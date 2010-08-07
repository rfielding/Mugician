//
//  ES2Renderer.h
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

#import "ESRenderer.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AudioOutput.h"


@interface ES2Renderer : NSObject <ESRenderer>
{
@private
    EAGLContext *context;


    // The OpenGL ES names for the framebuffer and renderbuffer used to render to this view
    GLuint defaultFramebuffer, colorRenderbuffer;

    GLuint program;
	
	AudioOutput* sound;
	bool somethingChanged;
}

- (void)render;
- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer;
- (void)touchesBegan:(NSSet*)touches atView:(UIView*)v;
- (void)touchesMoved:(NSSet*)touches atView:(UIView*)v;
- (void)touchesEnded:(NSSet*)touches atView:(UIView*)v;
- (void)touchesCancelled:(NSSet*)touches atView:(UIView*)v;

@end

