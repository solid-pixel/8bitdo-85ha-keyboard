- (NSData *)macroData{
 uint8_t header[4]={1,(uint8_t)self.macroRepeats.integerValue,(uint8_t)(self.macroRepeats.integerValue>>8),(uint8_t)self.macroEvents.count};
 NSMutableData *data=[NSMutableData dataWithBytes:header length:4];
 for(NSDictionary *step in self.macroEvents){unsigned value=[step[@"value"] unsignedIntValue];uint8_t event[3]={[step[@"action"] unsignedCharValue],value&255,value>>8};[data appendBytes:event length:3];}return data;
}
- (void)openMacro:(id)sender{
 (void)sender;if(!self.macroButton.enabled)return;self.macroKey=self.selected;
 if(!self.macroWindow){
  BOOL readOnly=!macro_writes_enabled();
  self.macroWindow=[[NSPanel alloc]initWithContentRect:NSMakeRect(0,0,780,readOnly?490:680) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];self.macroWindow.title=readOnly?@"View macro":@"Edit macro";
  self.macroName=[NSTextField new];self.macroName.placeholderString=@"Macro name";self.macroName.delegate=self;
  self.macroRepeats=[NSTextField new];self.macroRepeats.stringValue=@"1";self.macroRepeats.delegate=self;
  if(readOnly)for(NSTextField *field in @[self.macroName,self.macroRepeats]){field.editable=NO;field.selectable=YES;field.bezeled=NO;field.drawsBackground=NO;}
  NSStackView *nameRow=Stack(@[Label(@"Name",12,YES),self.macroName,Label(@"Repeat",12,YES),self.macroRepeats,Label(@"times",12,NO)],NSUserInterfaceLayoutOrientationHorizontal,10);
  self.macroTable=[[NSTableView alloc]initWithFrame:NSZeroRect];self.macroTable.delegate=self;self.macroTable.dataSource=self;self.macroTable.rowHeight=30;self.macroTable.target=self;self.macroTable.action=@selector(macroStepSelected:);self.macroTable.allowsEmptySelection=YES;self.macroTable.accessibilityLabel=@"Macro sequence";
  for(NSArray *spec in @[@[@"step",@"Step",@55],@[@"action",@"Action",@120],@[@"value",@"Key or pause",@540]]){NSTableColumn *c=[[NSTableColumn alloc]initWithIdentifier:spec[0]];c.title=spec[1];c.width=[spec[2] doubleValue];c.editable=NO;[self.macroTable addTableColumn:c];}
  NSScrollView *scroll=[NSScrollView new];scroll.documentView=self.macroTable;scroll.hasVerticalScroller=YES;scroll.borderType=NSBezelBorder;
  self.macroAction=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];[self.macroAction addItemsWithTitles:@[@"Press",@"Release",@"Pause"]];self.macroAction.target=self;self.macroAction.action=@selector(macroActionChanged:);
  self.macroKeyButton=[NSButton buttonWithTitle:@"F13" target:self action:@selector(openPicker:)];self.macroKeyButton.alignment=NSTextAlignmentLeft;
  self.macroDelay=[NSTextField new];self.macroDelay.stringValue=@"100";self.macroDelay.placeholderString=@"Pause in ms";self.macroDelay.toolTip=@"Pause in milliseconds (0–10000)";
  self.macroAdd=[NSButton buttonWithTitle:@"Add step" target:self action:@selector(macroAddStep:)];self.macroUpdate=[NSButton buttonWithTitle:@"Update step" target:self action:@selector(macroUpdateStep:)];
  NSStackView *stepRow=Stack(@[self.macroAction,self.macroKeyButton,self.macroDelay,self.macroAdd,self.macroUpdate],NSUserInterfaceLayoutOrientationHorizontal,10);
  NSMutableArray *mods=[NSMutableArray new];for(NSString *name in @[@"Control",@"Option",@"Shift",@"Command"])[mods addObject:[NSButton checkboxWithTitle:name target:nil action:nil]];self.macroModifiers=mods;
  self.macroShortcut=[NSButton buttonWithTitle:@"Add shortcut" target:self action:@selector(macroAddShortcut:)];
  NSStackView *shortcutRow=Stack(@[Label(@"With",12,NO),mods[0],mods[1],mods[2],mods[3],self.macroShortcut],NSUserInterfaceLayoutOrientationHorizontal,10);
  self.macroDelete=[NSButton buttonWithTitle:@"Remove step" target:self action:@selector(macroDeleteStep:)];self.macroUp=[NSButton buttonWithTitle:@"Move up" target:self action:@selector(macroMoveStep:)];self.macroUp.tag=-1;self.macroDown=[NSButton buttonWithTitle:@"Move down" target:self action:@selector(macroMoveStep:)];self.macroDown.tag=1;
  NSStackView *order=Stack(@[self.macroDelete,self.macroUp,self.macroDown],NSUserInterfaceLayoutOrientationHorizontal,10);
  self.macroNotice=Label(@"",12,NO);self.macroNotice.maximumNumberOfLines=3;
  self.macroSave=[NSButton buttonWithTitle:@"Save macro to keyboard" target:self action:@selector(macroSaveClicked:)];self.macroSave.bezelColor=NSColor.controlAccentColor;
  NSButton *cancel=[NSButton buttonWithTitle:readOnly?@"Close":@"Cancel" target:self action:@selector(closeMacro:)];cancel.keyEquivalent=@"\033";
  self.macroRemove=[NSButton buttonWithTitle:@"Remove macro & restore key" target:self action:@selector(macroRemoveClicked:)];
  NSView *space=[NSView new];NSStackView *actions=Stack(readOnly?@[space,cancel]:@[self.macroRemove,space,cancel,self.macroSave],NSUserInterfaceLayoutOrientationHorizontal,12);
  NSArray *rows=readOnly?@[Label(@"Saved macro",22,YES),nameRow,scroll,self.macroNotice,actions]:@[Label(@"Macro sequence",22,YES),Label(@"Add a shortcut, or build individual presses, releases, and pauses. Changes are saved onboard.",12,NO),nameRow,scroll,order,stepRow,shortcutRow,self.macroNotice,actions];
  NSStackView *root=Stack(rows,NSUserInterfaceLayoutOrientationVertical,16);root.translatesAutoresizingMaskIntoConstraints=NO;[self.macroWindow.contentView addSubview:root];NSView *content=self.macroWindow.contentView;
  NSMutableArray *constraints=[NSMutableArray arrayWithArray:@[[root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:22],[root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-22],[root.topAnchor constraintEqualToAnchor:content.topAnchor constant:22],[root.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-20],[self.macroName.widthAnchor constraintEqualToConstant:390],[self.macroRepeats.widthAnchor constraintEqualToConstant:50],[scroll.heightAnchor constraintEqualToConstant:260]]];
  if(!readOnly)[constraints addObjectsFromArray:@[[self.macroKeyButton.widthAnchor constraintEqualToConstant:220],[self.macroDelay.widthAnchor constraintEqualToConstant:110]]];
  for(NSView *v in (readOnly?@[nameRow,scroll,self.macroNotice,actions]:@[nameRow,scroll,order,stepRow,shortcutRow,self.macroNotice,actions]))[constraints addObject:[v.widthAnchor constraintEqualToAnchor:root.widthAnchor]];[NSLayoutConstraint activateConstraints:constraints];
 }
 NSDictionary *existing=self.state[@"macroDefinitions"][self.macroKey.stringValue];self.macroName.stringValue=existing[@"name"]?:@"New macro";self.macroRepeats.stringValue=@"1";self.macroEvents=[NSMutableArray new];
 if(existing[@"data"]){NSData *data=[[NSData alloc]initWithBase64EncodedString:existing[@"data"] options:0];const uint8_t *p=data.bytes;self.macroRepeats.integerValue=p[1]+256u*p[2];for(unsigned i=4;i<data.length;i+=3)[self.macroEvents addObject:@{@"action":@(p[i]),@"value":@(p[i+1]+256u*p[i+2])}];}
 self.macroEventKey=Payload(7,0,0x68);self.macroKeyButton.title=@"F13";[self.macroAction selectItemAtIndex:0];for(NSButton *button in self.macroModifiers)button.state=NSControlStateValueOff;
 [self.macroTable reloadData];[self.macroTable deselectAll:nil];[self macroActionChanged:nil];[self updateMacroButtons];[self.window beginSheet:self.macroWindow completionHandler:nil];
}
- (void)controlTextDidChange:(NSNotification *)note{if(note.object==self.macroName||note.object==self.macroRepeats)[self updateMacroButtons];}
- (void)tableViewSelectionDidChange:(NSNotification *)note{if(note.object==self.macroTable)[self macroStepSelected:nil];}
- (void)macroActionChanged:(id)sender{(void)sender;BOOL pause=self.macroAction.indexOfSelectedItem==2;self.macroDelay.hidden=!pause;self.macroKeyButton.hidden=pause;[self updateMacroButtons];}
- (NSDictionary *)macroInputStep{
 if(self.macroAction.indexOfSelectedItem==2){NSScanner *scan=[NSScanner scannerWithString:self.macroDelay.stringValue];int n=0;if(![scan scanInt:&n]||!scan.isAtEnd||n<0||n>10000){self.macroNotice.stringValue=@"Use a pause between 0 and 10000 milliseconds.";return nil;}return @{@"action":@15,@"value":@(n)};}
 const uint8_t *p=self.macroEventKey.bytes;return @{@"action":@(self.macroAction.indexOfSelectedItem==0?(p[1]?0x83:0x81):(p[1]?3:1)),@"value":@(p[1]?:p[2])};
}
- (void)macroStepSelected:(id)sender{
 (void)sender;NSInteger row=self.macroTable.selectedRow;if(row<0||row>=(NSInteger)self.macroEvents.count){[self updateMacroButtons];return;}NSDictionary *step=self.macroEvents[row];unsigned action=[step[@"action"] unsignedIntValue],value=[step[@"value"] unsignedIntValue];
 [self.macroAction selectItemAtIndex:action==15?2:(action&0x80?0:1)];if(action==15)self.macroDelay.integerValue=value;else{self.macroEventKey=action==3||action==0x83?Payload(7,value,0):Payload(7,0,value);self.macroKeyButton.title=MappingName(self.macroEventKey,0);}[self macroActionChanged:nil];
}
- (void)macroAddStep:(id)sender{(void)sender;NSDictionary *step=[self macroInputStep];if(!step||self.macroEvents.count>=MACRO_MAX_EVENTS)return;NSInteger row=self.macroTable.selectedRow;NSUInteger index=row>=0?(NSUInteger)row+1:self.macroEvents.count;[self.macroEvents insertObject:step atIndex:index];[self.macroTable reloadData];[self.macroTable selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];[self updateMacroButtons];}
- (void)macroUpdateStep:(id)sender{(void)sender;NSInteger row=self.macroTable.selectedRow;NSDictionary *step=[self macroInputStep];if(!step||row<0||row>=(NSInteger)self.macroEvents.count)return;self.macroEvents[row]=step;[self.macroTable reloadData];[self updateMacroButtons];}
- (void)macroDeleteStep:(id)sender{(void)sender;NSInteger row=self.macroTable.selectedRow;if(row<0||row>=(NSInteger)self.macroEvents.count)return;[self.macroEvents removeObjectAtIndex:row];[self.macroTable reloadData];[self.macroTable deselectAll:nil];[self updateMacroButtons];}
- (void)macroMoveStep:(NSButton *)sender{NSInteger row=self.macroTable.selectedRow,next=row+sender.tag;if(row<0||next<0||next>=(NSInteger)self.macroEvents.count)return;[self.macroEvents exchangeObjectAtIndex:row withObjectAtIndex:next];[self.macroTable reloadData];[self.macroTable selectRowIndexes:[NSIndexSet indexSetWithIndex:next] byExtendingSelection:NO];[self updateMacroButtons];}
- (void)macroAddShortcut:(id)sender{
 (void)sender;const uint8_t *p=self.macroEventKey.bytes;NSMutableArray *steps=[NSMutableArray new],*modifiers=[NSMutableArray new];unsigned codes[]={0xe0,0xe2,0xe1,0xe3};
 for(unsigned i=0;i<4;i++)if(self.macroModifiers[i].state==NSControlStateValueOn&&p[1]!=codes[i])[modifiers addObject:@(codes[i])];
 for(NSNumber *key in modifiers)[steps addObject:@{@"action":@0x83,@"value":key}];
 [steps addObject:@{@"action":@(p[1]?0x83:0x81),@"value":@(p[1]?:p[2])}];[steps addObject:@{@"action":@15,@"value":@30}];[steps addObject:@{@"action":@(p[1]?3:1),@"value":@(p[1]?:p[2])}];
 for(NSNumber *key in modifiers.reverseObjectEnumerator)[steps addObject:@{@"action":@3,@"value":key}];
 if(self.macroEvents.count+steps.count>MACRO_MAX_EVENTS){self.macroNotice.stringValue=@"A macro can contain up to 128 steps.";return;}
 [self.macroEvents addObjectsFromArray:steps];[self.macroTable reloadData];[self.macroTable deselectAll:nil];[self updateMacroButtons];
}
- (void)updateMacroButtons{
 NSData *data=[self macroData],*name=MacroEncodedName(self.macroName.stringValue);NSScanner *scan=[NSScanner scannerWithString:self.macroRepeats.stringValue];int repeats=0;BOOL repeatOK=[scan scanInt:&repeats]&&scan.isAtEnd&&repeats>=1&&repeats<=100;
 BOOL valid=repeatOK&&macro_name_valid(name.bytes,(unsigned)name.length)&&macro_valid(data.bytes,(unsigned)data.length);
 NSDictionary *saved=self.state[@"macroDefinitions"][self.macroKey.stringValue];BOOL unchanged=[saved[@"name"] isEqual:self.macroName.stringValue]&&[saved[@"data"] isEqual:[data base64EncodedStringWithOptions:0]];
 BOOL writable=macro_writes_enabled()&&MacrosWritable(self.state);
 self.macroSave.enabled=valid&&writable&&!unchanged&&!self.busy&&!self.demo&&self.state!=nil;
 self.macroRemove.enabled=writable&&!self.busy&&self.state&&[self isMacro:self.macroKey];
 BOOL editing=!self.busy&&macro_writes_enabled();
 NSInteger row=self.macroTable.selectedRow;self.macroUpdate.enabled=self.macroDelete.enabled=editing&&row>=0&&row<(NSInteger)self.macroEvents.count;self.macroUp.enabled=self.macroUpdate.enabled&&row>0;self.macroDown.enabled=self.macroUpdate.enabled&&row+1<(NSInteger)self.macroEvents.count;
 self.macroTable.enabled=!self.busy;
 self.macroName.enabled=self.macroRepeats.enabled=!self.busy;
 self.macroAction.enabled=self.macroKeyButton.enabled=self.macroDelay.enabled=editing;
 self.macroAdd.enabled=editing&&self.macroEvents.count<MACRO_MAX_EVENTS;self.macroShortcut.enabled=editing&&self.macroAction.indexOfSelectedItem!=2;for(NSButton *b in self.macroModifiers)b.enabled=editing;
 if(self.busy)return;
 if(!self.state)self.macroNotice.stringValue=@"Close this editor and reload to check the keyboard before saving again.";
 else if(!macro_writes_enabled())self.macroNotice.stringValue=@"Read-only. Macro editing, saving, and removal are unavailable.";
 else if(!writable)self.macroNotice.stringValue=@"Macro saves are blocked: the keyboard contains unreadable macro entries. Your existing mappings are preserved.";
 else if(!macro_name_valid(name.bytes,(unsigned)name.length))self.macroNotice.stringValue=@"Give this macro a name of up to 14 UTF-16 characters.";
 else if(!repeatOK)self.macroNotice.stringValue=@"Repeat must be a whole number from 1 to 100.";
 else if(!self.macroEvents.count)self.macroNotice.stringValue=@"Choose a key above and use Add shortcut to get started.";
 else if(!valid)self.macroNotice.stringValue=@"Each press needs a matching release. Keep pauses within 10 seconds and total playback within 60 seconds.";
 else self.macroNotice.stringValue=unchanged?@"This macro is already saved on the keyboard.":[NSString stringWithFormat:@"%lu steps · Ready to save. Your current mapping and macro will be backed up.",(unsigned long)self.macroEvents.count];
}
- (void)closeMacro:(id)sender{(void)sender;if(self.busy)return;[self.window endSheet:self.macroWindow];[self.macroWindow orderOut:nil];}
- (void)macroSaveClicked:(id)sender{(void)sender;if(!self.macroSave.enabled)return;NSDictionary *definition=@{@"name":self.macroName.stringValue,@"data":[[self macroData] base64EncodedStringWithOptions:0]};[self saveMacroKey:self.macroKey definition:definition mapping:Payload(7,0,0) undo:NO];}
- (void)macroRemoveClicked:(id)sender{(void)sender;if(!self.macroRemove.enabled)return;[self saveMacroKey:self.macroKey definition:nil mapping:Default(self.macroKey.intValue) undo:NO];}
- (void)saveMacroKey:(NSNumber *)key definition:(NSDictionary *)definition mapping:(NSData *)target undo:(BOOL)isUndo{
 if(!macro_writes_enabled()){self.status.stringValue=@"Macro changes are paused while saving is being repaired.";return;}
 if(self.busy||self.demo||!self.state||target.length!=24||!physical_key(key.unsignedIntValue)||!mapping_valid(target.bytes))return;
 if(!MacrosWritable(self.state)){self.status.stringValue=@"Macro saves are blocked until all existing macros can be backed up.";return;}
 NSData *newData=definition?[[NSData alloc]initWithBase64EncodedString:definition[@"data"] options:0]:nil;
 NSData *newName=definition?MacroEncodedName(definition[@"name"]):nil;
 if(definition&&(!macro_valid(newData.bytes,(unsigned)newData.length)||!macro_name_valid(newName.bytes,(unsigned)newName.length)))return;
 NSDictionary *displayed=self.state;self.busy=YES;self.status.stringValue=@"Backing up the profile and macro before saving…";[self updateButtons];if(self.macroWindow)[self updateMacroButtons];
 dispatch_async(self.ioQueue,^{@autoreleasepool{
  NSDictionary *after=nil,*undo=nil;NSString *error=nil;
  @try{
   NSDictionary *before=ReadSnapshot();if(![before isEqual:displayed])Throw(@"The keyboard changed since it was loaded. Reload before saving.");
   if(!MacrosWritable(before))Throw(@"Macro saves are blocked until all existing macros can be backed up.");
   NSData *old=Raw(before,key);if(!(zero_mapping(old.bytes)||mapping_valid(old.bytes)))Throw(@"This mapping cannot be safely restored by this editor.");
   NSDictionary *oldMacro=before[@"macroDefinitions"][key.stringValue];
   if([before[@"macroKeys"] containsObject:key]&&![oldMacro[@"editable"] boolValue])Throw(@"The current macro could not be backed up in an editable format.");
   if(!definition&&!oldMacro)Throw(@"There is no macro to remove. Reload before continuing.");
   NSArray *packets=before[@"macroPackets"];if(packets.count!=1)Throw(@"This macro list needs further support. No macro was written.");
   NSError *ioError=nil;if(![NSFileManager.defaultManager createDirectoryAtPath:self.backupDir withIntermediateDirectories:YES attributes:nil error:&ioError])Throw(ioError.localizedDescription);
   NSString *identifier=NSUUID.UUID.UUIDString;
   NSDictionary *record=@{@"snapshot":before,@"key":key,@"requestedMacro":definition?:NSNull.null,@"requestedMapping":Hex(target),@"createdAt":[[NSISO8601DateFormatter new] stringFromDate:NSDate.date]};
   NSData *backup=[NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&ioError];
   if(!backup||![backup writeToFile:[self.backupDir stringByAppendingPathComponent:[identifier stringByAppendingString:@"-before.json"]] options:NSDataWritingAtomic error:&ioError])Throw(ioError.localizedDescription?:@"Could not save the backup.");
   NSData *profile=[before[@"profile"] dataUsingEncoding:NSUTF16BigEndianStringEncoding];if(profile.length>28)Throw(@"Unsupported profile name.");
   uint8_t name[33]={0x54,0x80,(uint8_t)profile.length,0};memcpy(name+4,profile.bytes,profile.length);
   NSString *helper=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Helpers/85HAMacroWriter"];
   NSArray *arguments=@[helper,definition?@"--set":@"--remove",[NSString stringWithFormat:@"%02x",key.intValue],Hex(old),Hex(target),Hex([NSData dataWithBytes:name length:33]),Hex([[NSData alloc]initWithBase64EncodedString:packets[0] options:0]),oldMacro?Hex([[NSData alloc]initWithBase64EncodedString:oldMacro[@"nameReport"] options:0]):@"-",oldMacro?Hex([[NSData alloc]initWithBase64EncodedString:oldMacro[@"data"] options:0]):@"-",definition?Hex(newName):@"-",definition?Hex(newData):@"-"];
   NSMutableArray *quoted=[NSMutableArray new];for(NSString *argument in arguments)[quoted addObject:ShellQuote(argument)];
   NSString *script=[NSString stringWithFormat:@"do shell script %@ with administrator privileges",AppleQuote([[quoted componentsJoinedByString:@" "] stringByAppendingString:@" 2>&1"])];
   dispatch_async(dispatch_get_main_queue(),^{self.status.stringValue=@"Authorize the save in the macOS prompt. The keyboard may pause briefly.";self.macroNotice.stringValue=self.status.stringValue;});
   NSTask *task=[NSTask new];task.executableURL=[NSURL fileURLWithPath:@"/usr/bin/osascript"];task.arguments=@[@"-e",script];NSPipe *pipe=[NSPipe pipe];task.standardOutput=pipe;task.standardError=pipe;
   if(![task launchAndReturnError:&ioError])Throw(ioError.localizedDescription);
   NSData *log=[pipe.fileHandleForReading readDataToEndOfFile];[task waitUntilExit];
   [log writeToFile:[self.backupDir stringByAppendingPathComponent:[identifier stringByAppendingString:@"-save.log"]] atomically:YES];
   NSString *output=[[NSString alloc]initWithData:log encoding:NSUTF8StringEncoding]?:@"";
   if(task.terminationStatus||![output containsString:@"85HA_MACRO_VERIFIED"]){if([output containsString:@"User canceled"])Throw(@"Save canceled in the macOS authorization prompt.");Throw(@"The macro save was not confirmed. Close the editor and reload; the backup and USB log are saved.");}
   after=ReadAfterSave();if(!VerifyMacro(before,after,key,definition,target))Throw(@"Full-profile verification failed. Close the editor and reload before another change.");
   NSData *verified=[NSJSONSerialization dataWithJSONObject:after options:NSJSONWritingPrettyPrinted|NSJSONWritingSortedKeys error:&ioError];
   if(![verified writeToFile:[self.backupDir stringByAppendingPathComponent:[identifier stringByAppendingString:@"-after.json"]] options:NSDataWritingAtomic error:&ioError])Throw(@"The macro verified, but its verification record could not be saved.");
   if(!isUndo)undo=@{@"kind":@"macro",@"key":key,@"beforeMacro":oldMacro?:NSNull.null,@"beforeMapping":zero_mapping(old.bytes)?Default(key.intValue):old,@"afterState":after};
  }@catch(NSException *e){error=e.reason;after=nil;}
  dispatch_async(dispatch_get_main_queue(),^{
   self.busy=NO;self.state=after;self.undoRecord=undo;
   if(after){[self.drafts removeObjectForKey:key];self.selected=key;self.status.stringValue=isUndo?@"Previous mapping and macro restored and verified on the keyboard.":@"Saved and verified on the keyboard.";if(self.macroWindow.sheetParent)[self closeMacro:nil];[self filterChanged:nil];[self updateSelection];}
   else{self.status.stringValue=error?:@"Save failed. Reload before continuing.";self.currentLabel.stringValue=@"Reload to check the keyboard’s current state.";[self updateButtons];if(self.macroWindow){[self updateMacroButtons];self.macroNotice.stringValue=self.status.stringValue;}}
  });
 }});
}
