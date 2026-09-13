#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DockMonitor : NSObject

@property(nonatomic, readonly, getter=isAccessibilityGranted) BOOL accessibilityGranted;
@property(nonatomic, readonly, getter=isEventTapActive) BOOL eventTapActive;
@property(nonatomic, readonly, getter=isEnabled) BOOL enabled;

- (void)start;
- (void)refreshPermissions;
- (void)setEnabled:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
