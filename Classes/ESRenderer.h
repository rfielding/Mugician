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
//- (void)setCenterPoint:(CGPoint)point;
@end

