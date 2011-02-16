//
//  ESRenderer.h
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>

@protocol ESRenderer <NSObject>

- (void)render;
- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer;
- (void)touchesBegan:(NSSet*)touches atView:(UIView*)v;
- (void)touchesMoved:(NSSet*)touches atView:(UIView*)v;
- (void)touchesEnded:(NSSet*)touches atView:(UIView*)v;
- (void)touchesCancelled:(NSSet*)touches atView:(UIView*)v;
@end

