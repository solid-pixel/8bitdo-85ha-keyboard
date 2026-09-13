#import <AppKit/AppKit.h>
#import "Device.h"
#include "Mapping.h"
#import "MacroModel.h"

static void Throw(NSString *message){@throw [NSException exceptionWithName:@"85HA" reason:message userInfo:nil];}
static NSData *Payload(int type,int second,int third){uint8_t p[24]={type,second,third};return [NSData dataWithBytes:p length:24];}
static NSData *Default(int key){uint8_t p[24];default_mapping(key,p);return [NSData dataWithBytes:p length:24];}
static NSString *Hex(NSData *d){NSMutableString *s=[NSMutableString new];const uint8_t *p=d.bytes;for(NSUInteger i=0;i<d.length;i++)[s appendFormat:@"%02x",p[i]];return s;}
static NSDictionary *Entries(NSDictionary *snapshot){NSMutableDictionary *d=[NSMutableDictionary new];for(NSDictionary *m in snapshot[@"mappings"])d[m[@"key"]]=m;return d;}
static NSData *Raw(NSDictionary *snapshot,NSNumber *key){NSDictionary *e=key?Entries(snapshot)[key]:nil;return e?[[NSData alloc]initWithBase64EncodedString:e[@"data"] options:0]:[NSMutableData dataWithLength:24];}
static NSUInteger SelectedIndex(NSArray *rows,NSNumber *wanted){
 NSUInteger index=[rows indexOfObjectPassingTest:^BOOL(NSDictionary *item,NSUInteger idx,BOOL *stop){(void)idx;(void)stop;return [item[@"key"] isEqual:wanted];}];
 return index!=NSNotFound?index:(rows.count?0:NSNotFound);
}
static NSString *ShellQuote(NSString *s){return [NSString stringWithFormat:@"'%@'",[s stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"]];}
static NSString *AppleQuote(NSString *s){s=[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];s=[s stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];return [NSString stringWithFormat:@"\"%@\"",s];}
static NSDictionary *ReadSnapshot(void){
 BD85Device *device=nil;
 @try{
  device=[BD85Device new];NSMutableDictionary *s=[[device snapshot] mutableCopy];
  NSMutableArray *packets=[NSMutableArray new],*keys=[NSMutableArray new];
  for(NSData *data in [device macroPackets]){
   [packets addObject:[data base64EncodedStringWithOptions:0]];const uint8_t *p=data.bytes;
   for(int i=2;i+3<32;i+=4){if(!p[i])break;[keys addObject:@(p[i])];}
  }
  s[@"macroPackets"]=packets;s[@"macroKeys"]=keys;
  NSMutableDictionary *definitions=[NSMutableDictionary new];
  for(NSNumber *key in keys){if(!physical_key(key.unsignedIntValue))continue;
   @try{NSDictionary *definition=MacroDefinition([device macroDetailsForKey:key.unsignedCharValue],key.unsignedCharValue);definitions[key.stringValue]=definition?:@{@"readError":@"Unrecognized macro format"};}
   @catch(NSException *e){definitions[key.stringValue]=@{@"readError":e.reason?:@"Could not read macro"};}
  }
  s[@"macroDefinitions"]=definitions;return s;
 }@finally{[device close];}
}
static NSDictionary *ReadAfterSave(void){
 for(int i=0;i<4;i++){@try{return ReadSnapshot();}@catch(NSException *e){if(i==3)@throw;[NSThread sleepForTimeInterval:0.3];}}
 return nil;
}
static BOOL Verify(NSDictionary *before,NSDictionary *after,NSNumber *key,NSData *target){
 NSMutableDictionary *a=[Entries(before) mutableCopy],*b=[Entries(after) mutableCopy];[a removeObjectForKey:key];[b removeObjectForKey:key];
 if(![a isEqual:b] || !matches_readback(key.unsignedIntValue,target.bytes,Raw(after,key).bytes))return NO;
 NSMutableDictionary *metaA=[before mutableCopy],*metaB=[after mutableCopy];[metaA removeObjectForKey:@"mappings"];[metaB removeObjectForKey:@"mappings"];
 return [metaA isEqual:metaB];
}
static BOOL VerifyMacro(NSDictionary *before,NSDictionary *after,NSNumber *key,NSDictionary *definition,NSData *target){
 if(!after)return NO;
 NSMutableDictionary *a=[Entries(before) mutableCopy],*b=[Entries(after) mutableCopy];[a removeObjectForKey:key];[b removeObjectForKey:key];
 if(![a isEqual:b]||!matches_readback(key.unsignedIntValue,target.bytes,Raw(after,key).bytes))return NO;
 NSDictionary *listA=MacroListEntries(before[@"macroPackets"],key),*listB=MacroListEntries(after[@"macroPackets"],key);
 if(!listA||!listB||![listA isEqual:listB])return NO;
 NSMutableDictionary *defsA=[before[@"macroDefinitions"] mutableCopy],*defsB=[after[@"macroDefinitions"] mutableCopy];
 [defsA removeObjectForKey:key.stringValue];[defsB removeObjectForKey:key.stringValue];if(![defsA isEqual:defsB])return NO;
 NSDictionary *actual=after[@"macroDefinitions"][key.stringValue];
 NSDictionary *all=MacroListEntries(after[@"macroPackets"],nil);if(!all)return NO;
 if(definition){
  if(![actual[@"name"] isEqual:definition[@"name"]]||![actual[@"data"] isEqual:definition[@"data"]]||![actual[@"editable"] boolValue])return NO;
  NSData *data=[[NSData alloc]initWithBase64EncodedString:definition[@"data"] options:0],*name=[definition[@"name"] dataUsingEncoding:NSUTF16BigEndianStringEncoding];
  uint8_t entry[4]={key.unsignedCharValue,data.length&255,data.length>>8,name.length};
  if(![all[key.stringValue] isEqual:[[NSData dataWithBytes:entry length:4] base64EncodedStringWithOptions:0]])return NO;
 }else if(actual||all[key.stringValue])return NO;
 NSMutableDictionary *metaA=[before mutableCopy],*metaB=[after mutableCopy];
 for(NSString *field in @[@"mappings",@"macroPackets",@"macroKeys",@"macroDefinitions"]){[metaA removeObjectForKey:field];[metaB removeObjectForKey:field];}
 return [metaA isEqual:metaB];
}
static BOOL MacrosWritable(NSDictionary *snapshot){
 NSArray *packets=snapshot[@"macroPackets"];if(packets.count!=1)return NO;NSData *list=[[NSData alloc]initWithBase64EncodedString:packets[0] options:0];if(!macro_list_writable(list.bytes,(unsigned)list.length))return NO;
 NSDictionary *entries=MacroListEntries(packets,nil);if(!entries)return NO;
 for(NSString *key in entries){NSDictionary *definition=snapshot[@"macroDefinitions"][key];if(![definition[@"editable"] boolValue])return NO;
  NSData *entry=[[NSData alloc]initWithBase64EncodedString:entries[key] options:0],*data=[[NSData alloc]initWithBase64EncodedString:definition[@"data"] options:0];const uint8_t *p=entry.bytes;
  NSData *name=MacroEncodedName(definition[@"name"]);if(data.length!=p[1]+256u*p[2]||name.length!=p[3])return NO;
 }return YES;
}
static NSArray *Catalog(void){
 NSMutableArray *keys=[NSMutableArray new];
 void (^add)(int,NSString *,NSString *)=^(int key,NSString *name,NSString *position){[keys addObject:@{@"key":@(key),@"name":name,@"position":position?:@""}];};
 add(0x29,@"Escape",nil);for(int n=1;n<=12;n++)add(0x39+n,[NSString stringWithFormat:@"F%d",n],nil);
 add(0x46,@"Print Screen",nil);add(0x47,@"Scroll Lock",nil);add(0x48,@"Pause",nil);
 add(0x35,@"Grave / tilde",nil);for(int n=1;n<=9;n++)add(0x1d+n,[NSString stringWithFormat:@"%d",n],nil);add(0x27,@"0",nil);
 NSArray *pairs=@[@[@0x2d,@"Minus"],@[@0x2e,@"Equals"],@[@0x2a,@"Backspace"],@[@0x2b,@"Tab"]];for(NSArray *p in pairs)add([p[0] intValue],p[1],nil);
 for(NSString *letter in @[@"Q",@"W",@"E",@"R",@"T",@"Y",@"U",@"I",@"O",@"P"])add(4+[letter characterAtIndex:0]-'A',letter,nil);
 add(0x2f,@"Left bracket",nil);add(0x30,@"Right bracket",nil);add(0x31,@"Backslash",nil);add(0x39,@"Caps Lock",nil);
 for(NSString *letter in @[@"A",@"S",@"D",@"F",@"G",@"H",@"J",@"K",@"L"])add(4+[letter characterAtIndex:0]-'A',letter,nil);
 add(0x33,@"Semicolon",nil);add(0x34,@"Apostrophe",nil);add(0x28,@"Return",nil);add(0x65,@"Left Shift",nil);
 for(NSString *letter in @[@"Z",@"X",@"C",@"V",@"B",@"N",@"M"])add(4+[letter characterAtIndex:0]-'A',letter,nil);
 add(0x36,@"Comma",nil);add(0x37,@"Period",nil);add(0x38,@"Slash",nil);add(0x69,@"Right Shift",nil);
 add(0x64,@"Left Control",@"First key from the left, bottom row");
 add(0x67,@"Windows / second key",@"Second key from the left, bottom row");
 add(0x66,@"Left Alt / third key",@"Third key from the left, bottom row");
 add(0x2c,@"Space",nil);add(0x6a,@"Right Alt",@"First key to the right of Space");add(0x68,@"Right Control",nil);
 pairs=@[@[@0x49,@"Insert"],@[@0x4a,@"Home"],@[@0x4b,@"Page Up"],@[@0x4c,@"Forward Delete"],@[@0x4d,@"End"],@[@0x4e,@"Page Down"],@[@0x50,@"Left Arrow"],@[@0x51,@"Down Arrow"],@[@0x4f,@"Right Arrow"],@[@0x52,@"Up Arrow"]];
 for(NSArray *p in pairs)add([p[0] intValue],p[1],nil);return keys;
}
static NSDictionary *ModifierNames(void){return @{@0xe0:@"Control (left)",@0xe1:@"Shift (left)",@0xe2:@"Option (left)",@0xe3:@"Command (left)",@0xe4:@"Control (right)",@0xe5:@"Shift (right)",@0xe6:@"Option (right)",@0xe7:@"Command (right)"};}
static NSDictionary *MediaNames(void){return @{@0x6f:@"Brightness up",@0x70:@"Brightness down",@0xb5:@"Next track",@0xb6:@"Previous track",@0xb7:@"Stop playback",@0xcd:@"Play / pause",@0xe2:@"Mute",@0xe9:@"Volume up",@0xea:@"Volume down"};}
static NSString *UsageName(int key){
 for(NSDictionary *item in Catalog()){int source=[item[@"key"] intValue];if(source==key && source<0x64)return item[@"name"];}
 if(key>=0x68&&key<=0x73)return [NSString stringWithFormat:@"F%d",key-0x68+13];
 return [NSString stringWithFormat:@"Key 0x%02x",key];
}
static NSString *MappingName(NSData *data,int key){
 if(zero_mapping(data.bytes))data=Default(key);const uint8_t *p=data.bytes;
 if(!mapping_valid(p))return @"Unrecognized mapping";
 if(p[0]==12)return MediaNames()[@(p[1]+256*p[2])]?:@"Media key";
 if(!p[1]&&!p[2])return @"Disabled";
 if(p[1]&&p[2])return [NSString stringWithFormat:@"%@ + %@",ModifierNames()[@(p[1])],UsageName(p[2])];
 return p[1]?ModifierNames()[@(p[1])]:UsageName(p[2]);
}
static NSTextField *Label(NSString *text,CGFloat size,BOOL bold){NSTextField *l=[NSTextField wrappingLabelWithString:text];l.font=bold?[NSFont systemFontOfSize:size weight:NSFontWeightSemibold]:[NSFont systemFontOfSize:size];return l;}
static NSStackView *Stack(NSArray *views,NSUserInterfaceLayoutOrientation orientation,CGFloat spacing){NSStackView *s=[NSStackView stackViewWithViews:views];s.orientation=orientation;s.spacing=spacing;s.alignment=orientation==NSUserInterfaceLayoutOrientationVertical?NSLayoutAttributeLeading:NSLayoutAttributeTop;return s;}

// Coordinates use standard key widths, with a separate navigation cluster.
static NSArray *KeyboardLayout(void){
 NSMutableArray *layout=[NSMutableArray new];
 void (^key)(int,double,double,double,NSString *)=^(int code,double x,double y,double width,NSString *legend){
  [layout addObject:@{@"key":@(code),@"x":@(x),@"y":@(y),@"w":@(width),@"legend":legend}];
 };
 key(0x29,0,0,1,@"Esc");
 for(int i=0;i<12;i++)key(0x3a+i,2+i+(i/4)*0.5,0,1,[NSString stringWithFormat:@"F%d",i+1]);
 key(0x46,15.5,0,1,@"PrtSc");key(0x47,16.5,0,1,@"ScrLk");key(0x48,17.5,0,1,@"Pause");
 key(0x35,0,1.4,1,@"` ~");for(int i=0;i<10;i++)key(0x1e + i,1+i,1.4,1,i==9?@"0":[NSString stringWithFormat:@"%d",i+1]);
 key(0x2d,11,1.4,1,@"−");key(0x2e,12,1.4,1,@"=");key(0x2a,13,1.4,2,@"Backspace");
 key(0x2b,0,2.4,1.5,@"Tab");NSString *letters=@"QWERTYUIOP";
 for(int i=0;i<10;i++)key(4+[letters characterAtIndex:i]-'A',1.5+i,2.4,1,[letters substringWithRange:NSMakeRange(i,1)]);
 key(0x2f,11.5,2.4,1,@"[");key(0x30,12.5,2.4,1,@"]");key(0x31,13.5,2.4,1.5,@"\\");
 key(0x39,0,3.4,1.75,@"Caps Lock");letters=@"ASDFGHJKL";
 for(int i=0;i<9;i++)key(4+[letters characterAtIndex:i]-'A',1.75+i,3.4,1,[letters substringWithRange:NSMakeRange(i,1)]);
 key(0x33,10.75,3.4,1,@";");key(0x34,11.75,3.4,1,@"'");key(0x28,12.75,3.4,2.25,@"Return");
 key(0x65,0,4.4,2.25,@"Shift");letters=@"ZXCVBNM";
 for(int i=0;i<7;i++)key(4+[letters characterAtIndex:i]-'A',2.25+i,4.4,1,[letters substringWithRange:NSMakeRange(i,1)]);
 key(0x36,9.25,4.4,1,@",");key(0x37,10.25,4.4,1,@".");key(0x38,11.25,4.4,1,@"/");key(0x69,12.25,4.4,2.75,@"Shift");
 key(0x64,0,5.4,1.25,@"Ctrl · 1st");key(0x67,1.25,5.4,1.25,@"Win · 2nd");key(0x66,2.5,5.4,1.25,@"Alt · 3rd");
 key(0x2c,3.75,5.4,6.25,@"Space");key(0x6a,10,5.4,1.25,@"Alt");key(0x68,11.25,5.4,1.25,@"Ctrl");
 key(0,12.5,5.4,1.25,@"B");key(0,13.75,5.4,1.25,@"A");
 NSArray *nav=@[@"Ins",@"Home",@"PgUp",@"Del",@"End",@"PgDn"];
 for(int i=0;i<6;i++)key(0x49+i,15.5+i%3,1.4+i/3,1,nav[i]);
 key(0x52,16.5,4.4,1,@"↑");key(0x50,15.5,5.4,1,@"←");key(0x51,16.5,5.4,1,@"↓");key(0x4f,17.5,5.4,1,@"→");
 return layout;
}
static NSString *CompactName(NSString *name){
 NSDictionary *shortNames=@{@"Command (left)":@"⌘ Cmd",@"Command (right)":@"⌘ Cmd",@"Option (left)":@"⌥ Opt",@"Option (right)":@"⌥ Opt",@"Control (left)":@"Ctrl",@"Control (right)":@"Ctrl",@"Shift (left)":@"Shift",@"Shift (right)":@"Shift",@"Brightness up":@"Bri +",@"Brightness down":@"Bri −",@"Next track":@"Next",@"Previous track":@"Prev",@"Play / pause":@"Play",@"Volume up":@"Vol +",@"Volume down":@"Vol −",@"Disabled":@"Off",@"Unrecognized mapping":@"Unknown"};
 return shortNames[name]?:name;
}
@interface BD85KeyButton:NSButton
@property NSString *legend,*mapping;
@property BOOL selectedKey,remapped,macroKey,matched,pending;
@end
@implementation BD85KeyButton
- (void)drawRect:(NSRect)dirty{
 (void)dirty;NSRect r=NSInsetRect(self.bounds,1.5,1.5);
 NSBezierPath *shape=[NSBezierPath bezierPathWithRoundedRect:r xRadius:6 yRadius:6];
 NSColor *fill=self.selectedKey?NSColor.controlAccentColor:NSColor.controlBackgroundColor;
 [fill setFill];[shape fill];
 [(self.pending?NSColor.systemOrangeColor:(self.selectedKey?NSColor.controlAccentColor:[NSColor.separatorColor colorWithAlphaComponent:0.3])) setStroke];shape.lineWidth=(self.selectedKey||self.pending)?2:0.7;[shape stroke];
 NSColor *ink=self.selectedKey?NSColor.whiteColor:(self.matched?NSColor.labelColor:NSColor.tertiaryLabelColor);
 if(self.highlighted){[[NSColor.labelColor colorWithAlphaComponent:0.08] setFill];[shape fill];}
 NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.alignment=NSTextAlignmentCenter;style.lineBreakMode=NSLineBreakByTruncatingTail;
 BOOL detail=self.remapped||self.macroKey;
 NSString *main=detail?self.mapping:self.legend;
 CGFloat size=main.length>9?10:12;
 NSRect textRect=NSMakeRect(4,detail?NSHeight(r)*0.35:((NSHeight(self.bounds)-17)/2),NSWidth(self.bounds)-8,18);
 [main drawInRect:textRect withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:size weight:NSFontWeightMedium],NSForegroundColorAttributeName:ink,NSParagraphStyleAttributeName:style}];
 if(detail){
  [self.legend drawInRect:NSMakeRect(4,NSHeight(self.bounds)-17,NSWidth(self.bounds)-8,12) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:10],NSForegroundColorAttributeName:[ink colorWithAlphaComponent:0.75],NSParagraphStyleAttributeName:style}];

 }
 if(self.window.firstResponder==self){NSSetFocusRingStyle(NSFocusRingOnly);[shape fill];}
}
@end
@interface BD85KeyboardView:NSView
@property NSArray *layoutItems,*keyButtons;
@end
@implementation BD85KeyboardView
- (BOOL)isFlipped{return YES;}
- (void)layout{
 [super layout];CGFloat unit=(self.bounds.size.width-24)/18.5;
 for(NSUInteger i=0;i<self.layoutItems.count;i++){
  NSDictionary *item=self.layoutItems[i];NSButton *button=self.keyButtons[i];
  button.frame=NSMakeRect(12+[item[@"x"] doubleValue]*unit,12+[item[@"y"] doubleValue]*unit,[item[@"w"] doubleValue]*unit-3,unit-3);
 }
}

@end

static NSColor *CanvasColor(void){
 return [NSColor colorWithName:@"85HA canvas" dynamicProvider:^NSColor *(NSAppearance *appearance){
  BOOL dark=[[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua];
  return dark?[NSColor colorWithWhite:0.13 alpha:1]:[NSColor colorWithSRGBRed:247.0/255 green:247.0/255 blue:248.0/255 alpha:1];
 }];
}
@interface BD85Canvas:NSView
@end
@implementation BD85Canvas
- (void)drawRect:(NSRect)dirty{[CanvasColor() setFill];NSRectFill(dirty);}
@end

@interface BD85Card:NSView
@end
@implementation BD85Card
- (void)drawRect:(NSRect)dirty{(void)dirty;[NSColor.controlBackgroundColor setFill];NSBezierPath *p=[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,0.5,0.5) xRadius:12 yRadius:12];[p fill];[[NSColor.separatorColor colorWithAlphaComponent:0.3] setStroke];[p stroke];}
@end
static NSButton *IconButton(NSString *title,NSString *symbol,id target,SEL action){
 NSButton *b=[NSButton buttonWithTitle:title target:target action:action];b.image=[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];b.imagePosition=NSImageLeading;b.imageHugsTitle=YES;b.accessibilityLabel=title;return b;
}
static NSString *ChoiceGroup(NSData *data){const uint8_t *p=data.bytes;if(p[0]==12)return @"Media";if(p[1])return @"Modifiers";return p[2]?@"Keys":@"Other";}
static NSArray *FilterChoices(NSArray *choices,NSString *query,NSString *group){
 return [choices filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,NSDictionary *bindings){(void)bindings;return ([group isEqual:@"All"]||[item[@"group"] isEqual:group])&&(!query.length||[item[@"title"] localizedCaseInsensitiveContainsString:query]);}]];
}
@interface BD85ChoiceTable:NSTableView
@end
@implementation BD85ChoiceTable
- (void)keyDown:(NSEvent *)event{if(event.keyCode==36||event.keyCode==76){[NSApp sendAction:self.action to:self.target from:self];return;}[super keyDown:event];}
@end

@interface BD85Controller:NSObject<NSWindowDelegate,NSTableViewDataSource,NSTableViewDelegate,NSTextFieldDelegate>
@property NSWindow *window;
@property BD85KeyboardView *keyboard;
@property NSTextField *searchResult;
@property NSSearchField *search;
@property NSPopUpButton *destination;
@property NSTextField *connection,*titleLabel,*positionLabel,*currentLabel,*status,*note,*heartReminder;
@property NSButton *save,*reload,*undo,*defaults,*choose,*discard,*details;
@property NSTextField *changeSummary,*pendingLabel,*pickerResult;
@property NSMutableDictionary *drafts;
@property NSButton *macroButton,*macroSave,*macroRemove,*macroKeyButton,*macroUpdate,*macroDelete,*macroUp,*macroDown,*macroAdd,*macroShortcut;
@property NSPanel *macroWindow;
@property NSTextField *macroName,*macroRepeats,*macroDelay,*macroNotice;
@property NSTableView *macroTable;
@property NSPopUpButton *macroAction;
@property NSArray<NSButton *> *macroModifiers;
@property NSMutableArray *macroEvents;
@property NSNumber *macroKey;
@property NSData *macroEventKey;
@property BOOL pickingMacro;
@property NSPanel *picker;
@property NSSearchField *pickerSearch;
@property NSSegmentedControl *pickerCategories;
@property NSTableView *pickerTable;
@property NSArray *choices,*choiceRows;
@property NSArray *catalog,*rows;
@property NSDictionary *state,*undoRecord;
@property NSNumber *selected;
@property BOOL busy,demo;
@property dispatch_queue_t ioQueue;
@property NSString *backupDir;
@end
@implementation BD85Controller
- (instancetype)init{
 if(!(self=[super init]))return nil;
 _catalog=Catalog();_rows=_catalog;_drafts=[NSMutableDictionary new];_selected=@0x66;_ioQueue=dispatch_queue_create("local.8bitdo.85ha.editor",DISPATCH_QUEUE_SERIAL);
 _demo=[NSProcessInfo.processInfo.arguments containsObject:@"--85ha-demo"];
 NSString *support=[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES) firstObject];
 _backupDir=[support stringByAppendingPathComponent:@"8BitDo 85HA Editor/Backups"];
 [self buildWindow];return self;
}
- (void)buildWindow{
 self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1120,830) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
 self.window.contentView=[[BD85Canvas alloc]initWithFrame:self.window.contentView.bounds];self.window.backgroundColor=CanvasColor();
 self.window.title=@"85HA Keyboard";self.window.delegate=self;self.window.minSize=NSMakeSize(1040,800);self.window.releasedWhenClosed=NO;
 NSTextField *heading=Label(@"85HA Keyboard",23,YES);self.connection=Label(@"Reading keyboard…",12,NO);self.connection.textColor=NSColor.secondaryLabelColor;
 NSStackView *headingGroup=Stack(@[heading,self.connection],NSUserInterfaceLayoutOrientationVertical,5);
 self.reload=IconButton(@"Reload",@"arrow.clockwise",self,@selector(reloadClicked:));self.reload.toolTip=@"Read the saved profile again. Unsaved choices stay in this window.";
 NSButton *backups=IconButton(@"Backups",@"folder",self,@selector(showBackups:));
 NSView *headerSpace=[NSView new];NSStackView *header=Stack(@[headingGroup,headerSpace,self.reload,backups],NSUserInterfaceLayoutOrientationHorizontal,12);
 [headingGroup setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
 self.search=[[NSSearchField alloc]initWithFrame:NSZeroRect];self.search.placeholderString=@"Find a key on your keyboard";self.search.target=self;self.search.action=@selector(filterChanged:);self.search.sendsSearchStringImmediately=YES;
 self.searchResult=Label(@"",13,NO);self.searchResult.textColor=NSColor.secondaryLabelColor;
 NSView *searchSpace=[NSView new];NSStackView *searchBar=Stack(@[self.searchResult,searchSpace,self.search],NSUserInterfaceLayoutOrientationHorizontal,16);
 self.keyboard=[BD85KeyboardView new];self.keyboard.layoutItems=KeyboardLayout();NSMutableArray *buttons=[NSMutableArray new];
 for(NSDictionary *item in self.keyboard.layoutItems){
  BD85KeyButton *button=[[BD85KeyButton alloc]initWithFrame:NSZeroRect];button.tag=[item[@"key"] integerValue];button.legend=item[@"legend"];button.mapping=@"";button.matched=YES;
  button.title=button.legend;button.bordered=NO;button.buttonType=NSButtonTypeMomentaryPushIn;button.target=self;button.action=@selector(keyClicked:);
  if(!button.tag){button.enabled=NO;button.matched=NO;button.toolTip=@"Special button — editing is not supported";button.accessibilityLabel=[button.legend stringByAppendingString:@", special button, unavailable"];}
  [buttons addObject:button];[self.keyboard addSubview:button];
 }
 self.keyboard.keyButtons=buttons;
 NSTextField *legend=Label(@"Small labels show the original keys. A / B editing is unavailable.",12,NO);legend.textColor=NSColor.secondaryLabelColor;
 self.titleLabel=Label(@"Choose a key",22,YES);self.positionLabel=Label(@"",12,NO);self.positionLabel.textColor=NSColor.secondaryLabelColor;
 self.currentLabel=Label(@"",14,NO);
 NSStackView *selection=Stack(@[Label(@"SELECTED KEY",10,YES),self.titleLabel,self.positionLabel,self.currentLabel],NSUserInterfaceLayoutOrientationVertical,10);
 // Keep the validated destination model; the visible chooser is searchable.
 self.destination=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];self.destination.menu.autoenablesItems=NO;[self fillDestinations];
 self.choose=IconButton(@"Choose a mapping…",@"chevron.down",self,@selector(openPicker:));self.choose.imagePosition=NSImageTrailing;self.choose.controlSize=NSControlSizeLarge;self.choose.font=[NSFont systemFontOfSize:16 weight:NSFontWeightMedium];self.choose.alignment=NSTextAlignmentLeft;
 self.defaults=[NSButton buttonWithTitle:@"Use original mapping" target:self action:@selector(defaultClicked:)];
 self.discard=[NSButton buttonWithTitle:@"Discard this change" target:self action:@selector(discardClicked:)];
 self.macroButton=[NSButton buttonWithTitle:@"Create macro…" target:self action:@selector(openMacro:)];
 NSStackView *secondary=Stack(@[self.defaults,self.discard,self.macroButton],NSUserInterfaceLayoutOrientationHorizontal,10);
 self.changeSummary=Label(@"",13,NO);self.pendingLabel=Label(@"",12,YES);
 NSStackView *editor=Stack(@[Label(@"ASSIGN TO",10,YES),self.choose,self.changeSummary,secondary],NSUserInterfaceLayoutOrientationVertical,10);
 NSStackView *body=Stack(@[selection,editor],NSUserInterfaceLayoutOrientationHorizontal,28);
 self.save=[NSButton buttonWithTitle:@"Save to keyboard" target:self action:@selector(saveClicked:)];self.save.bezelStyle=NSBezelStyleRounded;self.save.bezelColor=NSColor.controlAccentColor;self.save.controlSize=NSControlSizeLarge;
 self.undo=IconButton(@"Undo last save",@"arrow.uturn.backward",self,@selector(undoClicked:));
 NSView *actionSpace=[NSView new];NSStackView *actions=Stack(@[self.pendingLabel,actionSpace,self.undo,self.save],NSUserInterfaceLayoutOrientationHorizontal,12);
 self.note=Label(@"",12,NO);self.note.textColor=NSColor.secondaryLabelColor;
 NSBox *line=[NSBox new];line.boxType=NSBoxSeparator;
 NSStackView *cardStack=Stack(@[body,line,actions,self.note],NSUserInterfaceLayoutOrientationVertical,12);cardStack.translatesAutoresizingMaskIntoConstraints=NO;
 BD85Card *card=[BD85Card new];[card addSubview:cardStack];
 self.status=Label(@"",12,NO);self.status.maximumNumberOfLines=3;self.status.textColor=NSColor.secondaryLabelColor;
 self.details=IconButton(@"Connection & help",@"info.circle",self,@selector(showDetails:));self.details.bordered=NO;
 self.heartReminder=Label(@"Turn the keyboard’s heart light on to use your saved mappings.",12,NO);self.heartReminder.textColor=NSColor.secondaryLabelColor;
 NSStackView *messages=Stack(@[self.status,self.heartReminder],NSUserInterfaceLayoutOrientationHorizontal,14);
 NSView *footerSpace=[NSView new];NSStackView *footer=Stack(@[messages,footerSpace,self.details],NSUserInterfaceLayoutOrientationHorizontal,12);
 NSView *spacer=[NSView new];
 NSStackView *root=Stack(@[header,searchBar,self.keyboard,legend,card,footer,spacer],NSUserInterfaceLayoutOrientationVertical,16);root.translatesAutoresizingMaskIntoConstraints=NO;
 [self.window.contentView addSubview:root];NSView *content=self.window.contentView;
 NSMutableArray *constraints=[NSMutableArray arrayWithArray:@[
  [root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:24],[root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-24],
  [root.topAnchor constraintEqualToAnchor:content.topAnchor constant:22],[root.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-18],
  [self.search.widthAnchor constraintEqualToConstant:280],
  [self.keyboard.heightAnchor constraintEqualToAnchor:self.keyboard.widthAnchor multiplier:6.4/18.5 constant:24-24*6.4/18.5],
  [cardStack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],[cardStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
  [cardStack.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],[cardStack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
  [selection.widthAnchor constraintEqualToAnchor:body.widthAnchor multiplier:0.4 constant:-14],[editor.widthAnchor constraintEqualToAnchor:body.widthAnchor multiplier:0.6 constant:-14],
  [self.choose.widthAnchor constraintEqualToAnchor:editor.widthAnchor],[self.changeSummary.widthAnchor constraintEqualToAnchor:editor.widthAnchor],
  [self.titleLabel.widthAnchor constraintEqualToAnchor:selection.widthAnchor],[self.positionLabel.widthAnchor constraintEqualToAnchor:selection.widthAnchor],
  [messages.widthAnchor constraintLessThanOrEqualToAnchor:footer.widthAnchor multiplier:0.82],[self.status.widthAnchor constraintLessThanOrEqualToAnchor:messages.widthAnchor multiplier:0.4],[spacer.heightAnchor constraintGreaterThanOrEqualToConstant:0]
 ]];
 for(NSView *v in @[header,searchBar,self.keyboard,legend,card,footer,spacer])[constraints addObject:[v.widthAnchor constraintEqualToAnchor:root.widthAnchor]];
 for(NSView *v in @[body,line,actions,self.note])[constraints addObject:[v.widthAnchor constraintEqualToAnchor:cardStack.widthAnchor]];
 [NSLayoutConstraint activateConstraints:constraints];[self.window center];[self updateSelection];
}

#include "MacroEditor.inc"

- (void)showDetails:(id)sender{
 (void)sender;NSUInteger unknown=0;for(NSDictionary *entry in self.state[@"mappings"]){int type=[entry[@"type"] intValue];if(type!=7&&type!=12)unknown++;}
 NSAlert *alert=[NSAlert new];alert.messageText=@"Connection & saving";
 alert.informativeText=[NSString stringWithFormat:@"Connect the keyboard by USB with its selector OFF. Turn the heart light ON to use your onboard profile.\n\nEach save changes one key, creates a backup, and checks the result. macOS administrator authorization is needed for USB access.\n\nMacros support key presses, releases, and pauses. The special A / B buttons cannot be edited. %lu unrecognized profile entries are preserved.\n\nUnsaved choices stay in this window when you switch keys or reload. Undo restores the last saved key; reloading clears Undo.",(unsigned long)unknown];
 [alert addButtonWithTitle:@"Got it"];[alert beginSheetModalForWindow:self.window completionHandler:nil];
}
- (void)openPicker:(id)sender{
 self.pickingMacro=(sender==self.macroKeyButton);if(self.pickingMacro?!self.macroKeyButton.enabled:!self.choose.enabled)return;
 if(!self.picker){
  self.picker=[[NSPanel alloc]initWithContentRect:NSMakeRect(0,0,450,450) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];self.picker.title=@"Choose a mapping";
  NSViewController *vc=[NSViewController new];vc.view=[[NSView alloc]initWithFrame:NSMakeRect(0,0,450,450)];self.picker.contentViewController=vc;
  self.pickerSearch=[[NSSearchField alloc]initWithFrame:NSZeroRect];self.pickerSearch.placeholderString=@"Search mappings, e.g. Command or F13";self.pickerSearch.sendsSearchStringImmediately=YES;self.pickerSearch.target=self;self.pickerSearch.action=@selector(filterPicker:);
  self.pickerCategories=[NSSegmentedControl segmentedControlWithLabels:@[@"All",@"Keys",@"Modifiers",@"Media"] trackingMode:NSSegmentSwitchTrackingSelectOne target:self action:@selector(filterPicker:)];self.pickerCategories.selectedSegment=0;
  self.pickerTable=[[BD85ChoiceTable alloc]initWithFrame:NSZeroRect];self.pickerTable.dataSource=self;self.pickerTable.delegate=self;self.pickerTable.rowHeight=34;self.pickerTable.headerView=nil;self.pickerTable.target=self;self.pickerTable.action=@selector(pickMapping:);self.pickerTable.allowsEmptySelection=YES;self.pickerTable.accessibilityLabel=@"Supported mappings";
  NSTableColumn *name=[[NSTableColumn alloc]initWithIdentifier:@"name"];name.width=298;name.editable=NO;[self.pickerTable addTableColumn:name];
  NSTableColumn *type=[[NSTableColumn alloc]initWithIdentifier:@"type"];type.width=100;type.editable=NO;[self.pickerTable addTableColumn:type];
  NSScrollView *scroll=[NSScrollView new];scroll.documentView=self.pickerTable;scroll.hasVerticalScroller=YES;scroll.borderType=NSNoBorder;
  self.pickerResult=Label(@"",12,NO);self.pickerResult.textColor=NSColor.secondaryLabelColor;
  NSButton *cancel=[NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelPicker:)];cancel.keyEquivalent=@"\033";
  NSStackView *root=Stack(@[Label(@"Choose a mapping",17,YES),self.pickerSearch,self.pickerCategories,scroll,self.pickerResult,cancel],NSUserInterfaceLayoutOrientationVertical,12);root.translatesAutoresizingMaskIntoConstraints=NO;[vc.view addSubview:root];
  NSMutableArray *constraints=[NSMutableArray arrayWithArray:@[[root.leadingAnchor constraintEqualToAnchor:vc.view.leadingAnchor constant:16],[root.trailingAnchor constraintEqualToAnchor:vc.view.trailingAnchor constant:-16],[root.topAnchor constraintEqualToAnchor:vc.view.topAnchor constant:16],[root.bottomAnchor constraintEqualToAnchor:vc.view.bottomAnchor constant:-16],[scroll.heightAnchor constraintEqualToConstant:240]]];
  for(NSView *v in @[self.pickerSearch,self.pickerCategories,scroll,self.pickerResult])[constraints addObject:[v.widthAnchor constraintEqualToAnchor:root.widthAnchor]];
  [NSLayoutConstraint activateConstraints:constraints];
 }
 NSMutableArray *choices=[NSMutableArray new];for(NSMenuItem *item in self.destination.itemArray)if([item.representedObject isKindOfClass:NSData.class]&&(!self.pickingMacro||([item.representedObject length]==24&&((const uint8_t *)[item.representedObject bytes])[0]==7&&(!!((const uint8_t *)[item.representedObject bytes])[1]!=!!((const uint8_t *)[item.representedObject bytes])[2]))))[choices addObject:@{@"title":item.title,@"data":item.representedObject,@"group":ChoiceGroup(item.representedObject)}];self.choices=choices;
 self.pickerSearch.stringValue=@"";self.pickerCategories.selectedSegment=0;[self filterPicker:nil];
 [(self.pickingMacro?self.macroWindow:self.window) beginSheet:self.picker completionHandler:nil];[self.picker makeFirstResponder:self.pickerSearch];
}
- (void)cancelPicker:(id)sender{(void)sender;[self.picker.sheetParent endSheet:self.picker];[self.picker orderOut:nil];}
- (void)filterPicker:(id)sender{
 (void)sender;self.choiceRows=FilterChoices(self.choices,self.pickerSearch.stringValue,[self.pickerCategories labelForSegment:self.pickerCategories.selectedSegment]);
 [self.pickerTable reloadData];[self.pickerTable deselectAll:nil];
 if(self.choiceRows.count){[self.pickerTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];[self.pickerTable scrollRowToVisible:0];}
 self.pickerResult.stringValue=self.choiceRows.count?[NSString stringWithFormat:@"%lu supported %@ · Click to choose",(unsigned long)self.choiceRows.count,self.choiceRows.count==1?@"mapping":@"mappings"]:@"No supported mappings match. Try another search or category.";
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)table{return table==self.macroTable?self.macroEvents.count:self.choiceRows.count;}
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row{if(table==self.macroTable){NSDictionary *step=self.macroEvents[row];unsigned action=[step[@"action"] unsignedIntValue],value=[step[@"value"] unsignedIntValue];if([column.identifier isEqual:@"step"])return @(row+1);if([column.identifier isEqual:@"action"])return action==15?@"Pause":(action&0x80?@"Press":@"Release");return action==15?[NSString stringWithFormat:@"%u ms",value]:(action==3||action==0x83?ModifierNames()[@(value)]:UsageName(value));}return self.choiceRows[row][[column.identifier isEqual:@"name"]?@"title":@"group"];}
- (void)pickMapping:(id)sender{
 (void)sender;NSInteger row=self.pickerTable.selectedRow;
 if(row<0||row>=(NSInteger)self.choiceRows.count||(self.pickingMacro?!self.macroKeyButton.enabled:!self.choose.enabled))return;
 if(self.pickingMacro){self.macroEventKey=self.choiceRows[row][@"data"];self.macroKeyButton.title=MappingName(self.macroEventKey,0);[self cancelPicker:nil];return;}
 [self selectPayload:self.choiceRows[row][@"data"]];[self destinationChanged:nil];[self cancelPicker:nil];[self.window makeFirstResponder:self.choose];
}

- (void)addChoice:(NSString *)title data:(NSData *)data{
 [self.destination addItemWithTitle:title];self.destination.lastItem.representedObject=data;
}
- (void)fillDestinations{
 for(NSNumber *modifier in [[ModifierNames() allKeys] sortedArrayUsingSelector:@selector(compare:)])[self addChoice:ModifierNames()[modifier] data:Payload(7,modifier.intValue,0)];
 [self.destination.menu addItem:NSMenuItem.separatorItem];
 for(NSNumber *media in [[MediaNames() allKeys] sortedArrayUsingSelector:@selector(compare:)])[self addChoice:MediaNames()[media] data:Payload(12,media.intValue&255,media.intValue>>8)];
 [self.destination.menu addItem:NSMenuItem.separatorItem];
 for(NSDictionary *item in self.catalog)if([item[@"key"] intValue]<0x64)[self addChoice:item[@"name"] data:Default([item[@"key"] intValue])];
 for(int n=13;n<=24;n++)[self addChoice:[NSString stringWithFormat:@"F%d",n] data:Payload(7,0,0x68+n-13)];
 [self.destination.menu addItem:NSMenuItem.separatorItem];[self addChoice:@"Disabled" data:Payload(7,0,0)];
}
- (BOOL)isMacro:(NSNumber *)key{return [self.state[@"macroKeys"] containsObject:key];}
- (void)selectPayload:(NSData *)data{
 for(NSMenuItem *item in self.destination.itemArray)if([item.representedObject isEqual:data]){[self.destination selectItem:item];return;}
 [self addChoice:[@"Current: " stringByAppendingString:MappingName(data,self.selected.intValue)] data:data];[self.destination selectItem:self.destination.lastItem];
}
- (void)updateSelection{
 if(!self.selected){self.titleLabel.stringValue=@"No matching keys";self.positionLabel.stringValue=@"";self.positionLabel.hidden=YES;self.currentLabel.stringValue=@"Try another search.";[self updateButtons];return;}
 NSDictionary *selected=nil;for(NSDictionary *item in self.catalog)if([item[@"key"] isEqual:self.selected])selected=item;
 self.titleLabel.stringValue=selected[@"name"]?:@"Choose a key";self.positionLabel.stringValue=[selected[@"position"] length]?selected[@"position"]:@"";self.positionLabel.hidden=!self.positionLabel.stringValue.length;
 NSData *raw=Raw(self.state,self.selected);BOOL macro=[self isMacro:self.selected];
 self.currentLabel.stringValue=self.state?(macro?[@"Macro: " stringByAppendingString:self.state[@"macroDefinitions"][self.selected.stringValue][@"name"]?:@"Unreadable macro"]:[@"Saved: " stringByAppendingString:MappingName(raw,self.selected.intValue)]):@"Reload to read the saved mapping.";
 [self selectPayload:self.drafts[self.selected]?: (zero_mapping(raw.bytes)?Default(self.selected.intValue):raw)];[self updateButtons];
}
- (void)updateButtons{
 NSData *raw=Raw(self.state,self.selected),*desired=self.destination.selectedItem.representedObject;
 BOOL valid=self.selected && self.state && raw.length==24 && (zero_mapping(raw.bytes)||mapping_valid(raw.bytes)) && ![self isMacro:self.selected];
 self.destination.enabled=!self.busy&&valid&&!self.demo;self.defaults.enabled=self.destination.enabled;
 self.save.enabled=self.destination.enabled && desired.length==24 && mapping_valid(desired.bytes) && !matches_readback(self.selected.unsignedIntValue,desired.bytes,raw.bytes);
 NSDictionary *macro=self.selected?self.state[@"macroDefinitions"][self.selected.stringValue]:nil;
 self.macroButton.title=[self isMacro:self.selected]?@"Edit macro…":@"Create macro…";
 self.macroButton.enabled=!self.busy&&!self.demo&&self.state&&self.selected&&([self isMacro:self.selected]?[macro[@"editable"] boolValue]:valid);
 self.choose.enabled=self.destination.enabled;self.choose.title=self.selected?MappingName(desired,self.selected.intValue):@"Choose a key first";
 self.choose.accessibilityLabel=[@"Assign to: " stringByAppendingString:self.choose.title];
 self.discard.enabled=!self.busy&&self.selected&&self.drafts[self.selected]!=nil;
 BOOL dirty=self.selected&&self.drafts[self.selected]!=nil;
 self.changeSummary.stringValue=!self.selected?@"Search for a key to start editing.":(!self.state?@"Connect by USB, then reload.":([self isMacro:self.selected]?@"This key runs a sequence. Use Edit macro to change it.":(dirty?[NSString stringWithFormat:@"%@ → %@",MappingName(raw,self.selected.intValue),MappingName(desired,self.selected.intValue)]:@"This mapping is already saved on the keyboard.")));
 self.pendingLabel.stringValue=self.drafts.count?[NSString stringWithFormat:@"%lu unsaved %@",(unsigned long)self.drafts.count,self.drafts.count==1?@"change":@"changes"]:@"No unsaved changes";
 self.pendingLabel.textColor=self.drafts.count?NSColor.labelColor:NSColor.secondaryLabelColor;
 self.note.stringValue=self.drafts.count?@"Save applies the selected key only. macOS will ask for authorization; a backup is created automatically.":@"";self.note.hidden=!self.drafts.count;self.heartReminder.hidden=!self.state;
 self.save.title=self.drafts.count>1?@"Save this key":@"Save to keyboard";
 self.defaults.toolTip=self.selected?[@"Original: " stringByAppendingString:MappingName(Default(self.selected.intValue),self.selected.intValue)]:@"";
 self.reload.enabled=!self.busy;self.search.enabled=!self.busy;[self updateKeyboard];
 self.undo.enabled=!self.busy&&!self.demo&&self.undoRecord!=nil&&self.state!=nil;
}
- (void)updateKeyboard{
 NSMutableSet *matches=[NSMutableSet new];for(NSDictionary *item in self.rows)[matches addObject:item[@"key"]];
 for(BD85KeyButton *button in self.keyboard.keyButtons){
  if(!button.tag)continue;NSNumber *key=@(button.tag);NSData *raw=Raw(self.state,key);
  button.selectedKey=[self.selected isEqual:key];button.matched=[matches containsObject:key];button.enabled=!self.busy&&button.matched;
  button.macroKey=[self isMacro:key];button.remapped=self.state&&!matches_readback((unsigned)button.tag,Default((int)button.tag).bytes,raw.bytes);
  NSString *mapping=self.state?(button.macroKey?@"Macro":MappingName(raw,(int)button.tag)):@"Not loaded";
  button.mapping=CompactName(mapping);button.pending=self.drafts[key]!=nil;
  NSDictionary *physical=nil;for(NSDictionary *item in self.catalog)if([item[@"key"] isEqual:key]){physical=item;break;}
  NSString *description=[NSString stringWithFormat:@"%@%@ — %@%@",physical[@"name"],[physical[@"position"] length]?[@" · " stringByAppendingString:physical[@"position"]]:@"",mapping,button.macroKey?@" (macro)":@""];
  button.toolTip=description;button.accessibilityLabel=description;button.accessibilityValue=button.pending?(button.selectedKey?@"Selected, unsaved change":@"Unsaved change"):(button.selectedKey?@"Selected":@"");button.needsDisplay=YES;
 }
 self.searchResult.stringValue=self.search.stringValue.length?[NSString stringWithFormat:@"%lu matching %@",(unsigned long)self.rows.count,self.rows.count==1?@"key":@"keys"]:@"";
}
- (void)keyClicked:(BD85KeyButton *)sender{
 if(self.busy||!sender.enabled||!sender.tag)return;
 self.selected=@(sender.tag);[self updateSelection];
}
- (void)filterChanged:(id)sender{
 (void)sender;NSString *query=self.search.stringValue;NSNumber *wanted=self.selected;
 self.rows=[self.catalog filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,NSDictionary *bindings){(void)bindings;return !query.length || [item[@"name"] localizedCaseInsensitiveContainsString:query] || [MappingName(Raw(self.state,item[@"key"]),[item[@"key"] intValue]) localizedCaseInsensitiveContainsString:query];}]];
 NSUInteger index=SelectedIndex(self.rows,wanted);
 self.selected=index!=NSNotFound?self.rows[index][@"key"]:nil;
 [self updateSelection];
}
- (void)destinationChanged:(id)sender{
 (void)sender;if(!self.selected||!self.state||[self isMacro:self.selected])return;
 NSData *data=self.destination.selectedItem.representedObject;if(data.length!=24||!mapping_valid(data.bytes))return;
 if(matches_readback(self.selected.unsignedIntValue,data.bytes,Raw(self.state,self.selected).bytes))[self.drafts removeObjectForKey:self.selected];else self.drafts[self.selected]=data;
 [self updateButtons];
}
- (void)discardClicked:(id)sender{(void)sender;if(self.busy||!self.selected)return;[self.drafts removeObjectForKey:self.selected];[self updateSelection];}
- (void)defaultClicked:(id)sender{(void)sender;[self selectPayload:Default(self.selected.intValue)];[self destinationChanged:nil];}
- (void)show:(id)sender{(void)sender;[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];}
- (BOOL)canClose{
 if(self.busy)return NO;if(!self.drafts.count&&!self.macroWindow.sheetParent)return YES;
 NSAlert *alert=[NSAlert new];alert.messageText=@"You have unsaved changes";alert.informativeText=@"Keep editing to save them to your keyboard, or discard them and close.";
 [alert addButtonWithTitle:@"Keep editing"];[alert addButtonWithTitle:@"Discard and close"];
 if([alert runModal]!=NSAlertSecondButtonReturn)return NO;[self.drafts removeAllObjects];return YES;
}
- (BOOL)windowShouldClose:(NSWindow *)sender{(void)sender;return [self canClose];}
- (void)reloadClicked:(id)sender{
 (void)sender;if(self.busy)return;self.busy=YES;self.status.stringValue=@"Reading saved mappings…";[self updateButtons];
 dispatch_async(self.ioQueue,^{@autoreleasepool{
  NSDictionary *snapshot=nil;NSString *error=nil;
  @try{if(self.demo){NSData *d=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"DemoProfile.json"]];snapshot=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil];if(!snapshot)Throw(@"Preview data unavailable.");}else snapshot=ReadSnapshot();}@catch(NSException *e){error=e.reason;}
  dispatch_async(dispatch_get_main_queue(),^{self.state=snapshot;self.undoRecord=nil;self.busy=NO;
   self.connection.stringValue=snapshot?[NSString stringWithFormat:@"%@ · onboard profile “%@”",self.demo?@"Preview — saving disabled":@"Connected by USB",snapshot[@"profile"]]:@"Keyboard unavailable";
   if(snapshot)for(NSNumber *key in [self.drafts.allKeys copy])if([self isMacro:key]||matches_readback(key.unsignedIntValue,[(NSData *)self.drafts[key] bytes],Raw(snapshot,key).bytes))[self.drafts removeObjectForKey:key];
   self.status.stringValue=error?:@"Profile loaded. Saves are backed up and verified.";
   [self filterChanged:nil];[self updateSelection];
  });
 }});
}
- (void)showBackups:(id)sender{(void)sender;NSError *e=nil;if(![NSFileManager.defaultManager createDirectoryAtPath:self.backupDir withIntermediateDirectories:YES attributes:nil error:&e]){self.status.stringValue=e.localizedDescription;return;}[NSWorkspace.sharedWorkspace openURL:[NSURL fileURLWithPath:self.backupDir]];}
- (void)saveClicked:(id)sender{(void)sender;[self saveKey:self.selected target:self.destination.selectedItem.representedObject undo:NO];}
- (void)undoClicked:(id)sender{
 (void)sender;if(!self.undoRecord)return;
 if([self.undoRecord[@"kind"] isEqual:@"macro"]){if(![self.state isEqual:self.undoRecord[@"afterState"]]){self.status.stringValue=@"The profile changed. Reload before continuing.";return;}NSDictionary *definition=self.undoRecord[@"beforeMacro"]==NSNull.null?nil:self.undoRecord[@"beforeMacro"];[self saveMacroKey:self.undoRecord[@"key"] definition:definition mapping:self.undoRecord[@"beforeMapping"] undo:YES];return;}
 NSNumber *key=self.undoRecord[@"key"];
 if(![Raw(self.state,key) isEqual:self.undoRecord[@"after"]]){self.status.stringValue=@"The mapping changed since that save. Reload before continuing.";return;}
 NSData *target=self.undoRecord[@"before"];if(zero_mapping(target.bytes))target=Default(key.intValue);
 [self saveKey:key target:target undo:YES];
}
- (void)saveKey:(NSNumber *)key target:(NSData *)target undo:(BOOL)isUndo{
 if(self.busy||self.demo||!self.state||[self isMacro:key]||target.length!=24||!physical_key(key.unsignedIntValue)||!mapping_valid(target.bytes))return;
 NSDictionary *displayed=self.state;self.busy=YES;self.status.stringValue=@"Backing up mappings before saving…";[self updateButtons];
 dispatch_async(self.ioQueue,^{@autoreleasepool{
  NSDictionary *after=nil,*undo=nil;NSString *error=nil,*backupPath=nil;
  @try{
   NSDictionary *before=ReadSnapshot();if(![before isEqual:displayed])Throw(@"The keyboard changed since it was loaded. Reload before saving.");
   NSData *old=Raw(before,key);if(!(zero_mapping(old.bytes)||mapping_valid(old.bytes)))Throw(@"This mapping cannot be safely restored by this editor.");
   NSArray *macroPackets=before[@"macroPackets"];if(macroPackets.count!=1)Throw(@"This macro layout needs further support. No mapping was written.");
   NSError *ioError=nil;if(![NSFileManager.defaultManager createDirectoryAtPath:self.backupDir withIntermediateDirectories:YES attributes:nil error:&ioError])Throw(ioError.localizedDescription);
   NSString *identifier=NSUUID.UUID.UUIDString;backupPath=[self.backupDir stringByAppendingPathComponent:[identifier stringByAppendingString:@"-before.json"]];
   NSDictionary *record=@{@"snapshot":before,@"key":key,@"requestedMapping":Hex(target),@"createdAt":[[NSISO8601DateFormatter new] stringFromDate:NSDate.date]};
   NSData *backup=[NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&ioError];
   if(!backup||![backup writeToFile:backupPath options:NSDataWritingAtomic error:&ioError])Throw(ioError.localizedDescription?:@"Could not save the backup.");
   NSData *nameBytes=[before[@"profile"] dataUsingEncoding:NSUTF16BigEndianStringEncoding];if(nameBytes.length>28)Throw(@"Unsupported profile name.");
   uint8_t name[33]={0x54,0x80,(uint8_t)nameBytes.length,0};memcpy(name+4,nameBytes.bytes,nameBytes.length);
   NSString *helper=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Helpers/85HAWriter"];
   NSArray *arguments=@[helper,@"--write",[NSString stringWithFormat:@"%02x",key.intValue],Hex(old),Hex(target),Hex([NSData dataWithBytes:name length:33]),Hex([[NSData alloc]initWithBase64EncodedString:macroPackets[0] options:0])];
   NSMutableArray *quoted=[NSMutableArray new];for(NSString *argument in arguments)[quoted addObject:ShellQuote(argument)];
   NSString *script=[NSString stringWithFormat:@"do shell script %@ with administrator privileges",AppleQuote([[quoted componentsJoinedByString:@" "] stringByAppendingString:@" 2>&1"])];
   dispatch_async(dispatch_get_main_queue(),^{self.status.stringValue=@"Authorize the save in the macOS prompt. The keyboard may pause briefly.";});
   NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:@"/usr/bin/osascript"];task.arguments=@[@"-e",script];NSPipe *pipe=[NSPipe pipe];task.standardOutput=pipe;task.standardError=pipe;
   if(![task launchAndReturnError:&ioError])Throw(ioError.localizedDescription);
   NSData *log=[pipe.fileHandleForReading readDataToEndOfFile];[task waitUntilExit];
   [log writeToFile:[self.backupDir stringByAppendingPathComponent:[identifier stringByAppendingString:@"-save.log"]] atomically:YES];
   NSString *output=[[NSString alloc]initWithData:log encoding:NSUTF8StringEncoding]?:@"";
   if(task.terminationStatus || ![output containsString:@"85HA_VERIFIED"]){if([output containsString:@"User canceled"])Throw(@"Save canceled in the macOS authorization prompt.");Throw(@"Save was not confirmed. Reload before continuing; the backup and USB log are saved.");}
   after=ReadAfterSave();if(!Verify(before,after,key,target))Throw(@"Full-profile verification failed. Reload and inspect the saved backup before another change.");
   NSData *verified=[NSJSONSerialization dataWithJSONObject:after options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&ioError];
   if(![verified writeToFile:[self.backupDir stringByAppendingPathComponent:[identifier stringByAppendingString:@"-after.json"]] options:NSDataWritingAtomic error:&ioError])Throw(@"The mapping verified, but its verification record could not be saved.");
   if(!isUndo)undo=@{@"key":key,@"before":old,@"after":Raw(after,key)};
  }@catch(NSException *e){error=e.reason;after=nil;}
  dispatch_async(dispatch_get_main_queue(),^{
   self.busy=NO;self.state=after;self.undoRecord=undo;
   if(after){[self.drafts removeObjectForKey:key];self.selected=key;self.status.stringValue=isUndo?@"Previous mapping restored and verified on the keyboard.":@"Saved and verified on the keyboard.";[self filterChanged:nil];[self updateSelection];}
   else{self.status.stringValue=error?:@"Save failed. Reload before continuing.";self.currentLabel.stringValue=@"Reload to check the keyboard’s current state.";[self updateButtons];}
  });
 }});
}
@end

static BD85Controller *controller;
void BD85StartEditor(void){
 if(!NSApp.mainMenu){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{BD85StartEditor();});return;}
 controller=[BD85Controller new];
 NSMenuItem *top=[[NSMenuItem alloc]initWithTitle:@"85HA Keyboard" action:nil keyEquivalent:@""];NSMenu *menu=[[NSMenu alloc]initWithTitle:@"85HA Keyboard"];
 NSMenuItem *show=[[NSMenuItem alloc]initWithTitle:@"Open 85HA Editor…" action:@selector(show:) keyEquivalent:@"k"];show.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagOption;show.target=controller;[menu addItem:show];top.submenu=menu;[NSApp.mainMenu insertItem:top atIndex:MIN(1,NSApp.mainMenu.numberOfItems)];
 [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){(void)note;if(!controller.window.visible)[controller show:nil];}];
 [controller show:nil];[controller reloadClicked:nil];
}
BOOL BD85IsBusy(void){return controller.busy;}

BOOL BD85CanClose(void){return [controller canClose];}
