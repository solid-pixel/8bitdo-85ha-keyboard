// Draw the app's original vector keycap artwork and produce the macOS icon sizes.
// clang -fobjc-arc -Wall -Wextra -Werror tools/make-icon.m -framework AppKit -o .build/make-icon
// .build/make-icon .build/AppIcon.iconset
#import <AppKit/AppKit.h>

static NSColor *RGB(unsigned hex) {
 return [NSColor colorWithSRGBRed:((hex >> 16) & 255)/255.0 green:((hex >> 8) & 255)/255.0 blue:(hex & 255)/255.0 alpha:1];
}
static NSBezierPath *Round(NSRect r, CGFloat radius) {
 return [NSBezierPath bezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
}
static void Artwork(void) {
 // One sculpted keycap; the surrounding canvas is transparent.
 NSBezierPath *body=Round(NSMakeRect(128,116,768,772),156);
 [NSGraphicsContext saveGraphicsState];
 NSShadow *shadow=[NSShadow new];shadow.shadowColor=[NSColor colorWithWhite:0 alpha:0.17];shadow.shadowBlurRadius=20;shadow.shadowOffset=NSMakeSize(0,-10);[shadow set];
 [RGB(0xACB3BE) setFill];[body fill];[NSGraphicsContext restoreGraphicsState];
 NSGradient *sides=[[NSGradient alloc]initWithStartingColor:RGB(0xA1A9B5) endingColor:RGB(0xE8EBEE)];[sides drawInBezierPath:body angle:90];
 NSBezierPath *top=Round(NSMakeRect(146,245,732,643),138);
 NSGradient *ivory=[[NSGradient alloc]initWithStartingColor:RGB(0xE5E8EB) endingColor:RGB(0xFFFFFF)];[ivory drawInBezierPath:top angle:90];
 [[NSColor colorWithWhite:1 alpha:0.8] setStroke];top.lineWidth=3;[top stroke];
 // A restrained inset makes the upper surface read as a keycap.
 NSBezierPath *face=Round(NSMakeRect(188,286,648,554),106);
 NSGradient *surface=[[NSGradient alloc]initWithStartingColor:RGB(0xF7F8F9) endingColor:RGB(0xEFF1F3)];[surface drawInBezierPath:face angle:90];
 // A custom pixel glyph keeps the 8-bit lettering crisp at every icon size.
 const char *rows[]={"0111110","1100011","1100011","1100011","0111110","1100011","1100011","1100011","0111110"};
 const CGFloat pixel=34, left=(1024-7*pixel)/2, bottom=563-9*pixel/2;
 [RGB(0x176DE6) setFill];
 for(int row=0;row<9;row++)for(int col=0;col<7;col++)if(rows[row][col]=='1')
  NSRectFill(NSMakeRect(left+col*pixel,bottom+(8-row)*pixel,pixel,pixel));

}
int main(int argc,const char **argv) { @autoreleasepool {
 if(argc!=2)return 2;
 NSString *output=[NSString stringWithUTF8String:argv[1]];
 NSError *error=nil;
 if(![NSFileManager.defaultManager createDirectoryAtPath:output withIntermediateDirectories:YES attributes:nil error:&error]){NSLog(@"%@",error);return 1;}
 for(NSNumber *nominal in @[@16,@32,@128,@256,@512])for(int scale=1;scale<=2;scale++) {
  NSInteger pixels=nominal.integerValue*scale;
  NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:pixels pixelsHigh:pixels bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  [NSGraphicsContext saveGraphicsState];[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
  NSAffineTransform *transform=[NSAffineTransform transform];[transform scaleBy:pixels/1024.0];[transform concat];Artwork();[NSGraphicsContext restoreGraphicsState];
  NSString *filename=[NSString stringWithFormat:@"icon_%ldx%ld%@.png",(long)nominal.integerValue,(long)nominal.integerValue,scale==2?@"@2x":@""];
  NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  if(![png writeToFile:[output stringByAppendingPathComponent:filename] options:NSDataWritingAtomic error:&error]){NSLog(@"%@",error);return 1;}
 }
 return 0;
}}
