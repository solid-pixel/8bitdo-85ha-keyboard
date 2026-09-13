#import <Foundation/Foundation.h>
@interface BD85Device : NSObject
- (NSDictionary *)snapshot;
- (NSData *)mappingForKey:(uint8_t)key;
- (NSArray<NSData *> *)macroPackets;
- (NSArray<NSData *> *)macroDetailsForKey:(uint8_t)key;
- (void)close;
@end
