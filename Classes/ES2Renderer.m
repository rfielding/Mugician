//
//  ES2Renderer.m
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

//#import <CoreGraphics/CoreGraphics.h>

#import "ES2Renderer.h"

#define NOTECOUNT 12

// The pixel dimensions of the CAEAGLLayer
static GLint backingWidth;
static GLint backingHeight;
static unsigned int tickCounter=0;

static const double kNotesPerOctave = 12.0;
static const double kMiddleAFrequency = 440.0;
static const double kMiddleANote = 48; //100; //24;//49;

#define TOUCHQUEUELEN (FINGERS)

#define SLIDERCOUNT 9
#define SPLITCOUNT 12
#define SNAPCONTROL 7

#define ACTIVECONTROL_PLAYAREA -1
#define ACTIVECONTROL_NOTHING -2

#define NOTEFONTSIZE 0.05
#define NOTEFONTTRANSPARENCY 0.5

static AudioOutput* lastAudio;

static float LastJ[TOUCHQUEUELEN];
static float LastI[TOUCHQUEUELEN];
static float SnapAdjustH[TOUCHQUEUELEN];
static int activeControl[TOUCHQUEUELEN]; //-1 is the main area, above that is a ref to a slider
static int currentControl = ACTIVECONTROL_NOTHING;

static float NoteStates[NOTECOUNT];
static float MicroStates[NOTECOUNT];
static float SliderValues[SLIDERCOUNT];
static float SliderAdjustH[SLIDERCOUNT];

static float bounceX=0;
static float bounceY=0;
static float bounceDX=0.1;
static float bounceDY=0.1;
static float snapPercent=0.5;
//static GLuint textures[1];

static void* touchQueue[TOUCHQUEUELEN];
//static long touchTimeStampPrev[TOUCHQUEUELEN];
static UITouchPhase touchPhase[TOUCHQUEUELEN];
static CGPoint touchPoint[TOUCHQUEUELEN];

//Yeah, this one!
static float touchMe[TOUCHQUEUELEN];
static char pmrData[16];
static NSString* susiNgPanalo = NULL;
static int adjustmentProgress = 8; //we got it when we reach 0
static int frameDrawn = 0;

void makeAdjustments()
{
	if(susiNgPanalo == NULL)
	{
		char* pmr = "qbuiNbkpsSbejvt";	
		for(int i=0; i<15; i++)
		{
			pmrData[i] = pmr[i] - 1;
		}
		susiNgPanalo = [NSString stringWithUTF8String:pmrData];
		[susiNgPanalo retain];
	}
	else 
	{
		[susiNgPanalo release];
		susiNgPanalo = NULL;
	}

}

int BeginIndexByTouch(UITouch* thisTouch,UIView* lastTouchesView,int t) 
{
	//Search for existing touch first
	int index = -1;
	for(int t=0;t<TOUCHQUEUELEN;t++)
	{
		if(touchQueue[t]==NULL)
		{
			index = t;
		}
	}
	
	float val = 1.0;
	if(susiNgPanalo != nil)
	{
		id valFloat = [thisTouch valueForKey:susiNgPanalo];
		if(valFloat != nil)
		{
			float vf = ([valFloat floatValue]-4)/7.0; 
			val = (vf);
		}
	}
	touchMe[index] = val;
	
	touchQueue[index] = thisTouch;
	touchPhase[index] = UITouchPhaseBegan;
	touchPoint[index] = [thisTouch locationInView:lastTouchesView];
	return index;
}

int MoveIndexByTouch(UITouch* thisTouch,UIView* lastTouchesView,int t) 
{
	for(int i=0; i<TOUCHQUEUELEN; i++) 
	{
		if(thisTouch == touchQueue[i]) 
		{
			float val = 1.0;
			if(susiNgPanalo != nil)
			{
				id valFloat = [thisTouch valueForKey:susiNgPanalo];			
				if(valFloat != nil)
				{
					float vf = ([valFloat floatValue]-4)/7; 
					val = (vf);
				}
			}
			touchMe[i] = val;
			touchPhase[i] = UITouchPhaseMoved;
			touchPoint[i] = [thisTouch locationInView:lastTouchesView];
			return i;
		}
	}
	return -1;
}

int FindIndexByTouch(UITouch* thisTouch,int t) 
{
	for(int i=0; i<TOUCHQUEUELEN; i++) 
	{
		//DOC states that this *should* be same object throughout touch life
		if(thisTouch == touchQueue[i]) 
		{
			return i;
		}
	}
	return -1;	
}

int NothingTouched() 
{
	for(int i=0; i<TOUCHQUEUELEN; i++) 
	{
		//DOC states that this *should* be same object throughout touch life
		if(NULL != touchQueue[i]) 
		{
			return false;
		}
	}
	return true;	
}
//Do this to simplify tracking what is down vs up
void DeleteTouchByIndex(int idx,int t)
{
	touchQueue[idx] = NULL;
}

UITouchPhase FindPhaseByIndex(int idx)
{
	return touchPhase[idx];
}

CGPoint FindPointByIndex(int idx)
{
	return touchPoint[idx];
}

//And inverse mapping
void* FindTouchByIndex(int idx)
{
	return touchQueue[idx];
}

float GetFrequencyForNote(float note) 
{
	return kMiddleAFrequency * powf(2, (note - kMiddleANote) / kNotesPerOctave);
}

// uniform index
enum 
{
    UNIFORM_TRANSLATE,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// attribute index
enum 
{
    ATTRIB_VERTEX,
    ATTRIB_COLOR,
    NUM_ATTRIBUTES
};


void TouchesInit()
{
	for(int i=0;i<FINGERS;i++)
	{
		activeControl[i]=-2;
		touchQueue[i] = NULL;
		touchMe[i] = 0;
	}
	for(int i=0;i<SLIDERCOUNT;i++)
	{
		SliderAdjustH[i]=0;
	}
}



void ButtonStatesInit()
{
	for(int i=0;i<NOTECOUNT;i++)
	{
		NoteStates[i]=0;
		MicroStates[i]=0;
	}
}

void TrackFingerChange(int touchIndex,float v,BOOL isBegin)
{
	if(activeControl[touchIndex]==-1)
	{
		CGPoint point = FindPointByIndex(touchIndex);
		float ifl = (1.0*SPLITCOUNT * (point.x+SnapAdjustH[touchIndex]))/backingWidth;
		float jfl = SPLITCOUNT-(1.0*SPLITCOUNT * point.y)/backingHeight;
		
		float n = ((int)jfl)*5 + ifl  -24 - 0.8 - 0.05;
		float f = GetFrequencyForNote(n);
		float h = (jfl-((int)jfl));
		float tm = touchMe[touchIndex];
		float press = (tm<0) ? 0 : tm;
		press = atan(press/3)*3;
		//Set the minimum frequency to automatically adjust oscilliscope
		if(f < minimumFrequency)
		{
			minimumFrequency = f;
		}
		frequencyPeriod *= f;
		[lastAudio setNote:f forFinger: touchIndex];	
		[lastAudio setVol:v*press forFinger: touchIndex];	
		[lastAudio setHarmonics:h forFinger: touchIndex];
		[lastAudio setPan:(ifl/SPLITCOUNT) forFinger: touchIndex];
		//NSLog(@"%f",press);
		
		if(isBegin)
		{
			float gain = SliderValues[2];
			if(gain > 0.01)
			{
				float p = (1+gain)*press*v;
				[lastAudio setAttackVol:p forFinger: touchIndex];	
			}
			else 
			{
				//[lastAudio setAttackVol:0 forFinger: touchIndex];	
			}
		}
		//This finger isn't fresh any more.
		touchPhase[touchIndex] = UITouchPhaseMoved;
	}
}


void RecheckFingers()
{
	minimumFrequency = 10000000.0;
	frequencyPeriod = 1;
	for(unsigned int f=0; f < FINGERS; f++)
	{
		void* touch = FindTouchByIndex(f);
		if(touch != NULL)
		{
			UITouchPhase phase = FindPhaseByIndex(f);
			if(phase==UITouchPhaseMoved || phase==UITouchPhaseBegan)
			{
				TrackFingerChange(f,1.0, phase==UITouchPhaseBegan);
			}
		}
		else 
		{
			[lastAudio setVol:0 forFinger:f];
		}
	}
}


void ButtonsTrack()
{
	BOOL snapHalfTone = (snapPercent>0.25);
	//BOOL snapDownNotes = false;	
	BOOL snapQuarterTone = (0.01 < snapPercent && snapPercent <= 0.25);
	BOOL showMicrotonal = snapQuarterTone || snapHalfTone==false;
	bool snapNotes = snapHalfTone || snapQuarterTone;
	
	for(unsigned int touchIndex=0; touchIndex < FINGERS; touchIndex++)
	{
		if(FindTouchByIndex(touchIndex)!=NULL)
		{
			UITouchPhase phase = FindPhaseByIndex(touchIndex);		
			CGPoint point = FindPointByIndex(touchIndex);
			
			float ifl = (1.0*SPLITCOUNT * point.x)/backingWidth;
			int i = (int)ifl;
			float jfl = SPLITCOUNT-(1.0*SPLITCOUNT * point.y)/backingHeight;
			int j = (int)jfl;
			float di = (ifl-i) - 0.5; 
			
			//Mark a control as active so that it can be used
			if(phase==UITouchPhaseBegan)
			{
				if(j < 1)
				{
					activeControl[touchIndex] = (int)((SLIDERCOUNT* point.x)/backingWidth);
				}
				else 
				{
					activeControl[touchIndex] = ACTIVECONTROL_PLAYAREA;
				}
			}
			if(j<1)
			{
				currentControl = activeControl[touchIndex];
			}
			if(phase==UITouchPhaseEnded || phase==UITouchPhaseCancelled)
			{
				activeControl[touchIndex] = ACTIVECONTROL_NOTHING;
			}
			
			if(activeControl[touchIndex] == ACTIVECONTROL_PLAYAREA) 
			{
				//It's treated like a begin if we move to a different line, even if sliding.
				bool newNote = (phase==UITouchPhaseBegan) || LastJ[touchIndex] != j;
				
				if(snapNotes)
				{
					
					if(newNote)
					{
						if(snapQuarterTone)
						{
							float qdi = di;
							if(di < -0.25)
							{
								qdi = 0;//di+0.25;
							}
							if(di > 0.25)
							{
								qdi = 0;//di-0.25;
							}
							SnapAdjustH[touchIndex] = -qdi * (1.0*backingWidth)/SPLITCOUNT;																						
						}
						else 
						{
							SnapAdjustH[touchIndex] = -di * (1.0*backingWidth)/SPLITCOUNT;																						
						}
					}
					else 
					{
						if(snapQuarterTone)
						{
							/*
							float snapSensitivity = (SliderValues[8]-0.25)/3*4;
							SnapAdjustH[touchIndex] = 
							(1-snapSensitivity) * SnapAdjustH[touchIndex] +
							snapSensitivity * -di * (1.0*backingWidth)/SPLITCOUNT;
							 */
						}
						else
						{
							float snapSensitivity = (SliderValues[8]-0.25)/3*4;
							SnapAdjustH[touchIndex] = 
							(1-snapSensitivity) * SnapAdjustH[touchIndex] +
							snapSensitivity * -di * (1.0*backingWidth)/SPLITCOUNT;
						}
					}
					
				}
				else 
				{
					SnapAdjustH[touchIndex] = 0;
				}
				LastJ[touchIndex] = j;		
				LastI[touchIndex] = ifl;
				
				unsigned int n = (5*j+i)%12;
				if((j>0) && 0<=n && n<NOTECOUNT)
				{
					if(di < -0.25 && showMicrotonal)
					{
						//quarterflat
						MicroStates[n] = (1+7*MicroStates[n])/8;
					}
					else
						if(0.25 < di && showMicrotonal) 
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
	for(unsigned int n=0;n<NOTECOUNT;n++)
	{
		NoteStates[n] *= 0.99;
		MicroStates[n] *= 0.99;
	}
	frameDrawn=0;
	RecheckFingers();
}



#define SQUAREVERTICESMAX 1200
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
	int n = (j*5+(i+9))%12;
	int isWhite = (n==0 || n==2 || n==3 || n==5 || n==7 || n==8 || n==10);
	
	float wr;// = w*255-hilite*255*k;
	float wg;// = w*255-hilite*255;
	float wb;// = w*255+k*hilite*255;
	
	if(isWhite)
	{
		wr = 255;
		wg = 255;
		wb = 255-hilite*255;
	}
	else
	{
		wr = 0;
		wg = 0;
		wb = hilite*255;
	}
		
	Vertices2Clear();

	Vertices2Insert(l,t,wr,wg,wb,255);
	Vertices2Insert(r,t,wr,wg,wb,255);
	Vertices2Insert(l,b,wr*0.5,wg*0.5,wb*0.5,255);
	Vertices2Insert(r,b,wr*0.25,wg*0.25,wb*0.25,255);
	
	Vertices2Render(GL_TRIANGLE_STRIP);
}

void MicroRedButtonRender(int i,int j,float hilite)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-0.1)*f-0.5);
	GLfloat r = 2*((i+0.1)*f-0.5);
	GLfloat t = 2*((j+0.5+0.1)*f-0.5);
	GLfloat b = 2*((j+0.5-0.1)*f-0.5);
	GLfloat h = 255*hilite;
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

void NoteNameRenderA(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONTSIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONTSIZE)*f-0.5);
	GLfloat h = 255*NOTEFONTTRANSPARENCY;
	GLfloat cr = 0;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,25);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderB(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONTSIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONTSIZE)*f-0.5);
	GLfloat h = 255*NOTEFONTTRANSPARENCY;
	GLfloat cr = 0;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,25);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);	
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderC(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONTSIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONTSIZE)*f-0.5);
	GLfloat h = 255*NOTEFONTTRANSPARENCY;
	GLfloat cr = 0;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,25);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderD(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONTSIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONTSIZE)*f-0.5);
	GLfloat h = 255*NOTEFONTTRANSPARENCY;
	GLfloat cr = 0;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Insert(r,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,25);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderE(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONTSIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONTSIZE)*f-0.5);
	GLfloat h = 255*NOTEFONTTRANSPARENCY;
	GLfloat cr = 0;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,25);
	 
	/*
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(r,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	 */
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderF(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONTSIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONTSIZE)*f-0.5);
	GLfloat h = 255*NOTEFONTTRANSPARENCY;
	GLfloat cr = 0;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert(r,t,cr,cg,cb,25);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderG(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONTSIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONTSIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONTSIZE)*f-0.5);
	GLfloat h = 255*NOTEFONTTRANSPARENCY;
	GLfloat cr = 0;
	GLfloat cg = 0;
	GLfloat cb = 0;
	Vertices2Clear();
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,25);
	Vertices2Insert(r,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRender(int i,int j)
{
	GLfloat f = 1.0/SPLITCOUNT;
	GLfloat l = 2*((i-0.1+0.5)*f-0.5);
	GLfloat r = 2*((i+0.1+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+0.1)*f-0.5);
	GLfloat b = 2*((j+0.5-0.1)*f-0.5);
	GLfloat h = 255;
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
	Vertices2Render(GL_LINES);
}

void ButtonsRender()
{
	for(int j=0;j<SPLITCOUNT;j++)
	{
		for(int i=0;i<SPLITCOUNT;i++)
		{
			ButtonRender(i,j,NoteStates[(5*j+i)%12]);
			switch( (5*j+i+9)%12 )
			{
				case 0:
					NoteNameRenderA(i,j);
					break;
				case 2:
					NoteNameRenderB(i,j);
					break;
				case 3:
					NoteNameRenderC(i,j);
					break;
				case 5:
					NoteNameRenderD(i,j);
					break;
				case 7:
					NoteNameRenderE(i,j);
					break;
				case 8:
					NoteNameRenderF(i,j);
					break;
				case 10:
					NoteNameRenderG(i,j);
					break;
			}
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
	//float intensity = 255;//(127+127*((SliderValues[8]-0.25)/3)*2);
	int r = 200;
	int g = 200;
	int b = 200;
	if(susiNgPanalo != NULL)
	{
		r = 255;
		g = 0;
		b = 0;
	}
	if(SliderValues[8]<0.25)
	{
		r = 0;
		g = 255;
		b = 0;
	}
	if(SliderValues[8]>0.01)
	{
		Vertices2Clear();
		for(int i=0;i<SPLITCOUNT;i++)
		{
			float v = -1 + i*2.0/SPLITCOUNT;
			//Vertices2Insert(-1,v,0,255,0,255);
			//Vertices2Insert(1,v,0,255,0,255);
			Vertices2Insert(v,-1,r,g,b,255);
			Vertices2Insert(v,1,r,g,b,255);
		}
		Vertices2Render(GL_LINES);
	}
}

static const GLfloat vertices[4][3] = {
	{-1.0,  1.0, -0.0},
	{ 1.0,  1.0, -0.0},
	{-1.0, -1.0, -0.0},
	{ 1.0, -1.0, -0.0}
};

static const GLfloat texCoords[] = {
	0.0, 1.0,
	1.0, 1.0,
	0.0, 0.0,
	1.0, 0.0
};

//Must be of size BUFFER_SIZE
void Oscilliscope(GLfloat l,GLfloat r,GLfloat t,GLfloat b,float* bufferData,float rd,float gr,float bl)
{
//	l *= 0.9;
//	r *= 0.9;
	r *= 0.1;
	if(NothingTouched())
	{
		//Nothing to draw unless there are touches
	}
	else 
	{		
		GLfloat v = (t+b)/2;
		GLfloat a = (t-b);
		float c = 200;
		Vertices2Clear();
		Vertices2Insert(l,t, c,c, c, 0);
		Vertices2Insert(r,t, c,c, c, 0);
		Vertices2Insert(l,v, c,c, c, 64);
		Vertices2Insert(r,v, c,c, c, 64);
		Vertices2Render(GL_TRIANGLE_STRIP);	
		
		Vertices2Clear();
		Vertices2Insert(l,v, c,c, c, 64);
		Vertices2Insert(r,v, c,c, c, 64);
		Vertices2Insert(l,b, c,c, c, 0);
		Vertices2Insert(r,b, c,c, c, 0);
		Vertices2Render(GL_TRIANGLE_STRIP);	
		
		Vertices2Clear();
		/*
		while(samples < BUFFER_SIZE/2)
		{
			samples *=2;
		}
		while(samples >= BUFFER_SIZE)
		{
			samples /=2;
		}
		 */
		//NSLog(@"%f %d",minimumFrequency,oscilliscopeCursor%BUFFER_SIZE);
		//give it up for now... need to make oscilliscope stand still!
		for(unsigned int i=0; i<BUFFER_SIZE; i++)
		{
			Vertices2Insert(
							l+(r-l)*(1.0*i)/(BUFFER_SIZE),
							v + a*bufferData[(i+oscilliscopeCursor)%(BUFFER_SIZE)], 
							rd,gr, bl, 200);
		}
		Vertices2Render(GL_LINE_STRIP);	
	}
}

void ControlSnapRenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,int slider)
{
	GLfloat v = (2*t+b)/3;
	//GLfloat a = (t-b);
	GLfloat n = 12;
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(
			l+(r-l)*i/n,
			v -0.01 * (1 + (i==3 || (i==10))*2), 
			255,255, 255, 
			i/n*255
		);
		Vertices2Insert(
			l+(r-l)*i/n,
			v +0.01 * (1 + (i==3 || (i==10))*2), 
			255,255, 255, 
			i/n*255
		);
	}
	Vertices2Render(GL_LINES);	
}

void Control4RenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,int slider)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i/n,v + 0.1*a*sinf(200*((i+tickCounter)/n)+SliderValues[6]*8*cosf( scale*tickCounter/10.0)), 255,255, 255, i/n*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}


void ControlFifthsRenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i/n,v + 0.1*a*sinf(M_PI*3*10.0*((i+tickCounter)/n)), 255,255, 255, i/n*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i/n,v + 0.2*a*sinf(M_PI*10.0*((i+tickCounter)/n)), 255,255, 255, i/n*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}

void Control3RenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i/n,v + 0.1*a*sinf(M_PI*20.0*((i+tickCounter)/n)), 255,255, 255, i/n*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i/n,v + 0.2*a*sinf(M_PI*10.0*((i+tickCounter)/n)), 255,255, 255, i/n*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}

void Control1RenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat d = 0.01;
	GLfloat U = v - 0.05;
	GLfloat D = v + 0.05;
	GLfloat R = 0.000005;
	bounceX += bounceDX;
	bounceY += bounceDY;
	if(bounceX < l)
	{
		bounceX = l;
		bounceDX = R+d;
	}
	if(r < bounceX)
	{
		bounceX = r;
		bounceDX = -R-d;
	}
	if(bounceY < U)
	{
		bounceY = U;
		bounceDY = R+d;
	}
	if(D < bounceY)
	{
		bounceY = D;
		bounceDY = -R-d;
	}
	GLfloat p = 255 * (bounceX-l)/(r-l);
	
	Vertices2Clear();
	Vertices2Insert(bounceX-d,bounceY-d, 255,255, 255, p);
	Vertices2Insert(bounceX+d,bounceY-d, 255,255, 255, p);
	Vertices2Insert(bounceX-d,bounceY+d, 255,255, 255, p);
	Vertices2Insert(bounceX+d,bounceY+d, 255,255, 255, p);
	Vertices2Render(GL_TRIANGLE_STRIP);	
	
}
						
void Control0RenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i/n,v + 0.1*a*sinf(M_PI*8.0*((i+tickCounter)/n)), 255,255, 255, i/n*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}

float sign(float x)
{
	return (x<=0) ? -1 : 1;
}

void Control2RenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	Vertices2Clear();
	for(int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i/n,v + 0.1*a*sign(sinf(M_PI*8.0*((i+tickCounter)/n))), 255,255, 255, i/n*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}
						
void ControlRender()
{
	GLfloat t = -1 + 2.0/SPLITCOUNT;
	GLfloat b = -1;
	GLfloat a = (t-b);
	
	GLfloat v = (2*t+b)/3;
	
	GLfloat begin = -1;
	GLfloat end = 1;
	int sliderCount=SLIDERCOUNT;
	for(int slider=0; slider < sliderCount; slider++)
	{
		GLfloat sl = begin + slider * (end-begin) / sliderCount;
		GLfloat sr = begin + (slider+1) * (end-begin) / sliderCount;
		GLfloat sv = sl + SliderValues[slider]*(sr-sl);
		
		GLfloat cr = 0;
		GLfloat cg = 0;
		GLfloat cb = 0;
		if(slider==0)
		{
			cg = 255;
		}
		if(slider==1)
		{
			cb = 255;
		}
		if(slider==2)
		{
			cr = 255;
		}
		if(slider==3)
		{
			cr = 200;
			cb = 200;
		}
		if(slider==4)
		{
			cr = 200;
			cb = 200;
		}
		if(slider==5)
		{
			cr = 200;
			cg = 100;
		}
		if(slider==6)
		{
			cr = 200;
			cg = 100;
		}
		if(slider==7)
		{
			cr = 200;
			cg = 100;
		}
		if(slider==8)
		{
			cr = 200;
			cg = 200;
			cb = 200;
		}
		
		GLfloat crd = cr * 0.5;
		GLfloat cgd = cg * 0.5;
		GLfloat cbd = cb * 0.5;
		
		Vertices2Clear();
		Vertices2Insert(sl,t, crd,cgd, cbd, 255);
		Vertices2Insert(sr,t, crd,cgd, cbd, 255);
		Vertices2Insert(sl,b, crd*0.50*0.5,cgd*0.5*0.5, cbd*0.5*0.5, 255);	
		Vertices2Insert(sr,b, crd*0.25*0.5,cgd*0.25*0.5, cbd*0.25*0.5, 255);	
		Vertices2Render(GL_TRIANGLE_STRIP);	
		
		Vertices2Clear();
		Vertices2Insert(sl,v+a*0.27, cr,cg, cb, 255);
		Vertices2Insert(sv,v+a*0.27, cr,cg, cb, 255);
		Vertices2Insert(sl,v-a*0.27, cr*0.5*0.5,cg*0.5*0.5, cb*0.5*0.5, 255);	
		Vertices2Insert(sv,v-a*0.27, cr*0.25*0.5,cg*0.25*0.5, cb*0.25*0.5, 255);	
		Vertices2Render(GL_TRIANGLE_STRIP);	
		
		switch(slider)
		{
			case 0: Control0RenderSkin(sl,sr,t,b); break;
			case 1: Control1RenderSkin(sl,sr,t,b); break;
			case 2: Control2RenderSkin(sl,sr,t,b); break;
			case 3: Control3RenderSkin(sl,sr,t,b); break;
			case 4: ControlFifthsRenderSkin(sl,sr,t,b); break;
			case 5: Control4RenderSkin(sl,sr,t,b,0.25,5); break;
			case 6: Control0RenderSkin(sl,sr,t,b); break;
			case 7: Control4RenderSkin(sl,sr,t,b,1.0,7); break;
			case 8: ControlSnapRenderSkin(sl,sr,t,b,1.0,7); break;
			//default:
				//TODO
		}
	}
}

void FingerControl(float i,float j)
{
	//Slidercontrol spans 5 slots
	float sliderf = 1.0*SLIDERCOUNT*i/NOTECOUNT;
	//int slider = (int)sliderf;
	int slider = currentControl;
	float v = sliderf - slider;
	if(v<0)
	{
		v = 0.0;
		//We can never allow gain to be 0, else we will get stuck notes!
		if(slider == 2)
		{
			v = 0.01;
		}
	}
	if(v > 1.0)
	{
		v = 1.0;
	}
	if(slider == currentControl)
	{
		switch(slider)
		{
			case 0: SliderValues[0]=v; [lastAudio setMaster: SliderValues[0]]; break;
			case 1: SliderValues[1]=v; [lastAudio setReverb: SliderValues[1]]; break;
			case 2: SliderValues[2]=v; [lastAudio setGain: SliderValues[2]]; break;
			case 3: SliderValues[3]=v; [lastAudio setPower: SliderValues[3]]; break;
			case 4: SliderValues[4]=v; [lastAudio setFM1: SliderValues[4]]; break;
			case 5: SliderValues[5]=v; [lastAudio setFM2: SliderValues[5]]; break;
			case 6: SliderValues[6]=v; [lastAudio setFM3: SliderValues[6]]; break;
			case 7: SliderValues[7]=v; [lastAudio setFM4: SliderValues[7]]; break;
			case 8: SliderValues[8]=v; snapPercent=v; break;
		}
	}
}

void FingerRenderLines(CGPoint p,int touchIndex)
{
	CGFloat px=p.x+SnapAdjustH[touchIndex];
	CGFloat py=p.y;
	GLfloat x = (0.5-p.x/backingWidth)*2;
	GLfloat y = (0.5-py/backingHeight)*2;
	float jfl = SPLITCOUNT-(1.0*SPLITCOUNT * py)/backingHeight;
	
	Vertices2Clear();	
	GLfloat d = 1.25/SPLITCOUNT;
	GLfloat l = d - x;
	GLfloat t = d + y;
	GLfloat r = -d - x;
	GLfloat b = -d + y;
	Vertices2Insert(l,(t+b)/2, 255, 255, 255, 150);
	Vertices2Insert(r,(t+b)/2, 255,255, 255, 150);
	Vertices2Insert((l+r)/2,t, 255,255, 255, 150);
	Vertices2Insert((l+r)/2,b, 255,255, 255, 150);
	Vertices2Render(GL_LINES);
}

void FingerRenderRaw2(float i,float j,GLfloat x,GLfloat y,CGFloat px,CGFloat py)
{
	
	GLfloat d = 1.0/SPLITCOUNT;
	GLfloat l = d - x;
	GLfloat t = d + y;
	GLfloat r = -d - x;
	GLfloat b = -d + y;
	GLfloat flat = 127 + 127 * cosf((i)*2*M_PI);//255*(i-((int)(i+0.5)));
	GLfloat sharp = 127 + 127 * cosf((i+0.5)*2*M_PI);//*(((int)(i))-i);
	GLfloat harm = 127 + 127 * cosf((j)*2*M_PI);//*(((int)(i))-i);
	Vertices2Insert(l,t, flat, sharp, harm, 150);
	Vertices2Insert(r,t, flat,sharp, harm, 150);
	Vertices2Insert(l,b, flat,sharp, harm, 150);
	Vertices2Insert(r,b, flat,sharp, harm, 150);
}

void FingerRenderRaw(CGPoint p,int touchIndex)
{
	CGFloat px=p.x+SnapAdjustH[touchIndex];
	CGFloat py=p.y;
	GLfloat x = (0.5-px/backingWidth)*2;
	GLfloat y = (0.5-py/backingHeight)*2;
	float jfl = SPLITCOUNT-(1.0*SPLITCOUNT * py)/backingHeight;
	float j = (int)jfl;
	if(j<1)
	{
		if(touchIndex >= 0)
		{
			if(FindPhaseByIndex(touchIndex)==UITouchPhaseMoved)
			{
				float i = (SPLITCOUNT * p.x)/backingWidth;
				FingerControl(i,jfl);
				
				adjustmentProgress = 8;
				//NSLog(@"reset");
			}
			else 
			{
				if(frameDrawn == 0)
				{
					//NSLog(@"progress %d %d",panalo,currentControl);
					if(adjustmentProgress==1 && currentControl==4)adjustmentProgress--;
					if(adjustmentProgress==2 && currentControl==4)adjustmentProgress--;
					if(adjustmentProgress==3 && currentControl==3)adjustmentProgress--;
					if(adjustmentProgress==4 && currentControl==4)adjustmentProgress--;
					
					if(adjustmentProgress==5 && currentControl==3)adjustmentProgress--;
					if(adjustmentProgress==6 && currentControl==3)adjustmentProgress--;
					if(adjustmentProgress==7 && currentControl==4)adjustmentProgress--;
					if(adjustmentProgress==8 && currentControl==3)adjustmentProgress--;
					if(adjustmentProgress==0)
					{
						makeAdjustments();
						adjustmentProgress = 8;
					}
					frameDrawn = 1;
				}
			}

		}
	}
	else 
	{
		float i = (SPLITCOUNT * px)/backingWidth;
		FingerRenderRaw2(i,jfl,x,y,px,py);
	}
}

void FingersRenderAllLines()
{
	for(int touchIndex=0; touchIndex < FINGERS; touchIndex++)
	{
		UITouch* touch = FindTouchByIndex(touchIndex);
		if(touch != NULL)
		{
			CGPoint lastPoint = FindPointByIndex(touchIndex);
			FingerRenderLines(lastPoint,touchIndex);
		}
	}
}

void FingersRender(bool fresh)
{
	Vertices2Clear();
	for(int touchIndex=0; touchIndex < FINGERS; touchIndex++)
	{
		UITouch* touch = FindTouchByIndex(touchIndex);
		if(touch != NULL)
		{
			CGPoint lastPoint = FindPointByIndex(touchIndex);
			FingerRenderRaw(lastPoint,touchIndex);
		}
	}
	Vertices2Render(GL_TRIANGLE_STRIP);
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
		//SetupTextureMapping();
		//touchQueueHead = 0;		
    }
	//MasterVol is 1/4 in beginning
	SliderValues[0] = SLIDER0;
	SliderValues[1] = SLIDER1;
	SliderValues[2] = SLIDER2;
	SliderValues[3] = SLIDER3;
	SliderValues[4] = SLIDER4;
	SliderValues[5] = SLIDER5;
	SliderValues[6] = SLIDER6;
	SliderValues[7] = SLIDER7;
	SliderValues[8] = SLIDER8;
	
	somethingChanged = true;
	TouchesInit();
	ButtonStatesInit();

	sound = [AudioOutput alloc];
	lastAudio = sound;
	[sound init];
	[sound start];
	ButtonsTrack();
	makeAdjustments();
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
	//CollectOrphanedNotes(lastTouches);
	LinesRender();
	ControlRender();
	FingersRender(true);
	FingersRenderAllLines();
	
	Oscilliscope(-0.95, 9, 0.8, 0.9, bufferL,0,255,0);		
	Oscilliscope(-0.95, 9, 0.8, 0.9, bufferR,255,0,0);		
	
	ButtonsTrack();
	
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
	NSArray* touchArray = [touches allObjects];
	for(int t=0; t < [touches count]; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		if([touch phase]==UITouchPhaseBegan)
		{
			BeginIndexByTouch(touch,v,t);
		}
		if([touch phase]==UITouchPhaseEnded)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
		if([touch phase]==UITouchPhaseCancelled)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
	}
	ButtonsTrack();
}

- (void)touchesMoved:(NSSet*)touches atView:(UIView*)v
{
	NSArray* touchArray = [touches allObjects];
	for(int t=0; t < [touches count]; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		if([touch phase]==UITouchPhaseMoved)
		{
			MoveIndexByTouch(touch,v,t);
		}
		if([touch phase]==UITouchPhaseEnded)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
		if([touch phase]==UITouchPhaseCancelled)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
	}
	ButtonsTrack();
}

- (void)touchesEnded:(NSSet*)touches atView:(UIView*)v
{
	NSArray* touchArray = [touches allObjects];
	int deadTouches = 0;
	int touchCount = [touches count];
	for(int t=0; t < touchCount; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		if([touch phase]==UITouchPhaseEnded)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
		if([touch phase]==UITouchPhaseEnded)
		{
			deadTouches++;
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
		if([touch phase]==UITouchPhaseCancelled)
		{
			deadTouches++;
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
	}
	//NSLog(@"%d %d",touchCount,deadTouches);
	//If all touches are dead, then be totally sure that sound is cut off
	if(touchCount == deadTouches)
	{
		for(int t=0; t < FINGERS; t++)
		{
			DeleteTouchByIndex(t,t);
			[lastAudio setVol:0.0 forFinger:t];
		}
	}
	ButtonsTrack();
}

- (void)touchesCancelled:(NSSet*)touches atView:(UIView*)v
{
	NSArray* touchArray = [touches allObjects];
	for(int t=0; t < [touches count]; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		if([touch phase]==UITouchPhaseEnded)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
		if([touch phase]==UITouchPhaseCancelled)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
	}
	ButtonsTrack();
}
@end
