#import <AppKit/AppKit.h>
extern void BD85StartEditor(void);
extern BOOL BD85CanClose(void);
@interface BD85AppDelegate:NSObject<NSApplicationDelegate>
@end
@implementation BD85AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note{(void)note;BD85StartEditor();}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{(void)sender;return YES;}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender{(void)sender;if(!BD85CanClose()){NSBeep();return NSTerminateCancel;}return NSTerminateNow;}
@end
int main(int argc,const char **argv){(void)argc;(void)argv;@autoreleasepool{
 NSApplication *application=NSApplication.sharedApplication;[application setActivationPolicy:NSApplicationActivationPolicyRegular];
 BD85AppDelegate *delegate=[BD85AppDelegate new];application.delegate=delegate;
 NSMenu *menu=[[NSMenu alloc]initWithTitle:@""];
 NSMenuItem *appItem=[[NSMenuItem alloc]initWithTitle:@"85HA Keyboard" action:nil keyEquivalent:@""];
 NSMenu *appMenu=[[NSMenu alloc]initWithTitle:@"85HA Keyboard"];
 [appMenu addItemWithTitle:@"About 85HA Keyboard" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
 [appMenu addItem:NSMenuItem.separatorItem];
 [appMenu addItemWithTitle:@"Quit 85HA Keyboard" action:@selector(terminate:) keyEquivalent:@"q"];
 appItem.submenu=appMenu;[menu addItem:appItem];
 NSMenuItem *editItem=[[NSMenuItem alloc]initWithTitle:@"Edit" action:nil keyEquivalent:@""];
 NSMenu *edit=[[NSMenu alloc]initWithTitle:@"Edit"];
 [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
 [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
 [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
 [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
 editItem.submenu=edit;[menu addItem:editItem];application.mainMenu=menu;
 [application run];return 0;
}}
