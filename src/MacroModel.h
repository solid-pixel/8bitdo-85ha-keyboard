#import <Foundation/Foundation.h>
#include "Macro.h"
// The vendor protocol byte-swaps spaces in names; U+2000 is reserved by this encoding.
static inline NSData *MacroEncodedName(NSString *title){
 NSMutableData *d=[[title dataUsingEncoding:NSUTF16BigEndianStringEncoding] mutableCopy];uint8_t *p=d.mutableBytes;
 if(!macro_name_valid(p,(unsigned)d.length))return nil;
 for(NSUInteger i=0;i<d.length;i+=2){if(p[i]==0x20&&p[i+1]==0)return nil;if(p[i]==0&&p[i+1]==0x20){p[i]=0x20;p[i+1]=0;}}return d;
}
static inline NSDictionary *MacroDefinition(NSArray<NSData *> *reports,uint8_t key){
 if(reports.count<2)return nil;NSData *name=reports[0];if(name.length!=33)return nil;const uint8_t *p=name.bytes;
 if(p[0]!=0x54||p[1]!=0x84||p[2]!=key||p[4]||!macro_name_valid(p+5,p[3]))return nil;
 NSMutableData *decoded=[NSMutableData dataWithBytes:p+5 length:p[3]];uint8_t *chars=decoded.mutableBytes;for(NSUInteger i=0;i<decoded.length;i+=2)if(chars[i]==0x20&&chars[i+1]==0){chars[i]=0;chars[i+1]=0x20;}
 NSString *title=[[NSString alloc]initWithData:decoded encoding:NSUTF16BigEndianStringEncoding];if(!title)return nil;
 NSMutableData *data=[NSMutableData new];NSMutableArray *raw=[NSMutableArray new];
 for(NSUInteger i=0;i<reports.count;i++){
  NSData *r=reports[i];if(r.length!=33)return nil;[raw addObject:[r base64EncodedStringWithOptions:0]];if(!i)continue;p=r.bytes;
  if(p[0]!=0x54||p[1]!=0x86||p[2]!=key||p[3]!=(i+1<reports.count)||!p[6]||p[6]>26||p[4]+256u*p[5]!=data.length)return nil;
  [data appendBytes:p+7 length:p[6]];
 }
 BOOL valid=macro_valid(data.bytes,(unsigned)data.length);
 return @{@"name":title,@"nameReport":[name base64EncodedStringWithOptions:0],@"data":[data base64EncodedStringWithOptions:0],@"reports":raw,@"editable":@(valid)};
}
static inline NSDictionary *MacroListEntries(NSArray *packets,NSNumber *excluding){
 if(!packets.count)return nil;NSMutableDictionary *entries=[NSMutableDictionary new];NSMutableSet *seen=[NSMutableSet new];NSUInteger page=0;
 for(NSString *encoded in packets){NSData *d=[[NSData alloc]initWithBase64EncodedString:encoded options:0];if(d.length!=33)return nil;const uint8_t *p=d.bytes;if(p[0]!=0x54||p[1]!=0x82||!!p[32]!=(++page<packets.count))return nil;
  for(unsigned i=2;i+3<32;i+=4){if(!p[i])break;NSString *key=[@(p[i]) stringValue];if([seen containsObject:key])return nil;[seen addObject:key];if(p[i]!=excluding.unsignedIntValue)entries[key]=[[d subdataWithRange:NSMakeRange(i,4)] base64EncodedStringWithOptions:0];}
 }return entries;
}
