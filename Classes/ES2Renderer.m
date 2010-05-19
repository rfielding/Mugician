//
//  ES2Renderer.m
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

#import "ES2Renderer.h"

#define NOTECOUNT 12

// The pixel dimensions of the CAEAGLLayer
static GLint backingWidth;
static GLint backingHeight;
static long tickCounter=0;

static const double kNotesPerOctave = 12.0;
static const double kMiddleAFrequency = 440.0;
static const double kMiddleANote = 48; //100; //24;//49;

#define SPLITCOUNT 12
static NSSet* lastTouches;
static UIView* lastTouchesView;
static AudioOutput* lastAudio;
static float gainp=0.5;
static float reverbp=0.5;
static float NoteStates[NOTECOUNT];
static float MicroStates[NOTECOUNT];

double GetFrequencyForNote(double note) {
	return kMiddleAFrequency * pow(2, (note - kMiddleANote) / kNotesPerOctave);
}

// uniform index
enum {
    UNIFORM_TRANSLATE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// attribute index
enum {
    ATTRIB_VERTEX,
    ATTRIB_COLOR,
    NUM_ATTRIBUTES
};


void TouchesInit()
{
	lastTouches = nil;
	lastTouchesView = nil;
}



void ButtonStatesInit()
{
	for(int i=0;i<NOTECOUNT;i++)
	{
		NoteStates[i]=0;
		MicroStates[i]=0;
	}
}


void ButtonsTrack()
{
	NSArray* touches = [lastTouches allObjects];
	if(touches != NULL && [touches count] > 0)
	{
		for(int t=0; t < [touches count] && t < FINGERS; t++)
		{
			UITouch* touch = [touches objectAtIndex:t];
			if(touch != NULL)
			{
				CGPoint point = [touch locationInView:lastTouchesView];
				//Find the square we are in, and enable it
				float ifl = (1.0*SPLITCOUNT * point.x)/backingWidth;
				int i = (int)ifl;
				float di = ifl-i;
				int j = SPLITCOUNT-(SPLITCOUNT * point.y)/backingHeight;
				int n = (5*j+i)%12;
				if((i>4||j>0) && 0<=n && n<NOTECOUNT)
				{
					if(di < 0.25)
					{
						//quarterflat
						MicroStates[n] = (1+7*MicroStates[n])/8;
					}
					else
					if(0.75 < di) 
					{
						//quartersharp
						MicroStates[(n+1)%NOTECOUNT] = (1+7*MicroStates[(n+1)%NOTECOUNT])/8;
					}
					else
					{
						//on note
						NoteStates[n] = (1+7*NoteStates[n])/8;
					}
				}
			}
		}
	}	
	//Fade all notes
	for(int n=0;n<NOTECOUNT;n++)
	{
		NoteStates[n] *= 0.995;
		MicroStates[n] *= 0.995;
	}
}



#define SQUAREVERTICESMAX 800
static int Vertices2Count;
//static GLfloat Vertices2[2*SQUAREVERTICESMAX];
static GLfloat Vertices2Translated[2*SQUAREVERTICESMAX];
static GLubyte Vertices2Colors[4*SQUAREVERTICESMAX];

//Recreate immediate mode
void Vertices2Clear()
{
	Vertices2Count = 0;
}

void Vertices2Insert(GLfloat x,GLfloat y,GLubyte r,GLubyte g,GLubyte b,GLubyte a)
{
	if(Vertices2Count < SQUAREVERTICESMAX)
	{
		Vertices2Translated[2*Vertices2Count+0] = x; 
		Vertices2Translated[2*Vertices2Count+1] = y; 
		Vertices2Colors[4*Vertices2Count+0] = r; 
		Vertices2Colors[4*Vertices2Count+1] = g; 
		Vertices2Colors[4*Vertices2Count+2] = b; 
		Vertices2Colors[4*Vertices2Count+3] = a; 
		Vertices2Count++;
	}
}

void Vertices2Render(int triType)
{
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, Vertices2Translated);
	glEnableVertexAttribArray(ATTRIB_VERTEX);
	glVertexAttribPointer(ATTRIB_COLOR, 4, GL_UNSIGNED_BYTE, 1, 0, Vertices2Colors);
	glEnableVertexAttribArray(ATTRIB_COLOR);	
    // Draw
    glDrawArrays(triType, 0, Vertices2Count);	
}

void ButtonRender(int i,int j,float hilite)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i+0)*f-0.5);
	GLfloat r = 2*((i+1)*f-0.5);
	GLfloat t = 2*((j+1)*f-0.5);
	GLfloat b = 2*((j+0)*f-0.5);
	GLfloat xc = (l+r)/2;
	GLfloat yc = (t+b)/2;
	int n = (j*5+(i+9))%12;
	int isWhite = (n==0 || n==2 || n==3 || n==5 || n==7 || n==8 || n==10);
	float w = isWhite?1.0:0.0;
	float k = (isWhite==false)?1.0:0.0;
	
	float wr = w*255-hilite*255*k;
	float wg = w*255-hilite*255;
	float wb = w*255+k*hilite*255;
	
	float br = 0;// - hilite*255;
	float bb = 0;
	float bg = 0;// - hilite*255;
	
	Vertices2Clear();
	
	Vertices2Insert(xc,yc,wr,wg,wb,255);
	Vertices2Insert(l,t,br,bg,bb,255);
	Vertices2Insert(r,t,br,bg,bb,255);
	
	Vertices2Insert(xc,yc,wr,wg,wb,255);
	Vertices2Insert(r,t,br,bg,bb,255);
	Vertices2Insert(r,b,br,bg,bb,255);
	
	Vertices2Insert(xc,yc,wr,wg,wb,255);
	Vertices2Insert(r,b,br,bg,bb,255);
	Vertices2Insert(l,b,br,bg,bb,255);
	
	Vertices2Insert(xc,yc,wr,wg,wb,255);
	Vertices2Insert(l,b,br,bg,bb,255);
	Vertices2Insert(l,t,br,bg,bb,255);
	
	Vertices2Render(GL_TRIANGLES);
}

void MicroRedButtonRender(int i,int j,float hilite)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-0.1)*f-0.5);
	GLfloat r = 2*((i+0.1)*f-0.5);
	GLfloat t = 2*((j+0.5+0.1)*f-0.5);
	GLfloat b = 2*((j+0.5-0.1)*f-0.5);
	GLfloat h = 200*hilite;
	GLfloat cr = 255;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_TRIANGLES);
}

void MicroGreenButtonRender(int i,int j,float hilite)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-0.1+0.5)*f-0.5);
	GLfloat r = 2*((i+0.1+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+0.1)*f-0.5);
	GLfloat b = 2*((j+0.5-0.1)*f-0.5);
	GLfloat h = 200*hilite;
	GLfloat cr = 0;
	GLfloat cg = 255;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_TRIANGLES);
}

void ButtonsRender()
{
	for(int j=0;j<SPLITCOUNT;j++)
	{
		for(int i=0;i<SPLITCOUNT;i++)
		{
			ButtonRender(i,j,NoteStates[(5*j+i)%12]);
			//MicroGreenButtonRender(i,j,NoteStates[(5*j+i)%12]);
		}
	}
}

void MicroButtonsRender()
{
	for(int j=0;j<SPLITCOUNT;j++)
	{
		//Note that we are over by 1
		for(int i=0;i<SPLITCOUNT+1;i++)
		{
			MicroRedButtonRender(i,j,MicroStates[(5*j+i)%12]);
		}
	}
}

void LinesRender()
{
	Vertices2Clear();
	for(int i=0;i<SPLITCOUNT;i++)
	{
		float v = -1 + i*2.0/SPLITCOUNT;
		Vertices2Insert(-1,v,0,255,0,255);
		Vertices2Insert(1,v,0,255,0,255);
		Vertices2Insert(v,-1,0,255,0,255);
		Vertices2Insert(v,1,0,255,0,255);
	}
	Vertices2Render(GL_LINES);
}

void ControlRender()
{
	GLfloat l = -1;
	GLfloat r = -2.0/SPLITCOUNT;
	GLfloat t = -1 + 2.0/SPLITCOUNT;
	GLfloat b = -1;
	GLfloat m = (r+l)/2;
	GLfloat v = (l+((reverbp)/2)*(r-l));
	GLfloat g = (l+(0.5+(gainp)/2)*(r-l));
	GLfloat d = 0.01;
	//Reverb blue slider
	Vertices2Clear();
	Vertices2Insert(l,t+d, 25,20, 250, 255);
	Vertices2Insert(v,t+d, 25,20, 250, 255);
	Vertices2Insert(l,b, 25,20, 50, 255);	
	Vertices2Insert(v,b, 25,20, 50, 255);	
	Vertices2Render(GL_TRIANGLE_STRIP);	
	//Black area of reverb
	Vertices2Clear();
	Vertices2Insert(v,t, 25,25, 100, 255);
	Vertices2Insert(m,t, 25,25, 100, 255);
	Vertices2Insert(v,b, 25,25, 0, 255);	
	Vertices2Insert(m,b, 25,25, 0, 255);	
	Vertices2Render(GL_TRIANGLE_STRIP);
	
	//Gain red slider
	Vertices2Clear();
	Vertices2Insert(m,t+d, 250,20, 25, 255);
	Vertices2Insert(g,t+d, 250,20, 20, 255);
	Vertices2Insert(m,b, 50,20, 20, 255);	
	Vertices2Insert(g,b, 50,20, 25, 255);	
	Vertices2Render(GL_TRIANGLE_STRIP);
	//gain black area
	Vertices2Clear();
	Vertices2Insert(g,t, 100,25, 25, 255);
	Vertices2Insert(r,t, 100,25, 20, 255);
	Vertices2Insert(g,b, 0,25, 20, 255);	
	Vertices2Insert(r,b, 0,25, 25, 255);	
	Vertices2Render(GL_TRIANGLE_STRIP);
	
}

void FingerControl(float i,float j)
{
	if(i<2.5)
	{
		reverbp = i*40/100;
	}
	else
	{
		gainp = (i-2.5)*40/100;
	}
	[lastAudio setGain:gainp];
	[lastAudio setReverb:reverbp];
}

void FingerRenderRaw2(float i,float j,GLfloat x,GLfloat y,CGFloat px,CGFloat py,int finger)
{
	
	GLfloat d = 1.0/SPLITCOUNT;
	GLfloat l = d - x;
	GLfloat t = d + y;
	GLfloat r = -d - x;
	GLfloat b = -d + y;
	GLfloat flat = 127 + 127 * cos((i)*2*M_PI);//255*(i-((int)(i+0.5)));
	GLfloat sharp = 127 + 127 * cos((i+0.5)*2*M_PI);//*(((int)(i))-i);
	GLfloat harm = 127 + 127 * cos((j)*2*M_PI);//*(((int)(i))-i);
	Vertices2Insert(l,t, flat, sharp, harm, 150);
	Vertices2Insert(r,t, flat,sharp, harm, 150);
	Vertices2Insert(l,b, flat,sharp, harm, 150);
	Vertices2Insert(r,b, flat,sharp, harm, 150);
	
	float n = ((int)j)*5 + i  -24 - 0.8;
	float f = GetFrequencyForNote(n);
	[lastAudio setNote:f forFinger: finger];	
	[lastAudio setVol:1.0 forFinger: finger];	
	[lastAudio setHarmonics:(j-((int)j)) forFinger: finger];	
}

void FingerRenderRaw(CGPoint p,int finger)
{
	GLfloat x = (0.5-p.x/backingWidth)*2;
	GLfloat y = (0.5-p.y/backingHeight)*2;
	CGFloat px=p.x;
	CGFloat py=p.y;
	float i = (SPLITCOUNT * px)/backingWidth;
	float j = SPLITCOUNT-(SPLITCOUNT * py)/backingHeight;
	if(j<1 && i<5)
	{
		FingerControl(i,j);
	}
	else 
	{
		FingerRenderRaw2(i,j,x,y,px,py,finger);
	}

}

void FingersRender()
{
	Vertices2Clear();
	NSArray* touches = [lastTouches allObjects];
	if(touches != NULL && [touches count] > 0)
	{
		for(int i=0; i < [touches count] && i < FINGERS; i++)
		{
			UITouch* touch = [touches objectAtIndex:i];
			if(touch != NULL)
			{
				CGPoint lastPoint = [touch locationInView:lastTouchesView];
				FingerRenderRaw(lastPoint,i);
			}
		}
	}
	Vertices2Render(GL_TRIANGLE_STRIP);
}

void DisableFingers()
{
	//Turn off all sounds
	for(int b=0;b<FINGERS;b++)
	{
		[lastAudio setVol:0 forFinger: b];
	}
}

@interface ES2Renderer (PrivateMethods)
- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation ES2Renderer

// Create an OpenGL ES 2.0 context
- (id)init
{
    if ((self = [super init]))
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

        if (!context || ![EAGLContext setCurrentContext:context] || ![self loadShaders])
        {
            [self release];
            return nil;
        }

        // Create default framebuffer object. The backing will be allocated for the current layer in -resizeFromLayer
        glGenFramebuffers(1, &defaultFramebuffer);
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);		
    }
	somethingChanged = true;
	TouchesInit();
	ButtonStatesInit();

	sound = [AudioOutput alloc];
	lastAudio = sound;
	[sound init];
	[sound start];
	
    return self;
}

- (void)render
{	
	tickCounter++;
	//[[UIDevice currentDevice] orientation]UIDeviceOrientationLandscapeLeft
	
    // This application only creates a single context which is already set current at this point.
    // This call is redundant, but needed if dealing with multiple contexts.
    [EAGLContext setCurrentContext:context];

    // This application only creates a single default framebuffer which is already bound at this point.
    // This call is redundant, but needed if dealing with multiple framebuffers.
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    glViewport(0, 0, backingWidth,backingHeight);
	
    glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    // Use shader program
    glUseProgram(program);
#if defined(DEBUG)
    if (![self validateProgram:program])
    {
        NSLog(@"Failed to validate program: %d", program);
        return;
    }
#endif
	
	ButtonsRender();
	MicroButtonsRender();	
	ButtonsTrack();
	LinesRender();
	ControlRender();
	DisableFingers();
	FingersRender();
			
	
    // This application only creates a single color renderbuffer which is already bound at this point.
    // This call is redundant, but needed if dealing with multiple renderbuffers.
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER];
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;

    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source)
    {
        NSLog(@"Failed to load vertex shader");
        return FALSE;
    }

    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);

#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif

    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0)
    {
        glDeleteShader(*shader);
        return FALSE;
    }

    return TRUE;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;

    glLinkProgram(prog);

#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif

    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0)
        return FALSE;

    return TRUE;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;

    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }

    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0)
        return FALSE;

    return TRUE;
}

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;

    // Create shader program
    program = glCreateProgram();

    // Create and compile vertex shader
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname])
    {
        NSLog(@"Failed to compile vertex shader");
        return FALSE;
    }

    // Create and compile fragment shader
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname])
    {
        NSLog(@"Failed to compile fragment shader");
        return FALSE;
    }

    // Attach vertex shader to program
    glAttachShader(program, vertShader);

    // Attach fragment shader to program
    glAttachShader(program, fragShader);

    // Bind attribute locations
    // this needs to be done prior to linking
    glBindAttribLocation(program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(program, ATTRIB_COLOR, "color");

    // Link program
    if (![self linkProgram:program])
    {
        NSLog(@"Failed to link program: %d", program);

        if (vertShader)
        {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader)
        {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (program)
        {
            glDeleteProgram(program);
            program = 0;
        }
        
        return FALSE;
    }

    // Get uniform locations
    uniforms[UNIFORM_TRANSLATE] = glGetUniformLocation(program, "translate");

    // Release vertex and fragment shaders
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);

    return TRUE;
}

- (BOOL)resizeFromLayer:(CAEAGLLayer *)layer
{
    // Allocate color buffer backing based on the current layer size
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    return YES;
}

- (void)dealloc
{
    // Tear down GL
    if (defaultFramebuffer)
    {
        glDeleteFramebuffers(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }

    if (colorRenderbuffer)
    {
        glDeleteRenderbuffers(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }

    if (program)
    {
        glDeleteProgram(program);
        program = 0;
    }

    // Tear down context
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];

    [context release];
    context = nil;

    [super dealloc];
}

- (void)touchesBegan:(NSSet*)touches atView:(UIView*)v
{
	lastTouches = touches;
	lastTouchesView = v;
//	somethingChanged = true;
}

- (void)touchesMoved:(NSSet*)touches atView:(UIView*)v
{
	lastTouches = touches;
	lastTouchesView = v;
//	somethingChanged = true;
}

- (void)touchesEnded:(NSSet*)touches atView:(UIView*)v
{
	lastTouches = touches;
	lastTouchesView = v;
//	somethingChanged = true;
}

@end
