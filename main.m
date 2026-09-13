#import <AppKit/AppKit.h>

#import "DockMonitor.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate>
@property(nonatomic, strong) DockMonitor *monitor;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSWindow *settingsWindow;
@property(nonatomic, strong) NSMenuItem *enabledItem;
@property(nonatomic, strong) NSMenuItem *accessibilityItem;
@property(nonatomic, strong) NSMenuItem *listenerItem;
@property(nonatomic, strong) NSButton *enabledButton;
@property(nonatomic, strong) NSButton *menuBarButton;
@property(nonatomic, strong) NSTextField *accessibilityValue;
@property(nonatomic, strong) NSTextField *listenerValue;
@property(nonatomic, strong) NSButton *permissionButton;
@property(nonatomic, strong) NSButton *refreshButton;
@property(nonatomic, strong) NSButton *quitButton;
@property(nonatomic, strong) NSSegmentedControl *languageControl;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *subtitleLabel;
@property(nonatomic, strong) NSTextField *behaviorRowLabel;
@property(nonatomic, strong) NSTextField *menuBarRowLabel;
@property(nonatomic, strong) NSTextField *accessibilityRowLabel;
@property(nonatomic, strong) NSTextField *listenerRowLabel;
@property(nonatomic, strong) NSTextField *behaviorDescription;
@property(nonatomic, strong) NSTextField *privacyDescription;
- (NSBox *)separator;
- (NSView *)rowWithLabel:(NSTextField *)label control:(NSView *)control;
- (void)buildApplicationMenu;
- (void)buildStatusMenu;
- (void)showStatusMenu:(id)sender;
- (void)loadApplicationIcon;
- (BOOL)shouldKeepMenuBarIcon;
- (BOOL)usesChinese;
- (NSString *)localized:(NSString *)chinese english:(NSString *)english;
- (void)updateLocalizedStrings;
- (void)changeLanguage:(id)sender;
- (void)applyMenuBarVisibility:(BOOL)visible;
- (void)discardSettingsWindow;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    [self loadApplicationIcon];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self buildApplicationMenu];
    self.monitor = [[DockMonitor alloc] init];
    [self.monitor start];
    [self buildSettingsWindow];
    [self applyMenuBarVisibility:[self shouldKeepMenuBarIcon]];
    [self updateMenuState];
    [self showSettingsWindow:nil];
}

- (void)loadApplicationIcon {
    NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"AppIcon" ofType:@"icns"];
    NSImage *icon = iconPath == nil ? nil : [[NSImage alloc] initWithContentsOfFile:iconPath];
    if (icon != nil) {
        NSApp.applicationIconImage = icon;
    }
}

- (void)buildApplicationMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Dock Click Minimize"];
    NSMenuItem *applicationMenuItem = [[NSMenuItem alloc] initWithTitle:@"Dock Click Minimize"
                                                                    action:nil
                                                             keyEquivalent:@""];
    NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@"Dock Click Minimize"];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"退出 Dock Click Minimize" english:@"Quit Dock Click Minimize"]
                                                       action:@selector(quit:)
                                                keyEquivalent:@"q"];
    quitItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    quitItem.target = self;
    [applicationMenu addItem:quitItem];
    applicationMenuItem.submenu = applicationMenu;
    [mainMenu addItem:applicationMenuItem];

    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"窗口" english:@"Window"]
                                                               action:nil
                                                        keyEquivalent:@""];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:
        [self localized:@"窗口" english:@"Window"]];
    NSMenuItem *closeItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"关闭窗口" english:@"Close Window"]
                                                         action:@selector(closeSettingsWindow:)
                                                  keyEquivalent:@"w"];
    closeItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    closeItem.target = self;
    [windowMenu addItem:closeItem];
    windowMenuItem.submenu = windowMenu;
    [mainMenu addItem:windowMenuItem];

    NSApp.mainMenu = mainMenu;
}

- (BOOL)usesChinese {
    NSString *language = [[NSUserDefaults standardUserDefaults] stringForKey:@"Language"];
    return ![language isEqualToString:@"en"];
}

- (NSString *)localized:(NSString *)chinese english:(NSString *)english {
    return [self usesChinese] ? chinese : english;
}

- (BOOL)shouldKeepMenuBarIcon {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:@"KeepMenuBarIcon"];
    return value == nil ? YES : [defaults boolForKey:@"KeepMenuBarIcon"];
}

- (void)updateLocalizedStrings {
    BOOL chinese = [self usesChinese];
    self.languageControl.selectedSegment = chinese ? 0 : 1;
    self.subtitleLabel.stringValue = [self localized:@"前台应用 Dock 点击行为"
                                               english:@"A small, native toggle for the active Dock app"];
    self.behaviorRowLabel.stringValue = [self localized:@"Dock 点击行为"
                                                 english:@"Dock click behavior"];
    self.enabledButton.title = [self localized:@"启用" english:@"Enabled"];
    self.menuBarRowLabel.stringValue = [self localized:@"菜单栏" english:@"Menu bar"];
    self.menuBarButton.title = [self localized:@"保留菜单栏图标" english:@"Keep in Menu Bar"];
    self.accessibilityRowLabel.stringValue = [self localized:@"辅助功能" english:@"Accessibility"];
    self.listenerRowLabel.stringValue = [self localized:@"Dock 监听" english:@"Dock listener"];
    self.permissionButton.title = [self localized:@"打开辅助功能设置"
                                             english:@"Open Accessibility Settings"];
    self.refreshButton.title = [self localized:@"刷新状态" english:@"Refresh Status"];
    self.behaviorDescription.stringValue = [self localized:
        @"当前应用已在前台时，点击它的 Dock 图标会最小化当前窗口。\n"
         @"点击其他应用时保持 macOS 原生行为。"
        english:@"When the active app's Dock icon is clicked, its front window is minimized.\n"
         @"Clicks on other apps keep macOS's normal behavior."];
    self.privacyDescription.stringValue = [self localized:
        @"仅使用辅助功能权限。鼠标点击只在内存中处理，不会保存。\n"
         @"如果刚刚修改了权限，请点击“刷新状态”或重新打开本应用。"
        english:@"Only Accessibility is used. Mouse clicks are handled in memory and never stored.\n"
         @"If you just changed the switch, click Refresh Status or reopen this app."];
    self.quitButton.title = [self localized:@"退出" english:@"Quit"];
}

- (void)changeLanguage:(id)sender {
    (void)sender;
    BOOL chinese = self.languageControl.selectedSegment == 0;
    [[NSUserDefaults standardUserDefaults] setObject:(chinese ? @"cn" : @"en")
                                                     forKey:@"Language"];
    [self updateLocalizedStrings];
    [self buildApplicationMenu];
    [self updateMenuState];
}

- (void)applyMenuBarVisibility:(BOOL)visible {
    if (visible) {
        if (self.statusItem == nil) {
            [self buildStatusItem];
        }
        self.statusItem.visible = YES;
        return;
    }

    if (self.statusItem != nil) {
        NSStatusItem *item = self.statusItem;
        self.statusItem = nil;
        item.visible = NO;
        [[NSStatusBar systemStatusBar] removeStatusItem:item];
    }
}

- (NSView *)rowWithLabel:(NSTextField *)label control:(NSView *)control {
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    label.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    control.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:control];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:26.0],
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [control.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [control.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]
    ]];
    return row;
}

- (NSBox *)separator {
    NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    return separator;
}

- (void)buildSettingsWindow {
    NSRect frame = NSMakeRect(0.0, 0.0, 430.0, 340.0);
    self.settingsWindow = [[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSWindowStyleMaskTitled |
                                                                    NSWindowStyleMaskClosable |
                                                                    NSWindowStyleMaskMiniaturizable)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO];
    self.settingsWindow.title = @"Dock Click Minimize";
    self.settingsWindow.delegate = self;
    self.settingsWindow.releasedWhenClosed = NO;

    NSView *contentView = [[NSView alloc] initWithFrame:NSZeroRect];
    self.settingsWindow.contentView = contentView;

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 14.0;
    stack.edgeInsets = NSEdgeInsetsMake(22.0, 24.0, 20.0, 24.0);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor]
    ]];

    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iconView.image = NSApp.applicationIconImage;
    if (iconView.image == nil) {
        iconView.image = [NSImage imageWithSystemSymbolName:@"rectangle.on.rectangle"
                                      accessibilityDescription:@"Dock Click Minimize"];
    }
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [iconView.widthAnchor constraintEqualToConstant:30.0].active = YES;
    [iconView.heightAnchor constraintEqualToConstant:30.0].active = YES;

    self.titleLabel = [NSTextField labelWithString:@"Dock Click Minimize"];
    self.titleLabel.font = [NSFont systemFontOfSize:19.0 weight:NSFontWeightSemibold];
    self.subtitleLabel = [NSTextField labelWithString:@""];
    self.subtitleLabel.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular];
    self.subtitleLabel.textColor = NSColor.secondaryLabelColor;

    NSStackView *titleStack = [NSStackView stackViewWithViews:@[self.titleLabel, self.subtitleLabel]];
    titleStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    titleStack.alignment = NSLayoutAttributeLeading;
    titleStack.spacing = 3.0;

    self.languageControl = [NSSegmentedControl segmentedControlWithLabels:@[@"CN", @"EN"]
                                                               trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                     target:self
                                                                     action:@selector(changeLanguage:)];
    self.languageControl.controlSize = NSControlSizeSmall;
    self.languageControl.segmentStyle = NSSegmentStyleRounded;
    [self.languageControl setWidth:36.0 forSegment:0];
    [self.languageControl setWidth:36.0 forSegment:1];
    [self.languageControl setSelectedSegment:[self usesChinese] ? 0 : 1];

    NSStackView *header = [NSStackView stackViewWithViews:@[iconView, titleStack]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    header.alignment = NSLayoutAttributeCenterY;
    header.spacing = 12.0;
    [stack addArrangedSubview:header];

    // Keep the language switch independent from the content stack. This
    // preserves the compact header's intrinsic size and prevents AppKit from
    // assigning negative geometry when the window is first laid out.
    self.languageControl.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.languageControl];
    [NSLayoutConstraint activateConstraints:@[
        [self.languageControl.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24.0],
        [self.languageControl.centerYAnchor constraintEqualToAnchor:header.centerYAnchor]
    ]];

    [stack addArrangedSubview:[self separator]];

    self.enabledButton = [NSButton buttonWithTitle:@"Enabled"
                                             target:self
                                             action:@selector(toggleEnabledFromWindow:)];
    self.enabledButton.buttonType = NSButtonTypeSwitch;
    self.behaviorRowLabel = [NSTextField labelWithString:@""];
    [stack addArrangedSubview:[self rowWithLabel:self.behaviorRowLabel control:self.enabledButton]];

    self.menuBarButton = [NSButton buttonWithTitle:@"Keep in Menu Bar"
                                             target:self
                                             action:@selector(toggleMenuBarFromWindow:)];
    self.menuBarButton.buttonType = NSButtonTypeSwitch;
    self.menuBarRowLabel = [NSTextField labelWithString:@""];
    [stack addArrangedSubview:[self rowWithLabel:self.menuBarRowLabel control:self.menuBarButton]];

    self.accessibilityValue = [NSTextField labelWithString:@"Not Granted"];
    self.accessibilityValue.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    self.accessibilityRowLabel = [NSTextField labelWithString:@""];
    [stack addArrangedSubview:[self rowWithLabel:self.accessibilityRowLabel control:self.accessibilityValue]];

    self.listenerValue = [NSTextField labelWithString:@"Inactive"];
    self.listenerValue.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    self.listenerRowLabel = [NSTextField labelWithString:@""];
    [stack addArrangedSubview:[self rowWithLabel:self.listenerRowLabel control:self.listenerValue]];

    self.permissionButton = [NSButton buttonWithTitle:@"Open Accessibility Settings"
                                                target:self
                                                action:@selector(openPrivacySettings:)];
    self.permissionButton.bezelStyle = NSBezelStyleRounded;
    self.permissionButton.controlSize = NSControlSizeSmall;

    self.refreshButton = [NSButton buttonWithTitle:@"Refresh Status"
                                              target:self
                                              action:@selector(refreshStatus:)];
    self.refreshButton.bezelStyle = NSBezelStyleRounded;
    self.refreshButton.controlSize = NSControlSizeSmall;

    NSStackView *permissionActions = [NSStackView stackViewWithViews:@[
        self.permissionButton,
        self.refreshButton
    ]];
    permissionActions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    permissionActions.alignment = NSLayoutAttributeCenterY;
    permissionActions.spacing = 8.0;
    permissionActions.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *permissionFooter = [[NSView alloc] initWithFrame:NSZeroRect];
    permissionFooter.translatesAutoresizingMaskIntoConstraints = NO;
    [permissionFooter addSubview:permissionActions];
    [NSLayoutConstraint activateConstraints:@[
        [permissionFooter.heightAnchor constraintEqualToConstant:28.0],
        [permissionActions.trailingAnchor constraintEqualToAnchor:permissionFooter.trailingAnchor],
        [permissionActions.centerYAnchor constraintEqualToAnchor:permissionFooter.centerYAnchor]
    ]];
    [stack addArrangedSubview:permissionFooter];

    [stack addArrangedSubview:[self separator]];

    self.behaviorDescription = [NSTextField labelWithString:@""];
    self.behaviorDescription.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular];
    self.behaviorDescription.textColor = NSColor.secondaryLabelColor;
    self.behaviorDescription.maximumNumberOfLines = 0;
    self.behaviorDescription.lineBreakMode = NSLineBreakByWordWrapping;
    self.behaviorDescription.preferredMaxLayoutWidth = 370.0;
    [stack addArrangedSubview:self.behaviorDescription];

    self.privacyDescription = [NSTextField labelWithString:@""];
    self.privacyDescription.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];
    self.privacyDescription.textColor = NSColor.tertiaryLabelColor;
    self.privacyDescription.maximumNumberOfLines = 0;
    self.privacyDescription.lineBreakMode = NSLineBreakByWordWrapping;
    self.privacyDescription.preferredMaxLayoutWidth = 370.0;
    [stack addArrangedSubview:self.privacyDescription];

    self.quitButton = [NSButton buttonWithTitle:@"Quit" target:self action:@selector(quit:)];
    self.quitButton.bezelStyle = NSBezelStyleRounded;
    self.quitButton.controlSize = NSControlSizeSmall;
    NSView *footer = [[NSView alloc] initWithFrame:NSZeroRect];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [footer addSubview:self.quitButton];
    self.quitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [footer.heightAnchor constraintEqualToConstant:28.0],
        [self.quitButton.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor],
        [self.quitButton.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor]
    ]];
    [stack addArrangedSubview:footer];

    [self.settingsWindow center];
    [self updateLocalizedStrings];
}

- (void)discardSettingsWindow {
    if (self.settingsWindow == nil) {
        return;
    }

    self.settingsWindow.delegate = nil;
    self.settingsWindow = nil;
    self.enabledButton = nil;
    self.menuBarButton = nil;
    self.accessibilityValue = nil;
    self.listenerValue = nil;
    self.permissionButton = nil;
    self.refreshButton = nil;
    self.quitButton = nil;
    self.languageControl = nil;
    self.titleLabel = nil;
    self.subtitleLabel = nil;
    self.behaviorRowLabel = nil;
    self.menuBarRowLabel = nil;
    self.accessibilityRowLabel = nil;
    self.listenerRowLabel = nil;
    self.behaviorDescription = nil;
    self.privacyDescription = nil;

    // LaunchServices and Tahoe read the icon from the Bundle; they do not need
    // AppKit's decoded high-resolution copy after the settings window closes.
    // Release it so the resident accessory process keeps a smaller footprint.
    NSApp.applicationIconImage = nil;
}

- (void)buildStatusItem {
    if (self.statusItem != nil) {
        return;
    }

    // Keep the menu bar glyph lightweight and transparent. The application
    // icon is declared separately in Info.plist for the Dock and System
    // Settings; it should not be reused as a filled status-bar image.
    NSImage *statusImage = [NSImage imageWithSystemSymbolName:@"cursorarrow.click.2"
                                       accessibilityDescription:@"Dock Click Minimize"];
    if (statusImage == nil) {
        statusImage = [NSImage imageWithSystemSymbolName:@"cursorarrow.click"
                                   accessibilityDescription:@"Dock Click Minimize"];
    }
    if (statusImage == nil) {
        statusImage = NSApp.applicationIconImage;
    }

    // Let AppKit create the status item in its normal visible state. On Tahoe,
    // creating it hidden and revealing it later can leave Control Center with
    // a stale, blank placeholder in the "Allow in the Menu Bar" list.
    NSStatusItem *statusItem = [[NSStatusBar systemStatusBar]
        statusItemWithLength:NSSquareStatusItemLength];
    // Keep AppKit's default Item-0 identity. Tahoe registers the status item
    // before this method returns; renaming it here makes Control Center see an
    // Item-0 host followed by a second host and can leave a blank entry.
    self.statusItem = statusItem;

    NSButton *button = statusItem.button;
    statusImage.size = NSMakeSize(18.0, 18.0);
    statusImage.template = YES;
    button.image = statusImage;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.imagePosition = NSImageOnly;
    button.title = @"";
    button.image.template = YES;
    button.accessibilityLabel = @"Dock Click Minimize";
    button.toolTip = @"Dock Click Minimize";
    button.target = self;
    button.action = @selector(showStatusMenu:);
}

- (void)showStatusMenu:(id)sender {
    (void)sender;
    @autoreleasepool {
        if (self.statusItem == nil) {
            return;
        }

        // The status menu is needed only while the user is looking at it.
        // Keeping it lazy avoids retaining AppKit's menu/item graph during
        // normal idle operation, while the status item itself remains
        // available.
        [self buildStatusMenu];
        NSMenu *menu = self.statusItem.menu;
        if (menu == nil) {
            return;
        }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.statusItem popUpStatusItemMenu:menu];
#pragma clang diagnostic pop

        self.statusItem.menu = nil;
        self.enabledItem = nil;
        self.accessibilityItem = nil;
        self.listenerItem = nil;
    }
}

- (void)buildStatusMenu {
    if (self.statusItem == nil) {
        return;
    }

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Dock Click Minimize"];
    menu.delegate = self;

    NSMenuItem *heading = [[NSMenuItem alloc] initWithTitle:@"Dock Click Minimize"
                                                      action:nil
                                               keyEquivalent:@""];
    heading.enabled = NO;
    [menu addItem:heading];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"打开设置…" english:@"Open Settings…"]
                                                            action:@selector(showSettingsWindow:)
                                                     keyEquivalent:@","];
    settingsItem.target = self;
    [menu addItem:settingsItem];

    self.enabledItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"启用" english:@"Enabled"]
                                                   action:@selector(toggleEnabled:)
                                            keyEquivalent:@""];
    self.enabledItem.target = self;
    [menu addItem:self.enabledItem];

    self.accessibilityItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"辅助功能：未授权" english:@"Accessibility: Not Granted"]
                                                         action:@selector(openPrivacySettings:)
                                                  keyEquivalent:@""];
    self.accessibilityItem.target = self;
    [menu addItem:self.accessibilityItem];

    self.listenerItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"Dock 监听：未运行" english:@"Dock listener: Not active"]
                                                    action:@selector(openPrivacySettings:)
                                             keyEquivalent:@""];
    self.listenerItem.target = self;
    self.listenerItem.hidden = YES;
    [menu addItem:self.listenerItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *explanation = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"最小化当前应用的前台窗口。"
                 english:@"Minimize the active app's front window."]
                                                           action:nil
                                                    keyEquivalent:@""];
    explanation.enabled = NO;
    [menu addItem:explanation];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:
        [self localized:@"退出" english:@"Quit"]
                                                       action:@selector(quit:)
                                                keyEquivalent:@""];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

- (void)menuWillOpen:(NSMenu *)menu {
    (void)menu;
    [self.monitor refreshPermissions];
    [self updateMenuState];
}

- (void)updateMenuState {
    self.menuBarButton.state = [self shouldKeepMenuBarIcon]
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    self.enabledItem.state = self.monitor.enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.accessibilityItem.title = self.monitor.accessibilityGranted
        ? [self localized:@"辅助功能：已授权" english:@"Accessibility: Granted"]
        : [self localized:@"辅助功能：未授权" english:@"Accessibility: Not Granted"];
    self.accessibilityItem.enabled = !self.monitor.accessibilityGranted;

    self.listenerItem.hidden = !self.monitor.accessibilityGranted || self.monitor.eventTapActive;
    if (!self.monitor.eventTapActive && self.monitor.accessibilityGranted) {
        self.listenerItem.title = [self localized:
            @"Dock 监听：未运行 — 请检查辅助功能"
            english:@"Dock listener: Not active — check Accessibility"];
    }

    self.enabledButton.state = self.monitor.enabled
        ? NSControlStateValueOn
        : NSControlStateValueOff;
    self.accessibilityValue.stringValue = self.monitor.accessibilityGranted
        ? [self localized:@"已授权" english:@"Granted"]
        : [self localized:@"未授权" english:@"Not Granted"];
    self.accessibilityValue.textColor = self.monitor.accessibilityGranted
        ? NSColor.systemGreenColor
        : NSColor.secondaryLabelColor;
    if (!self.monitor.enabled) {
        self.listenerValue.stringValue = [self localized:@"已停用" english:@"Disabled"];
        self.listenerValue.textColor = NSColor.secondaryLabelColor;
    } else if (self.monitor.eventTapActive) {
        self.listenerValue.stringValue = [self localized:@"运行中" english:@"Active"];
        self.listenerValue.textColor = NSColor.systemGreenColor;
    } else {
        self.listenerValue.stringValue = [self localized:@"未运行" english:@"Inactive"];
        self.listenerValue.textColor = NSColor.secondaryLabelColor;
    }
}

- (void)showSettingsWindow:(id)sender {
    (void)sender;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    if (self.settingsWindow == nil) {
        [self loadApplicationIcon];
        [self buildSettingsWindow];
    }
    [self.monitor refreshPermissions];
    [self updateMenuState];
    [self.settingsWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)application
                    hasVisibleWindows:(BOOL)flag {
    (void)application;
    (void)flag;
    [self showSettingsWindow:nil];
    return YES;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    [self.monitor refreshPermissions];
    [self updateMenuState];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (notification.object != self.settingsWindow) {
        return;
    }
    [self discardSettingsWindow];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    if (notification.object != self.settingsWindow) {
        return;
    }
    [self.monitor refreshPermissions];
    [self updateMenuState];
}

- (void)toggleEnabled:(id)sender {
    (void)sender;
    [self.monitor setEnabled:!self.monitor.enabled];
    [self updateMenuState];
}

- (void)toggleEnabledFromWindow:(id)sender {
    (void)sender;
    [self.monitor setEnabled:self.enabledButton.state == NSControlStateValueOn];
    [self updateMenuState];
}

- (void)toggleMenuBarFromWindow:(id)sender {
    (void)sender;
    BOOL keep = self.menuBarButton.state == NSControlStateValueOn;
    [[NSUserDefaults standardUserDefaults] setBool:keep forKey:@"KeepMenuBarIcon"];
    [self applyMenuBarVisibility:keep];
    [self updateMenuState];
}

- (void)closeSettingsWindow:(id)sender {
    (void)sender;
    // Command-W is a background utility action, not an application quit.
    // Close and release the window before switching to accessory mode. Merely
    // ordering it out leaves AppKit retaining the hidden window and controls.
    NSWindow *window = self.settingsWindow;
    window.delegate = nil;
    [self discardSettingsWindow];
    [window close];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    (void)application;
    return NO;
}

- (void)openPrivacySettings:(id)sender {
    (void)sender;
    NSURL *url = [NSURL URLWithString:
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)refreshStatus:(id)sender {
    (void)sender;
    [self.monitor refreshPermissions];
    [self updateMenuState];
}

- (void)quit:(id)sender {
    (void)sender;
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
