#import "DockMonitor.h"

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreGraphics/CoreGraphics.h>

static CFTypeRef CopyAXValue(AXUIElementRef element, CFStringRef attribute) {
    if (element == NULL) {
        return NULL;
    }

    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    return error == kAXErrorSuccess ? value : NULL;
}

static NSString *CopyAXString(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = CopyAXValue(element, attribute);
    if (value == NULL) {
        return nil;
    }

    NSString *result = nil;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        result = [(__bridge NSString *)value copy];
    }
    CFRelease(value);
    return result;
}

static AXUIElementRef CopyAXElement(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = CopyAXValue(element, attribute);
    if (value == NULL) {
        return NULL;
    }

    if (CFGetTypeID(value) != AXUIElementGetTypeID()) {
        CFRelease(value);
        return NULL;
    }
    return (AXUIElementRef)value;
}

static BOOL CopyAXBoolean(AXUIElementRef element, CFStringRef attribute, BOOL *valueOut) {
    CFTypeRef value = CopyAXValue(element, attribute);
    if (value == NULL) {
        return NO;
    }

    BOOL isBoolean = CFGetTypeID(value) == CFBooleanGetTypeID();
    if (isBoolean && valueOut != NULL) {
        *valueOut = CFBooleanGetValue((CFBooleanRef)value);
    }
    CFRelease(value);
    return isBoolean;
}

static BOOL IsApplicationDockItem(AXUIElementRef element) {
    // Dock has reported application items with both shapes across macOS
    // releases: AXDockItem as the role, or AXApplicationDockItem as the
    // subrole. The URL check later rejects folders, stacks, Trash, and other
    // non-application items.
    NSString *role = CopyAXString(element, kAXRoleAttribute);
    NSString *subrole = CopyAXString(element, kAXSubroleAttribute);
    // On current macOS the role is normally AXDockItem and the subrole is
    // AXApplicationDockItem. Older Dock accessibility trees sometimes omit
    // the subrole, so accept that shape too. If a subrole is present, reject
    // folder/stack/Trash items explicitly.
    if ([subrole isEqualToString:@"AXApplicationDockItem"]) {
        return YES;
    }
    return subrole.length == 0 && [role isEqualToString:@"AXDockItem"];
}

// AX hit-testing often returns a child of the Dock item. Walk up only a
// bounded number of parents so a malformed accessibility tree cannot cause a
// long operation inside the event tap callback.
static AXUIElementRef FindApplicationDockItem(AXUIElementRef hitElement) {
    AXUIElementRef current = hitElement;

    for (NSUInteger depth = 0; current != NULL && depth < 12; depth++) {
        if (IsApplicationDockItem(current)) {
            return current;
        }

        CFTypeRef parent = CopyAXValue(current, kAXParentAttribute);
        CFRelease(current);
        current = NULL;

        if (parent != NULL && CFGetTypeID(parent) == AXUIElementGetTypeID()) {
            current = (AXUIElementRef)parent;
        } else if (parent != NULL) {
            CFRelease(parent);
        }
    }

    if (current != NULL) {
        CFRelease(current);
    }
    return NULL;
}

static NSString *CopyDockItemBundleIdentifier(AXUIElementRef dockItem) {
    CFTypeRef urlValue = CopyAXValue(dockItem, kAXURLAttribute);
    if (urlValue == NULL) {
        return nil;
    }

    NSString *path = nil;
    CFTypeID type = CFGetTypeID(urlValue);
    if (type == CFURLGetTypeID()) {
        NSURL *url = (__bridge NSURL *)urlValue;
        path = [url.path copy];
    } else if (type == CFStringGetTypeID()) {
        NSString *rawValue = [(__bridge NSString *)urlValue copy];
        if ([rawValue hasPrefix:@"file://"]) {
            path = [NSURL URLWithString:rawValue].path;
        } else {
            path = rawValue;
        }
    }
    CFRelease(urlValue);

    if (path.length == 0) {
        return nil;
    }

    NSBundle *bundle = [NSBundle bundleWithPath:path];
    return [bundle.bundleIdentifier copy];
}

static BOOL IsFullScreenWindow(AXUIElementRef window) {
    // AXFullScreen is not present in every application's accessibility tree,
    // so an absent attribute means "not reported as full screen". The
    // subrole check covers applications that expose only the window subrole.
    BOOL fullScreen = NO;
    if (CopyAXBoolean(window, CFSTR("AXFullScreen"), &fullScreen) && fullScreen) {
        return YES;
    }

    NSString *subrole = CopyAXString(window, kAXSubroleAttribute);
    return [subrole isEqualToString:@"AXFullScreenWindow"];
}

static BOOL IsNormalWindow(AXUIElementRef window) {
    NSString *role = CopyAXString(window, kAXRoleAttribute);
    if (![role isEqualToString:@"AXWindow"]) {
        return NO;
    }

    NSString *subrole = CopyAXString(window, kAXSubroleAttribute);
    NSSet<NSString *> *nonDocumentSubroles = [NSSet setWithObjects:
        @"AXDialog",
        @"AXDrawer",
        @"AXFloatingWindow",
        @"AXFullScreenWindow",
        @"AXSheet",
        @"AXSystemDialog",
        nil
    ];
    return subrole.length == 0 || ![nonDocumentSubroles containsObject:subrole];
}

static BOOL IsEligibleWindow(AXUIElementRef window) {
    if (!IsNormalWindow(window) || IsFullScreenWindow(window)) {
        return NO;
    }

    BOOL minimized = NO;
    // A missing AXMinimized value is treated conservatively. We must not risk
    // touching a window whose minimized state cannot be determined.
    if (!CopyAXBoolean(window, kAXMinimizedAttribute, &minimized) || minimized) {
        return NO;
    }

    // AXUIElementIsAttributeSettable is not consistently implemented by all
    // AppKit/WebKit applications even when setting AXMinimized succeeds.
    // Keep the state check above, then let the actual set operation decide.
    return YES;
}

static AXUIElementRef CopyFrontNormalWindow(AXUIElementRef application) {
    AXUIElementRef focusedWindow = CopyAXElement(application, kAXFocusedWindowAttribute);
    if (focusedWindow != NULL) {
        if (IsNormalWindow(focusedWindow)) {
            if (IsEligibleWindow(focusedWindow)) {
                return focusedWindow;
            }
            CFRelease(focusedWindow);
            return NULL;
        }
        CFRelease(focusedWindow);
    }

    AXUIElementRef mainWindow = CopyAXElement(application, kAXMainWindowAttribute);
    if (mainWindow != NULL) {
        if (IsEligibleWindow(mainWindow)) {
            return mainWindow;
        }
        CFRelease(mainWindow);
    }

    CFTypeRef windowsValue = CopyAXValue(application, kAXWindowsAttribute);
    if (windowsValue == NULL || CFGetTypeID(windowsValue) != CFArrayGetTypeID()) {
        if (windowsValue != NULL) {
            CFRelease(windowsValue);
        }
        return NULL;
    }

    CFArrayRef windows = (CFArrayRef)windowsValue;
    AXUIElementRef result = NULL;
    CFIndex count = CFArrayGetCount(windows);
    for (CFIndex index = 0; index < count; index++) {
        AXUIElementRef window = (AXUIElementRef)CFArrayGetValueAtIndex(windows, index);
        if (window != NULL && IsEligibleWindow(window)) {
            result = (AXUIElementRef)CFRetain(window);
            break;
        }
    }
    CFRelease(windowsValue);
    return result;
}

#if DEBUG
static void DebugLog(NSString *message) {
    const char *text = message.UTF8String ? message.UTF8String : "";
    fprintf(stderr, "%s\n", text);
}

#define DM_DEBUG_LOG(...) DebugLog([NSString stringWithFormat:__VA_ARGS__])
#else
#define DM_DEBUG_LOG(...)
#endif

@interface DockMonitor () {
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _eventTapSource;
}

@property(nonatomic, readwrite, getter=isAccessibilityGranted) BOOL accessibilityGranted;
@property(nonatomic, readwrite, getter=isEventTapActive) BOOL eventTapActive;
@property(nonatomic, readwrite, getter=isEnabled) BOOL enabled;

- (BOOL)handleLeftMouseDown:(CGEventRef)event;
- (void)installEventTapIfNeeded;
- (void)tearDownEventTap;
- (void)reenableEventTap;
- (void)minimizeProcessIfStillFrontmost:(pid_t)processIdentifier
                      bundleIdentifier:(NSString *)bundleIdentifier
                           clickedName:(NSString *)clickedName;

@end

static CGEventRef DockEventCallback(CGEventTapProxy proxy,
                                     CGEventType type,
                                     CGEventRef event,
                                     void *refcon) {
    (void)proxy;
    DockMonitor *monitor = (__bridge DockMonitor *)refcon;

    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        [monitor reenableEventTap];
        return event;
    }

    if (!monitor.isEnabled) {
        return event;
    }

    if (type == kCGEventLeftMouseDown) {
        DM_DEBUG_LOG(@"Event: leftMouseDown");
        [monitor handleLeftMouseDown:event];
    }

    // This is deliberately a listen-only tap. Dock receives the original
    // click and therefore keeps its native activation/restoration behavior.
    return event;
}

@implementation DockMonitor

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        id savedValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled"];
        _enabled = savedValue == nil
            ? YES
            : [[NSUserDefaults standardUserDefaults] boolForKey:@"Enabled"];
    }
    return self;
}

- (void)start {
    [self refreshPermissions];
}

- (void)refreshPermissions {
    // Use the current, non-prompting trust check. Passing false here is
    // important: refreshing the UI must never show a permission prompt.
    NSDictionary *options = @{
        (__bridge NSString *)kAXTrustedCheckOptionPrompt : @NO
    };
    self.accessibilityGranted = AXIsProcessTrustedWithOptions(
        (__bridge CFDictionaryRef)options);
    if (!self.accessibilityGranted) {
        [self tearDownEventTap];
#if DEBUG
        DM_DEBUG_LOG(@"Accessibility: NOT GRANTED\nEventTap: NOT INSTALLED");
#endif
        return;
    }

    [self installEventTapIfNeeded];
#if DEBUG
    DM_DEBUG_LOG(@"Accessibility: GRANTED\nEventTap: %@",
                 self.eventTapActive ? @"ACTIVE" : @"NOT ACTIVE");
#endif
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"Enabled"];
    if (_eventTap != NULL) {
        CGEventTapEnable(_eventTap, enabled);
    }
}

- (void)installEventTapIfNeeded {
    if (_eventTap != NULL) {
        self.eventTapActive = YES;
        if (self.enabled) {
            CGEventTapEnable(_eventTap, true);
        }
        return;
    }

    // Only the press is needed. The original event is always returned to the
    // Dock, so observing mouse-up adds work without changing the behavior.
    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown);

    // A session-level listen-only tap observes the click without changing it.
    // It is enough for this utility and avoids the extra Input Monitoring
    // requirement associated with an active/HID tap.
    _eventTap = CGEventTapCreate(kCGSessionEventTap,
                                 kCGHeadInsertEventTap,
                                 kCGEventTapOptionListenOnly,
                                 mask,
                                 DockEventCallback,
                                 (__bridge void *)self);
    if (_eventTap == NULL) {
        self.eventTapActive = NO;
        return;
    }

    _eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);
    if (_eventTapSource == NULL) {
        CFRelease(_eventTap);
        _eventTap = NULL;
        self.eventTapActive = NO;
        return;
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), _eventTapSource, kCFRunLoopCommonModes);
    self.eventTapActive = YES;
    if (!self.enabled) {
        CGEventTapEnable(_eventTap, false);
    }
}

- (void)tearDownEventTap {
    if (_eventTapSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), _eventTapSource, kCFRunLoopCommonModes);
        CFRelease(_eventTapSource);
        _eventTapSource = NULL;
    }

    if (_eventTap != NULL) {
        CGEventTapEnable(_eventTap, false);
        CFRelease(_eventTap);
        _eventTap = NULL;
    }
    self.eventTapActive = NO;
}

- (void)reenableEventTap {
    if (_eventTap != NULL && self.enabled) {
        CGEventTapEnable(_eventTap, true);
    }
}

- (BOOL)handleLeftMouseDown:(CGEventRef)event {
    if (!self.accessibilityGranted) {
        return NO;
    }

    CGEventFlags flags = CGEventGetFlags(event);
    CGEventFlags modifierFlags = kCGEventFlagMaskCommand |
                                 kCGEventFlagMaskAlternate |
                                 kCGEventFlagMaskControl |
                                 kCGEventFlagMaskShift;
    if ((flags & modifierFlags) != 0) {
        return NO;
    }

    NSRunningApplication *frontmostApplication = NSWorkspace.sharedWorkspace.frontmostApplication;
    NSString *frontmostName = frontmostApplication.localizedName ? frontmostApplication.localizedName : @"(none)";
#if !DEBUG
    (void)frontmostName;
#endif
    NSString *frontmostBundleIdentifier = frontmostApplication.bundleIdentifier;
    if (frontmostBundleIdentifier.length == 0) {
        return NO;
    }

    CGPoint location = CGEventGetLocation(event);
    AXUIElementRef systemWideElement = AXUIElementCreateSystemWide();
    AXUIElementRef hitElement = NULL;
    AXError hitTestError = AXUIElementCopyElementAtPosition(systemWideElement,
                                                              (float)location.x,
                                                              (float)location.y,
                                                              &hitElement);
    CFRelease(systemWideElement);
    if (hitTestError != kAXErrorSuccess || hitElement == NULL) {
        return NO;
    }

    AXUIElementRef dockItem = FindApplicationDockItem(hitElement);
    if (dockItem == NULL) {
        return NO;
    }

    NSRunningApplication *dockApplication =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.dock"].firstObject;
    pid_t dockProcessIdentifier = 0;
    AXUIElementGetPid(dockItem, &dockProcessIdentifier);
    if (dockApplication == nil ||
        dockProcessIdentifier != dockApplication.processIdentifier) {
        CFRelease(dockItem);
        return NO;
    }

    NSString *clickedSubrole = CopyAXString(dockItem, kAXSubroleAttribute);
    NSString *clickedName = CopyAXString(dockItem, kAXTitleAttribute);
    if (clickedName == nil) {
        clickedName = @"(unknown)";
    }
    NSString *clickedBundleIdentifier = CopyDockItemBundleIdentifier(dockItem);
    BOOL hasExplicitApplicationSubrole =
        [clickedSubrole isEqualToString:@"AXApplicationDockItem"];
    // When older Dock trees omit the subrole, require a real application
    // bundle URL before accepting the candidate. This prevents a folder,
    // Stack, or Trash item with a coincidentally matching title from ever
    // reaching the window-minimization path.
    if (!hasExplicitApplicationSubrole && clickedBundleIdentifier.length == 0) {
        CFRelease(dockItem);
        return NO;
    }
    // Bundle ID is the exact identity. Only use the Dock title when the Dock
    // did not expose an application URL at all; otherwise two apps with the
    // same localized name must never be treated as the same application.
    BOOL sameApplication = clickedBundleIdentifier.length > 0
        ? [clickedBundleIdentifier isEqualToString:frontmostBundleIdentifier]
        : [clickedName isEqualToString:frontmostName];

    if (!sameApplication) {
        DM_DEBUG_LOG(@"Clicked: %@\nFrontmost: %@\nSameApp: NO\nAction: PASS THROUGH",
                     clickedName,
                     frontmostName);
        CFRelease(dockItem);
        return NO;
    }

    AXUIElementRef application = AXUIElementCreateApplication(frontmostApplication.processIdentifier);
    AXUIElementRef window = application != NULL ? CopyFrontNormalWindow(application) : NULL;
    BOOL hasWindow = window != NULL;
#if !DEBUG
    (void)hasWindow;
#endif
    BOOL minimized = NO;
    if (window != NULL) {
        CopyAXBoolean(window, kAXMinimizedAttribute, &minimized);
    }

    DM_DEBUG_LOG(@"Clicked: %@\nFrontmost: %@\nSameApp: YES\nHasWindow: %@\nMinimized: %@\nReadBackMinimized: %@\nAction: %@",
                 clickedName,
                 frontmostName,
                 hasWindow ? @"YES" : @"NO",
                 minimized ? @"YES" : @"NO",
                 @"PENDING",
                 hasWindow ? @"MINIMIZE AFTER DOCK" : @"PASS THROUGH");

    if (window != NULL) {
        CFRelease(window);
    }
    if (application != NULL) {
        CFRelease(application);
    }
    CFRelease(dockItem);

    if (!hasWindow) {
        return NO;
    }

    pid_t processIdentifier = frontmostApplication.processIdentifier;
    NSString *bundleIdentifier = [frontmostBundleIdentifier copy];
    NSString *name = [clickedName copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   ^{
        [self minimizeProcessIfStillFrontmost:processIdentifier
                            bundleIdentifier:bundleIdentifier
                                 clickedName:name];
    });
    return YES;
}

- (void)minimizeProcessIfStillFrontmost:(pid_t)processIdentifier
                      bundleIdentifier:(NSString *)bundleIdentifier
                           clickedName:(NSString *)clickedName {
    NSRunningApplication *current = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (current.processIdentifier != processIdentifier ||
        ![current.bundleIdentifier isEqualToString:bundleIdentifier]) {
        DM_DEBUG_LOG(@"Clicked: %@\nAction: PASS THROUGH (frontmost changed)", clickedName);
        return;
    }

    AXUIElementRef application = AXUIElementCreateApplication(processIdentifier);
    AXUIElementRef window = application != NULL ? CopyFrontNormalWindow(application) : NULL;
    AXError minimizeError = kAXErrorFailure;
    if (window != NULL) {
        minimizeError = AXUIElementSetAttributeValue(window,
                                                       kAXMinimizedAttribute,
                                                       kCFBooleanTrue);
    }
#if !DEBUG
    (void)minimizeError;
#endif

#if DEBUG
    BOOL readBackMinimized = NO;
    BOOL readBackSucceeded = window != NULL &&
        CopyAXBoolean(window, kAXMinimizedAttribute, &readBackMinimized);
#endif
    DM_DEBUG_LOG(@"Clicked: %@\nFrontmost: %@\nAction: %@\nReadBackMinimized: %@",
                 clickedName,
                 current.localizedName ? current.localizedName : @"(none)",
                 minimizeError == kAXErrorSuccess ? @"MINIMIZE" : @"PASS THROUGH",
                 readBackSucceeded ? (readBackMinimized ? @"YES" : @"NO") : @"UNKNOWN");

    if (window != NULL) {
        CFRelease(window);
    }
    if (application != NULL) {
        CFRelease(application);
    }
}

- (void)dealloc {
    [self tearDownEventTap];
}

@end
