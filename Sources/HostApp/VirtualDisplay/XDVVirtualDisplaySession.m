#import "XDVVirtualDisplaySession.h"
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@interface CGVirtualDisplayDescriptor : NSObject
- (void)setName:(NSString *)name;
- (void)setQueue:(dispatch_queue_t)queue;
- (void)setTerminationHandler:(dispatch_block_t)terminationHandler;
- (void)setMaxPixelsWide:(uint32_t)value;
- (void)setMaxPixelsHigh:(uint32_t)value;
- (void)setSizeInMillimeters:(CGSize)value;
- (void)setVendorID:(uint32_t)value;
- (void)setProductID:(uint32_t)value;
- (void)setSerialNumber:(uint32_t)value;
- (void)setRedPrimary:(CGPoint)value;
- (void)setGreenPrimary:(CGPoint)value;
- (void)setBluePrimary:(CGPoint)value;
- (void)setWhitePoint:(CGPoint)value;
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(uint32_t)width height:(uint32_t)height refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
- (void)setHiDPI:(uint32_t)value;
- (void)setRotation:(uint32_t)value;
- (void)setModes:(NSArray *)value;
- (void)setRefreshDeadline:(double)value;
@end

@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
- (uint32_t)displayID;
@end

@interface XDVVirtualDisplaySession ()
@property (nonatomic, strong) CGVirtualDisplay *display;
@property (nonatomic, readwrite) uint32_t displayID;
@end

@implementation XDVVirtualDisplaySession

- (instancetype)initWithName:(NSString *)name
                       width:(uint32_t)width
                      height:(uint32_t)height
                 refreshRate:(double)refreshRate
                       error:(NSError * _Nullable __autoreleasing *)error
{
    self = [super init];
    if (!self) {
        return nil;
    }

    Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
    Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
    Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
    Class displayClass = NSClassFromString(@"CGVirtualDisplay");

    if (!descriptorClass || !modeClass || !settingsClass || !displayClass) {
        if (error) {
            *error = [NSError errorWithDomain:@"XDisplay.VirtualDisplay"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"CGVirtualDisplay private classes are unavailable on this macOS build."}];
        }
        return nil;
    }

    CGVirtualDisplayDescriptor *descriptor = [descriptorClass new];
    [descriptor setName:name];
    [descriptor setQueue:dispatch_get_main_queue()];
    [descriptor setTerminationHandler:^{}];
    [descriptor setMaxPixelsWide:width];
    [descriptor setMaxPixelsHigh:height];
    [descriptor setSizeInMillimeters:CGSizeMake(344.0, 194.0)];
    [descriptor setVendorID:0xFEEE];
    [descriptor setProductID:0x0001];
    [descriptor setSerialNumber:(uint32_t)arc4random_uniform(UINT32_MAX)];
    [descriptor setRedPrimary:CGPointMake(0.6797, 0.3203)];
    [descriptor setGreenPrimary:CGPointMake(0.2559, 0.6983)];
    [descriptor setBluePrimary:CGPointMake(0.1494, 0.0557)];
    [descriptor setWhitePoint:CGPointMake(0.3125, 0.3291)];

    CGVirtualDisplayMode *mode = [[modeClass alloc] initWithWidth:width height:height refreshRate:refreshRate];
    CGVirtualDisplaySettings *settings = [settingsClass new];
    [settings setHiDPI:0];
    [settings setRotation:0];
    [settings setRefreshDeadline:0.016];
    [settings setModes:@[mode]];

    self.display = [[displayClass alloc] initWithDescriptor:descriptor];
    if (!self.display) {
        if (error) {
            *error = [NSError errorWithDomain:@"XDisplay.VirtualDisplay"
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"CGVirtualDisplay failed to initialize."}];
        }
        return nil;
    }

    BOOL applied = [self.display applySettings:settings];
    if (!applied || self.display.displayID == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"XDisplay.VirtualDisplay"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey: @"CGVirtualDisplay failed to apply its settings."}];
        }
        return nil;
    }

    _displayID = self.display.displayID;
    return self;
}

@end
