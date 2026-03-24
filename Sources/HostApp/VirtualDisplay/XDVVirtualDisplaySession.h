#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XDVVirtualDisplaySession : NSObject

- (instancetype)initWithName:(NSString *)name
                       width:(uint32_t)width
                      height:(uint32_t)height
                 refreshRate:(double)refreshRate
                       error:(NSError * _Nullable * _Nullable)error;

@property (nonatomic, readonly) uint32_t displayID;

@end

NS_ASSUME_NONNULL_END
