#import "Device.h"
#import <IOKit/hid/IOHIDManager.h>

static void Fail(NSString *s) { @throw [NSException exceptionWithName:@"KeyboardError" reason:s userInfo:nil]; }
static void LogReport(const char *direction,NSData *data) {
 fprintf(stderr,"%s ",direction);const uint8_t *bytes=data.bytes;
 for(NSUInteger i=0;i<data.length;i++)fprintf(stderr,"%02x",bytes[i]);
 fputc('\n',stderr);
}
@interface BD85Device () {
 IOHIDManagerRef _manager;
 IOHIDDeviceRef _device;
 uint8_t _input[33];
 NSMutableArray<NSData *> *_replies;
 CFRunLoopRef _runLoop;
}
@end
static void Received(void *context, IOReturn result, void *sender, IOHIDReportType type,
                     uint32_t reportID, uint8_t *bytes, CFIndex length);
@implementation BD85Device
- (instancetype)init {
 if (!(self=[super init])) return nil;
 _replies=[NSMutableArray new];
 _manager=IOHIDManagerCreate(NULL,kIOHIDOptionsTypeNone);
 NSDictionary *match=@{@kIOHIDVendorIDKey:@0x2dc8,@kIOHIDProductIDKey:@0x5200,
 @kIOHIDPrimaryUsagePageKey:@0x8c,@kIOHIDPrimaryUsageKey:@1};
 IOHIDManagerSetDeviceMatching(_manager,(__bridge CFDictionaryRef)match);
 CFSetRef devices=IOHIDManagerCopyDevices(_manager);
 if(!devices || CFSetGetCount(devices)!=1) {
  if(devices)CFRelease(devices);
  [self close];
  Fail(@"Connect one 85HA by USB with its selector set to OFF, then click Reload.");
 }
 CFSetGetValues(devices,(const void **)&_device); CFRetain(_device); CFRelease(devices);
 IOReturn r=IOHIDDeviceOpen(_device,kIOHIDOptionsTypeNone);
 if(r!=kIOReturnSuccess){[self close];Fail([NSString stringWithFormat:@"Could not open the keyboard (0x%x). Close other keyboard configuration apps and retry.",r]);}
 _runLoop=CFRunLoopGetCurrent(); CFRetain(_runLoop);
 IOHIDDeviceRegisterInputReportCallback(_device,_input,sizeof _input,Received,(__bridge void *)self);
 IOHIDDeviceScheduleWithRunLoop(_device,_runLoop,kCFRunLoopDefaultMode);
 return self;
}
- (void)received:(NSData *)data { [_replies addObject:data]; }
- (void)assertThread { if(_runLoop!=CFRunLoopGetCurrent())Fail(@"Keyboard operation used the wrong thread."); }
- (NSData *)receive {
 [self assertThread];CFAbsoluteTime end=CFAbsoluteTimeGetCurrent()+2.0;
 while(CFAbsoluteTimeGetCurrent()<end){
  while(!_replies.count && CFAbsoluteTimeGetCurrent()<end)CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.01,false);
  if(!_replies.count)break;
  NSData *d=_replies[0];[_replies removeObjectAtIndex:0];
  if(d.length!=33 || ((const uint8_t *)d.bytes)[0]!=0x54)Fail(@"Unexpected keyboard response.");
  if(((const uint8_t *)d.bytes)[1]==0x8a)continue;
  LogReport("RX",d);return d;
 }
 Fail(@"Keyboard response timed out. Reconnect its USB cable, then reload.");return nil;
}
- (NSData *)send:(const uint8_t *)bytes length:(NSUInteger)length {
 [self assertThread];
 if(length>33 || length<2 || bytes[0]!=0x52)Fail(@"Invalid configuration command.");
 // Deliberately no bootloader, firmware, erase, or profile-delete operations.
 BOOL allowed=(length==2 && (bytes[1]==0x80 || bytes[1]==0x81 || bytes[1]==0x82)) ||
 (length==3 && (bytes[1]==0x83 || bytes[1]==0x84 || bytes[1]==0x86));
 if(!allowed)Fail(@"Unsupported command blocked.");
 [_replies removeAllObjects]; uint8_t report[33]={0}; memcpy(report,bytes,length);
 LogReport("TX",[NSData dataWithBytes:report length:33]);
 IOReturn r=IOHIDDeviceSetReport(_device,kIOHIDReportTypeOutput,0x52,report,33);
 if(r!=kIOReturnSuccess)Fail([NSString stringWithFormat:@"USB command failed (0x%x). Reload before retrying.",r]);
 return [self receive];
}
- (NSData *)mappingForKey:(uint8_t)key {
 const uint8_t b[]={0x52,0x83,key};NSData *d=[self send:b length:3];
 const uint8_t *p=d.bytes;
 if(p[1]!=0x83 || p[2]!=key)Fail(@"Mapping response did not match the requested key.");
 return [d subdataWithRange:NSMakeRange(3,24)];
}
- (NSArray<NSData *> *)macroPackets {
 const uint8_t b[]={0x52,0x82};NSData *d=[self send:b length:2];
 NSMutableArray *packets=[NSMutableArray new];
 for(int page=0;;page++){
  const uint8_t *p=d.bytes;
  if(p[1]!=0x82 || p[32]>1 || page>=8)Fail(@"Unexpected macro list response.");
  [packets addObject:d];
  if(!p[32])return packets;
  d=[self receive];
 }
}
- (NSArray<NSData *> *)macroDetailsForKey:(uint8_t)key {
 const uint8_t name[]={0x52,0x84,key};NSData *d=[self send:name length:3];
 const uint8_t *p=d.bytes;
 if(p[1]!=0x84 || p[2]!=key)Fail(@"Unexpected macro name response.");
 NSMutableArray *packets=[NSMutableArray arrayWithObject:d];
 const uint8_t definition[]={0x52,0x86,key};d=[self send:definition length:3];
 NSUInteger offset=0;
 for(int page=0;;page++){
  p=d.bytes;
  if(p[1]!=0x86 || p[2]!=key || p[3]>1 || !p[6] || p[6]>26 || (p[4]+256*p[5])!=offset || page>=32)Fail(@"Unexpected macro data response.");
  offset+=p[6];[packets addObject:d];
  if(!p[3])return packets;
  d=[self receive];
 }
}
- (NSDictionary *)snapshot {
 const uint8_t name[]={0x52,0x80};NSData *d=[self send:name length:2];const uint8_t *p=d.bytes;
 if(p[1]!=0x80 || p[2]>28 || p[2]%2 || p[3]!=0)Fail(@"Unrecognized onboard profile format.");
 NSString *profile=[[NSString alloc]initWithBytes:p+4 length:p[2] encoding:NSUTF16BigEndianStringEncoding];
 if(!profile)Fail(@"Invalid profile name encoding.");
 const uint8_t list[]={0x52,0x81};d=[self send:list length:2];
 NSMutableArray *entries=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
 for(int page=0;;page++){
  p=d.bytes;if(p[1]!=0x81 || (p[32]!=0 && p[32]!=1) || page>7)Fail(@"Unrecognized mapped-key list.");
  for(int i=2;i<32;i+=2){if(p[i]==0)break;NSNumber *key=@(p[i]);if([seen containsObject:key])Fail(@"Duplicate key in mapping list.");[seen addObject:key];[entries addObject:@{@"key":key,@"type":@(p[i+1])}];}
  if(!p[32])break;d=[self receive];
 }
 NSMutableArray *mappings=[NSMutableArray new];
 for(NSDictionary *entry in entries){NSData *data=[self mappingForKey:[entry[@"key"] unsignedCharValue]];NSMutableDictionary *m=[entry mutableCopy];m[@"data"]=[data base64EncodedStringWithOptions:0];[mappings addObject:m];}
 return @{@"profile":profile,@"vendorID":@0x2dc8,@"productID":@0x5200,@"mappings":mappings};
}
- (void)close {
 if(_device){if(_runLoop){IOHIDDeviceUnscheduleFromRunLoop(_device,_runLoop,kCFRunLoopDefaultMode);IOHIDDeviceRegisterInputReportCallback(_device,_input,sizeof _input,NULL,NULL);}IOHIDDeviceClose(_device,kIOHIDOptionsTypeNone);CFRelease(_device);_device=NULL;}
 if(_manager){CFRelease(_manager);_manager=NULL;}if(_runLoop){CFRelease(_runLoop);_runLoop=NULL;}
}
- (void)dealloc{[self close];}
@end
static void Received(void *context, IOReturn result, void *sender, IOHIDReportType type,uint32_t reportID,uint8_t *bytes,CFIndex length){
 (void)sender;(void)type;(void)reportID;
 if(result==kIOReturnSuccess && length>0 && length<=33)[(__bridge BD85Device *)context received:[NSData dataWithBytes:bytes length:length]];
}
