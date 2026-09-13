#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

int main(int argc, const char *argv[]) {
    if (argc < 3) {
        return 2;
    }
    @autoreleasepool {
        [NSApplication sharedApplication];
    CFArrayRef urls = LSCopyApplicationURLsForBundleIdentifier(CFSTR("com.ccswitch.desktop"), NULL);
        NSLog(@"registered URLs: %@", CFBridgingRelease(urls));
        NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:[NSString stringWithUTF8String:argv[1]]];
        NSLog(@"icon size: %@", NSStringFromSize(icon.size));
        NSImage *canvas = [[NSImage alloc] initWithSize:NSMakeSize(1024.0, 1024.0)];
        [canvas lockFocus];
        [[NSColor whiteColor] setFill];
        NSRectFill(NSMakeRect(0.0, 0.0, 1024.0, 1024.0));
        [icon drawInRect:NSMakeRect(0.0, 0.0, 1024.0, 1024.0)
                fromRect:NSZeroRect
               operation:NSCompositingOperationSourceOver
                fraction:1.0];
        [canvas unlockFocus];
        NSBitmapImageRep *representation = [[NSBitmapImageRep alloc] initWithData:canvas.TIFFRepresentation];
        NSData *png = [representation representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        if (png == nil || ![png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]) {
            return 1;
        }
    }
    return 0;
}
