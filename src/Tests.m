#import "Editor.m"
#include <assert.h>
int main(void){@autoreleasepool{
 assert(!macro_writes_enabled());
 NSMutableSet *layoutKeys=[NSMutableSet new];NSArray *layout=KeyboardLayout();
 for(NSUInteger i=0;i<layout.count;i++){
  NSDictionary *a=layout[i];NSNumber *key=a[@"key"];
  if(key.intValue){assert(![layoutKeys containsObject:key]);[layoutKeys addObject:key];assert(physical_key(key.intValue));}
  double x=[a[@"x"] doubleValue],y=[a[@"y"] doubleValue],w=[a[@"w"] doubleValue];
  assert(x>=0&&y>=0&&x+w<=18.5&&y+1<=6.4);
  for(NSUInteger j=i+1;j<layout.count;j++){
   NSDictionary *b=layout[j];double bx=[b[@"x"] doubleValue],by=[b[@"y"] doubleValue],bw=[b[@"w"] doubleValue];
   assert(!(x<bx+bw&&bx<x+w&&y<by+1&&by<y+1));
  }
 }
 assert(layoutKeys.count==Catalog().count);
 for(NSDictionary *key in Catalog())assert([layoutKeys containsObject:key[@"key"]]);
 assert(SelectedIndex(@[@{@"key":@0x47}],@0x29)==0);
 assert(SelectedIndex(@[@{@"key":@0x29},@{@"key":@0x47}],@0x47)==1);
 assert(SelectedIndex(@[],@0x47)==NSNotFound);
 assert(zero_mapping(Raw(@{@"mappings":@[]},nil).bytes));
 assert(physical_key(0x66));assert(!physical_key(0x76));assert(!physical_key(0x53));assert(!physical_key(0x32));
 uint8_t decoded[24];assert(!parse_hex("52;touch",decoded,24));assert(!parse_hex("gg",decoded,1));assert(parse_hex("07",decoded,1)&&decoded[0]==7);
 NSData *f13=Payload(7,0,0x68),*bad=Payload(0xfa,0,0);assert(mapping_valid(f13.bytes));assert(!mapping_valid(bad.bytes));
 assert(!mapping_valid(Payload(7,1,4).bytes));assert(!mapping_valid(Payload(12,0xff,0xff).bytes));
 uint8_t trailing[24]={7,0,4};trailing[23]=1;assert(!mapping_valid(trailing));
 NSData *zero=[NSMutableData dataWithLength:24];assert(matches_readback(0x47,Default(0x47).bytes,zero.bytes));assert(!matches_readback(0x47,f13.bytes,zero.bytes));
 NSDictionary *other=@{@"key":@0x66,@"type":@7,@"data":[Payload(7,0xe3,0) base64EncodedStringWithOptions:0]};
 NSDictionary *before=@{@"profile":@"work",@"mappings":@[other],@"macroPackets":@[@"original"]};
 NSDictionary *mapped=@{@"key":@0x47,@"type":@7,@"data":[f13 base64EncodedStringWithOptions:0]};
 NSMutableDictionary *after=[before mutableCopy];after[@"mappings"]=@[other,mapped];assert(Verify(before,after,@0x47,f13));
 after[@"profile"]=@"other";assert(!Verify(before,after,@0x47,f13));after[@"profile"]=@"work";
 after[@"macroPackets"]=@[@"changed"];assert(!Verify(before,after,@0x47,f13));after[@"macroPackets"]=before[@"macroPackets"];
 after[@"mappings"]=@[mapped];assert(!Verify(before,after,@0x47,f13));
 assert([ShellQuote(@"a'b") isEqual:@"'a'\\''b'"]);
 NSArray *choices=@[@{@"title":@"Command (right)",@"group":@"Modifiers"},@{@"title":@"F13",@"group":@"Keys"},@{@"title":@"Volume up",@"group":@"Media"}];
 assert(FilterChoices(choices,@"command",@"All").count==1);
 assert(FilterChoices(choices,@"F13",@"Modifiers").count==0);
 assert(FilterChoices(choices,@"",@"Media").count==1);
 assert(FilterChoices(choices,@"no-match",@"All").count==0);
 // Golden device capture: screenshot macro with two read packets.
 NSArray *encoded=@[@"VIRGFAAAcwBjAHIAZQBlAG4AcwBoAG8AdAAAAAAAAAAA",@"VIZGAQAAGgEBAAqD4gAPIACD4QAPXQCBIQAPPwABIQAP",@"VIZGABoACB8AA+EAA+IAAAAAAAAAAAAAAAAAAAAAAAAA"];
 NSMutableArray *reports=[NSMutableArray new];for(NSString *s in encoded)[reports addObject:[[NSData alloc]initWithBase64EncodedString:s options:0]];
 NSDictionary *shot=MacroDefinition(reports,0x46);assert([shot[@"editable"] boolValue]);assert([shot[@"name"] isEqual:@"screenshot"]);
 NSData *sequence=[[NSData alloc]initWithBase64EncodedString:shot[@"data"] options:0];assert(sequence.length==34&&macro_valid(sequence.bytes,34));
 uint8_t packet[33];assert(macro_packet(0x46,sequence.bytes,34,0,packet)==25);assert(packet[3]==1&&packet[4]==0&&packet[6]==25&&!memcmp(packet+7,sequence.bytes,25));
 assert(macro_packet(0x46,sequence.bytes,34,25,packet)==9);assert(!packet[3]&&packet[4]==25&&packet[6]==9&&!memcmp(packet+7,(const uint8_t *)sequence.bytes+25,9));
 assert(!macro_packet(0x46,sequence.bytes,34,24,packet));assert(!macro_packet(0x46,sequence.bytes,34,34,packet));
 assert(macro_remove_packet(0x46,sequence.bytes,34,packet));
 const uint8_t expectedRemoval[33]={0x52,0x77,0x46,10};assert(!memcmp(packet,expectedRemoval,33));
 assert(!macro_remove_packet(0x46,sequence.bytes,33,packet));assert(!macro_remove_packet(0x74,sequence.bytes,34,packet));
 NSMutableData *broken=[sequence mutableCopy];uint8_t *bp=broken.mutableBytes;bp[1]=0;assert(!macro_valid(bp,34));bp[1]=1;bp[31]=0x83;assert(!macro_valid(bp,34));
 assert(!macro_valid(sequence.bytes,33));assert(!MacroDefinition(@[reports[0],reports[2]],0x46));assert(!MacroDefinition(reports,0x47));
 uint8_t chord[]={1,1,0,3,0x81,0x68,0,15,30,0,1,0x68,0};assert(macro_valid(chord,sizeof(chord)));
 chord[5]=0xe3;assert(!macro_valid(chord,sizeof(chord)));chord[5]=0x68;chord[8]=0xff;chord[9]=0xff;assert(!macro_valid(chord,sizeof(chord)));
 chord[8]=0x10;chord[9]=0x27;chord[1]=100;assert(!macro_valid(chord,sizeof(chord)));
 uint8_t goodName[]={0,65},badName[]={0xd8,0};assert(macro_name_valid(goodName,2));assert(!macro_name_valid(goodName,1));assert(!macro_name_valid(badName,2));
 uint8_t many[4+3*128]={1,1,0,128};for(unsigned i=0;i<128;i++){many[4+i*3]=i%2?1:0x81;many[5+i*3]=4;}assert(macro_valid(many,sizeof(many)));
 assert(macro_remove_packet(0x47,many,sizeof(many),packet)&&packet[3]==128);
 unsigned offset=0,pages=0;while(offset<sizeof(many)){unsigned n=macro_packet(0x47,many,sizeof(many),offset,packet);assert(n&&packet[4]+256u*packet[5]==offset);if(pages&&offset+n<sizeof(many))assert(n==24);offset+=n;pages++;}assert(pages==17);
 // Changing one macro must not mask collateral changes to mappings, names or sequences.
 uint8_t list[33]={0x54,0x82,0x46,34,0,20};NSString *(^b64)(const uint8_t *,NSUInteger)=^NSString *(const uint8_t *p,NSUInteger n){return [[NSData dataWithBytes:p length:n] base64EncodedStringWithOptions:0];};
 NSMutableDictionary *mb=[before mutableCopy];mb[@"macroPackets"]=@[b64(list,33)];mb[@"macroKeys"]=@[@0x46];mb[@"macroDefinitions"]=@{@"70":shot};
 NSMutableDictionary *ma=[mb mutableCopy];list[6]=0x47;list[7]=13;list[9]=2;ma[@"macroPackets"]=@[b64(list,33)];ma[@"macroKeys"]=@[@0x46,@0x47];
 uint8_t safe[]={1,1,0,3,0x81,0x68,0,15,30,0,1,0x68,0};NSDictionary *added=@{@"name":@"A",@"data":b64(safe,sizeof(safe)),@"editable":@YES};
 ma[@"macroDefinitions"]=@{@"70":shot,@"71":added};ma[@"mappings"]=@[other,@{@"key":@0x47,@"type":@7,@"data":b64(Payload(7,0,0).bytes,24)}];
 assert(VerifyMacro(mb,ma,@0x47,added,Payload(7,0,0)));assert(VerifyMacro(ma,mb,@0x47,nil,Default(0x47)));
 ma[@"macroDefinitions"]=@{@"70":added,@"71":added};assert(!VerifyMacro(mb,ma,@0x47,added,Payload(7,0,0)));ma[@"macroDefinitions"]=@{@"70":shot,@"71":added};
 ma[@"mappings"]=@[];assert(!VerifyMacro(mb,ma,@0x47,added,Payload(7,0,0)));
 assert(MacrosWritable(mb));list[7]=0xff;list[8]=0xff;ma[@"macroPackets"]=@[b64(list,33)];assert(!MacrosWritable(ma));assert(!macro_list_writable(list,33));
 NSData *spaced=MacroEncodedName(@"F13 test");assert([Hex(spaced) isEqual:@"00460031003320000074006500730074"]);assert(!MacroEncodedName(@"\u2000"));
 uint8_t spacedName[33]={0x54,0x84,0x46,16,0};memcpy(spacedName+5,spaced.bytes,spaced.length);NSMutableArray *spacedReports=[reports mutableCopy];spacedReports[0]=[NSData dataWithBytes:spacedName length:33];assert([MacroDefinition(spacedReports,0x46)[@"name"] isEqual:@"F13 test"]);
 [NSApplication sharedApplication];BD85Controller *ui=[BD85Controller new];ui.state=before;
 ui.selected=@0x66;[ui updateSelection];[ui selectPayload:f13];[ui destinationChanged:nil];
 assert(ui.drafts.count==1 && ui.save.enabled);
 ui.selected=@0x47;[ui updateSelection];assert(!ui.save.enabled);
 ui.selected=@0x66;[ui updateSelection];assert([ui.destination.selectedItem.representedObject isEqual:f13] && ui.save.enabled);
 ui.search.stringValue=@"no-match";[ui filterChanged:nil];assert(!ui.selected && !ui.choose.enabled && !ui.save.enabled && ui.drafts.count==1);
 ui.search.stringValue=@"third";[ui filterChanged:nil];assert([ui.selected isEqual:@0x66] && [ui.destination.selectedItem.representedObject isEqual:f13]);
 [ui discardClicked:nil];assert(!ui.drafts.count&&!ui.save.enabled);
 NSMutableDictionary *macroState=[before mutableCopy];macroState[@"macroKeys"]=@[@0x46];ui.state=macroState;ui.selected=@0x46;[ui updateSelection];assert(!ui.choose.enabled&&!ui.save.enabled);
 puts("PASS: geometry, mapping search, drafts, macro decoding and name encoding, sequence bounds and balanced keys, packet offsets, malformed-table blocking, collateral verification, and quoting.");
 return 0;
}}
