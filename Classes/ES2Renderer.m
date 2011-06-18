//
//  ES2Renderer.m
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//
//  Visual polish and various bug fixes added by Gavin Norton on 2011-06-16
//  Color choices derived from http://www.colorjack.com/sphere/ Six-Tone (CCW) with hue 36, sat 82 and bal 100
//

//#import <CoreGraphics/CoreGraphics.h>

#import "ES2Renderer.h"

static int SPLIT_COUNT = 12;
#define SLIDER_COUNT 12

#define NOTE_COUNT 12
#define kOctaveFactor 2.0
static const int NoteColors[NOTE_COUNT] = {1,0,1, 1,0,1,0,1, 1,0,1,0}; //color pattern starting on 'A', for 12EDO
#define VERTICAL_STEP_SIZE 5        // step distance between "strings"
#define NOTE_OFFSET  3              // shifts layout and sounds on entire surface by this many steps. 3 is original Mugician layout

//#define NOTE_COUNT 10
//#define kOctaveFactor 2.0
//static const int NoteColors[NOTE_COUNT] = {1,0,1, 1,0,1,0,1, 1,0}; //color pattern starting on 'A', for 10EDO
//#define VERTICAL_STEP_SIZE 4        // step distance between "strings"
//#define NOTE_OFFSET  3              // shifts layout and sounds on entire surface by this many steps.

//#define NOTE_COUNT 13
//#define kOctaveFactor 3.0
//static const int NoteColors[NOTE_COUNT] = {1,0,1, 1,0,1,0,1, 1,0,1,0,1}; //color pattern starting on 'A', for13TET Bohlen-Pierce
//#define VERTICAL_STEP_SIZE 5        // step distance between "strings"
//#define NOTE_OFFSET  -26            // shifts layout and sounds on entire surface by this many steps.

#define kMiddleAFrequency 440.0
#define center1DNoteAdjustment ((1.0-(SPLIT_COUNT%2))/2.0)
#define center2DNoteAdjustment center1DNoteAdjustment*center1DNoteAdjustment
#define kMiddleANote  (0.25*SPLIT_COUNT*SPLIT_COUNT)+center2DNoteAdjustment-NOTE_COUNT+2.0

static float NoteStates[NOTE_COUNT];
static float MicroStates[NOTE_COUNT];

// The pixel dimensions of the CAEAGLLayer
static GLint backingWidth;
static GLint backingHeight;
static float inverseBackingWidth;
static float inverseBackingHeight;
static unsigned int tickCounter=0;

#define SLIDER0 0.5
#define SLIDER1 0.79296875
#define SLIDER2 0.663085938
#define SLIDER3 0.735351562
#define SLIDER4 0.25
#define SLIDER5 0.46
#define SLIDER6 0.1
#define SLIDER7 0.0
#define SLIDER8 0.400000006
#define SLIDER9 0.5
#define SLIDER10 0.0
#define SLIDER11 0.1

#define SL_MVOL 0
#define SL_REVERB 1
#define SL_ATANDIST 2
#define SL_OCTAVE 3
#define SL_FMDIST 4
#define SL_ECHOPERIOD 5
#define SL_ECHOFEEDBACK 6
#define SL_ECHOVOL 7
#define SL_FRET 8
#define SL_POLY 9
#define SL_PRESET 10
#define SL_LOCK 11
/*
static const int SliderColors[SLIDER_COUNT][3] = {
    {125,   0, 125}, // deep purple
    {  0, 125, 125}, // deep teal
    {125, 125,   0}, // deep olive
    {150,  68, 150}, // purple
    {150,  68, 150}, // purple
    {  0, 125, 125}, // deep teal
    {  0, 125, 125}, // deep teal
    {  0, 125, 125}, // deep teal
    {150,  68, 150}, // purple
    { 68, 150, 150}, // teal
    {150, 150,  68}, // olive
    {125, 125,   0}, // deep olive
};
*/
static const GLfloat SliderColors[SLIDER_COUNT][3] = {
//    {255, 171,  46}, // orange
//    { 46, 255, 171}, // green
//    { 67,  46, 255}, // blue
//    {171,  46, 255}, // purple
//    {255,  67,  46}, // red

    { 67,  46, 255}, // blue
    {255, 171,  46}, // orange
    { 46, 255, 171}, // green
    {171,  46, 255}, // purple
    {171,  46, 255}, // purple
    {255, 171,  46}, // orange
    {255, 171,  46}, // orange
    {255, 171,  46}, // orange
    {255,  67,  46}, // red
    {255,  67,  46}, // red
    {255,  67,  46}, // red
    {255,  67,  46}, // red
};

#define SL_LOCK_THRESHOLD 0.5
static const int PadlockXColorRGB[3] = {255, 255,  255};
#define NUM_PRESETS    12  // may have to be 12 or smaller (if raised, this code needs more letter rendering code)

#define TOUCHQUEUELEN (FINGERS)

#define POLYPHONYMAX 8
#define SL_POLY_1_THRESHOLD 0.33
#define SL_POLY_2_THRESHOLD 0.66

#define ACTIVECONTROL_PLAYAREA -1
#define ACTIVECONTROL_NOTHING -2

#define NOTEFONT_SIZE 0.05
#define NOTEFONT_TRANSPARENCY 0.3 // was 0.5

static const GLfloat GradientColors[4] = {255, 255, 255, 127};
#define GRADIENT_FADE 0.5

static const GLfloat WhiteButtonColors[4] = { 40,  40,  40, 127};
static const GLfloat BlackButtonColors[4] = { 24,  24,  24, 127};
static const GLfloat MicroButtonColors[4] = {255,  67,  46, 200};
static const GLfloat WhiteButtonHilite[4] = { 67,  46, 255, 127};
static const GLfloat BlackButtonHilite[4] = {255, 171,  46, 127};
static const GLfloat FretLineColorsRGBA[3][4] = {
    {255, 255, 255, 32},
    {255, 255, 255, 32},
    {  0,   0,   0, 32},
};
static const GLfloat TrackLineColorsRGBA[3][4] = {
    {  0,   0,   0, 127},
    {255,  67,  46, 48}, 
};
#define kButtonLBFactor 0.1    // was 0.50
#define kButtonRBFactor 0.1    // was 0.25

#define DEFAULT_PRESSURE 0.5

#define FINGER_A 127   // was 150

#define kNoteFadeRGBFactor 0.95 // was 0.98


static AudioOutput* lastAudio;

static float LastJ[TOUCHQUEUELEN];
static float LastI[TOUCHQUEUELEN];
static float SnapAdjustH[TOUCHQUEUELEN];
static int activeControl[TOUCHQUEUELEN]; //-1 is the main area, above that is a ref to a slider
static int currentControl = ACTIVECONTROL_NOTHING;

static float SliderFileValues[NUM_PRESETS][SLIDER_COUNT];
static float SliderValues[NUM_PRESETS][SLIDER_COUNT];
static unsigned int SliderPreset = SLIDER10;
//static float SliderAdjustH[SLIDERCOUNT];

static float bounceX =0.0;
static float bounceY =0.0;
static float bounceDX=0.1;
static float bounceDY=0.1;

static void* touchQueue[TOUCHQUEUELEN];
//static long touchTimeStampPrev[TOUCHQUEUELEN];
static UITouchPhase touchPhase[TOUCHQUEUELEN];
static CGPoint touchPoint[TOUCHQUEUELEN];
//static NSTimeInterval touchTime[TOUCHQUEUELEN];

//Yes, counting notes!
static unsigned int touchNoteNumber[TOUCHQUEUELEN];
static unsigned int noteNumber=0;

//Yeah, this one!
static float touchMe[TOUCHQUEUELEN];
static char pmrData[16];
static NSString* susiNgPanalo = NULL;
static int adjustmentProgress = 8; //we got it when we reach 0

static int touchIsMaxNote[TOUCHQUEUELEN];

static unsigned int timeTapStart = 0;

//Need to read and write out preferences so that all locked settings are saved on lock
NSString* FindDocumentsDirectory() {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [paths objectAtIndex:0];
}

NSString* FindResourcesDirectory() {
	return NSHomeDirectory();
}

//Done whenever a setting is locked
void WritePreferences()
{
	//Generate the data file to write into a string
	NSMutableString* str = [[NSMutableString alloc] init];
	
	//Append a version for this format
	[str appendFormat:@"%d\n", 161];
	//The default preset to bring up on startup - the last written
	[str appendFormat:@"%d\n", SliderPreset];

	//The default preset to bring up on startup - the last written
	[str appendFormat:@"%d\n", susiNgPanalo==NULL?0:1973];
	
	//Update the slider file values
	for(unsigned int preset=0; preset < NUM_PRESETS; preset++)
	{
		//*Locked* values overwrite what goes out to file
		if(SliderValues[preset][SL_LOCK] > SL_LOCK_THRESHOLD)
		{
			for(unsigned int slider=0; slider < SLIDER_COUNT; slider++)
			{
				SliderFileValues[preset][slider] = SliderValues[preset][slider];
			}
		}
	}
	//Append a list of floats, one for each preset
	for(unsigned int preset=0; preset < NUM_PRESETS; preset++)
	{
		for(unsigned int slider=0; slider < SLIDER_COUNT; slider++)
		{
			[str appendFormat:@"%f ", SliderFileValues[preset][slider] ];			
			//NSLog(@"w: %d,%d -> %f",preset,slider, SliderValues[preset][slider]);
		}
		[str appendString:@"\n"];			
	}
	
	NSData *data = [[NSData alloc] initWithBytes:[str UTF8String] length:[str length]]; 
	
	//Where to write it?
	NSString* docs = FindDocumentsDirectory();
	NSString *appFile = [docs stringByAppendingPathComponent:@"mugician.presets"];
	
	//Write it out
	[data writeToFile:appFile atomically:YES];
}

void SyncWithPreset(unsigned int preset)
{
	[lastAudio setMaster: SliderValues[preset][SL_MVOL]]; 
	[lastAudio setReverb: SliderValues[preset][SL_REVERB]]; 
	[lastAudio setGain: SliderValues[preset][SL_ATANDIST]]; 
	[lastAudio setPower: SliderValues[preset][SL_OCTAVE]]; 
	[lastAudio setFM1: SliderValues[preset][SL_FMDIST]]; 
	[lastAudio setDelayTime: SliderValues[preset][SL_ECHOPERIOD]]; 
	[lastAudio setDelayFeedback: SliderValues[preset][SL_ECHOFEEDBACK]]; 
	[lastAudio setDelayVolume: SliderValues[preset][SL_ECHOVOL]]; 
}

void SetValueForFingerControl(const unsigned int slider, const float v, const unsigned int isSwitching)
{
	const unsigned int isLocked = (SliderValues[SliderPreset][SL_LOCK] > SL_LOCK_THRESHOLD) && !isSwitching;
	switch(slider)
	{
		case SL_MVOL: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_MVOL]=v; 
				[lastAudio setMaster: SliderValues[SliderPreset][SL_MVOL]]; 
			}
			break;
		}
		case SL_REVERB: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_REVERB]=v; 
				[lastAudio setReverb: SliderValues[SliderPreset][SL_REVERB]]; 
			}
			break;
		}
		case SL_ATANDIST: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_ATANDIST]=v; 
				[lastAudio setGain: SliderValues[SliderPreset][SL_ATANDIST]]; 
			}
			break;
		}
		case SL_OCTAVE: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_OCTAVE]=v; 
				[lastAudio setPower: SliderValues[SliderPreset][SL_OCTAVE]]; 
			}
			break;
		}
		case SL_FMDIST: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_FMDIST]=v; 
				[lastAudio setFM1: SliderValues[SliderPreset][SL_FMDIST]]; 
			}
			break;
		}
		case SL_ECHOPERIOD: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_ECHOPERIOD]=v; 
				[lastAudio setDelayTime: SliderValues[SliderPreset][SL_ECHOPERIOD]]; 
			}
			break;
		}
		case SL_ECHOFEEDBACK: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_ECHOFEEDBACK]=v; 
				[lastAudio setDelayFeedback: SliderValues[SliderPreset][SL_ECHOFEEDBACK]]; 
			}
			break;
		}
		case SL_ECHOVOL: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_ECHOVOL]=v; 
				[lastAudio setDelayVolume: SliderValues[SliderPreset][SL_ECHOVOL]]; 
			}
			break;
		}
		case SL_FRET: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_FRET]=v; 
			}
			break;
		}
		case SL_POLY: {
			if(!isLocked)
			{
				SliderValues[SliderPreset][SL_POLY]=v; 
			}
			break;
		}
		case SL_PRESET: {
			unsigned int oldV = (int)(1.0*SliderValues[SliderPreset][SL_PRESET]*NUM_PRESETS)-1;				
			unsigned int newV = (int)(1.0*NUM_PRESETS*v)-1; 
			SliderValues[SliderPreset][SL_PRESET]=v; 					
			if(oldV != newV)
			{
				//NSLog(@"%d -> %d   %f",oldV,newV,v);
				//Set both of these sliders to same value and recheck
				//Redo all sliders
				SliderPreset = newV;
				SliderValues[SliderPreset][SL_PRESET]=v; 			
				SyncWithPreset(SliderPreset);
			}
			break;
		}
		case SL_LOCK: {
			unsigned int oldLocked = SliderValues[SliderPreset][SL_LOCK] > SL_LOCK_THRESHOLD;
			unsigned int newLocked = v > SL_LOCK_THRESHOLD;
			SliderValues[SliderPreset][SL_LOCK]=v; 
			if(oldLocked != newLocked && !isSwitching && newLocked)
			{
				WritePreferences();
			}
			break;
		}
	}
}

static inline void makeAdjustments()
{
	if(susiNgPanalo == NULL)
	{
		char* pmr = "qbuiNbkpsSbejvt";	
		for(unsigned int i=0; i<15; i++)
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


//Only done on startup, so we don't go back and refresh
void ReadPreferences()
{
	NSError* error = nil;
	NSString* dataString = nil;
	NSString* docs = FindDocumentsDirectory();
	//NSString* resources = FindResourcesDirectory();
	NSScanner* scanner = nil;
	NSString* appFile = nil;
	int version = 0;
	int adjusted=0;
	
	//Look in documents directory first
	if(docs != NULL)
	{
		appFile = [docs stringByAppendingPathComponent:@"mugician.presets"];
		if(appFile != NULL)
		{
			dataString = [NSString stringWithContentsOfFile:appFile encoding:NSUTF8StringEncoding error:&error];
		}		
	}
	
	//Try resources if no document yet
	if(dataString == NULL)
	{
		appFile = (NSString*)[[NSBundle mainBundle] pathForResource:@"mugician" ofType:@"presets"];
		if(appFile != NULL)
		{
			dataString = 
			[NSString stringWithContentsOfFile:appFile encoding:NSUTF8StringEncoding error:&error];
		}
	}
	
	//If we found something to load
	if(dataString != NULL)
	{
		scanner = [NSScanner scannerWithString:dataString];
		[scanner scanInt:&version];
		//Can't compare floats for equality for even the simplest things
		if(version == 161)
		{
			int presetVal;
			[scanner scanInt:&presetVal];
			SliderPreset = presetVal;
			[scanner scanInt:&adjusted];
			if(adjusted == 1973)
			{
				makeAdjustments();
			}
			if(SliderPreset >= SLIDER_COUNT)SliderPreset = SLIDER_COUNT-1;
			for(unsigned int preset=0; preset < SLIDER_COUNT; preset++)
			{
				for(unsigned int slider=0; slider < SLIDER_COUNT; slider++)
				{
					//Protect against garbage data
					[scanner scanFloat:&SliderFileValues[preset][slider]];
					if(SliderFileValues[preset][slider] < 0)SliderFileValues[preset][slider]=0;
					if(SliderFileValues[preset][slider] > 1)SliderFileValues[preset][slider]=1;
					//NSLog(@"r: %d,%d -> %f",preset,slider, SliderValues[preset][slider]);
					
					SliderValues[preset][slider] = SliderFileValues[preset][slider];
				}
			}
		}
	}
	else
	{
		//Just put in some defaults
		for(unsigned int i=0;i<NUM_PRESETS;i++)
		{
			SliderFileValues[i][0] = SliderValues[i][0] = SLIDER0;
			SliderFileValues[i][1] = SliderValues[i][1] = SLIDER1;
			SliderFileValues[i][2] = SliderValues[i][2] = SLIDER2;
			SliderFileValues[i][3] = SliderValues[i][3] = SLIDER3;
			SliderFileValues[i][4] = SliderValues[i][4] = SLIDER4;
			SliderFileValues[i][5] = SliderValues[i][5] = SLIDER5;
			SliderFileValues[i][6] = SliderValues[i][6] = SLIDER6;
			SliderFileValues[i][7] = SliderValues[i][7] = SLIDER7;
			SliderFileValues[i][8] = SliderValues[i][8] = SLIDER8;
			SliderFileValues[i][9] = SliderValues[i][9] = SLIDER9;
			SliderFileValues[i][10] = SliderValues[i][10] = SLIDER10;
			SliderFileValues[i][11] = SliderValues[i][11] = SLIDER11;
		}
	}
	SyncWithPreset(SliderPreset);
}





int BeginIndexByTouch(UITouch* thisTouch,UIView* lastTouchesView,const unsigned int t) 
{
	//Search for existing touch first
	int index = -1;
	for(unsigned int t=0;t<TOUCHQUEUELEN;t++)
	{
		if(touchQueue[t]==NULL)
		{
			index = t;
		}
	}
	
	if(index >= 0)
	{
		float val = DEFAULT_PRESSURE;
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
		touchNoteNumber[index] = noteNumber;
		noteNumber++;
	}
	return index;
}


int MoveIndexByTouch(UITouch* thisTouch,UIView* lastTouchesView,const unsigned int t) 
{
	for(unsigned int i=0; i<TOUCHQUEUELEN; i++) 
	{
		if(thisTouch == touchQueue[i]) 
		{
			float val = DEFAULT_PRESSURE;
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

static inline int FindIndexByTouch(UITouch* thisTouch,const unsigned int t) 
{
	for(unsigned int i=0; i<TOUCHQUEUELEN; i++) 
	{
		//DOC states that this *should* be same object throughout touch life
		if(thisTouch == touchQueue[i]) 
		{
			return i;
		}
	}
	return -1;	
}

static inline BOOL NothingTouched() 
{
	for(unsigned int i=0; i<TOUCHQUEUELEN; i++) 
	{
		//DOC states that this *should* be same object throughout touch life
		if(NULL != touchQueue[i]) 
		{
			return false;
		}
	}
	return true;	
}

void ComputeMaxNotes()
{
	const BOOL useKeyboardRules = SliderValues[SliderPreset][SL_POLY] < SL_POLY_1_THRESHOLD;
	const BOOL useKeyboardRulesPerString = !useKeyboardRules && SliderValues[SliderPreset][SL_POLY] < SL_POLY_2_THRESHOLD;
	if(useKeyboardRulesPerString)
	{
		//Nobody is max note yet...
		for(unsigned int t=0; t<TOUCHQUEUELEN; t++) 
		{
			if(NULL != touchQueue[t]) 
			{
				//int s = (int)(SPLITCOUNT-(1.0*SPLITCOUNT * touchPoint[t].y)/backingHeight);
				touchIsMaxNote[t] = (touchPhase[t] == UITouchPhaseBegan && activeControl[t]<0);
			}
		}	
		long maxNoteNumber[SPLIT_COUNT];
		int maxTouch[SPLIT_COUNT];
		for(unsigned int s=0; s<SPLIT_COUNT; s++)
		{
			maxNoteNumber[s] = -1;
			maxTouch[s] = -1;
		}
		//Find highest note number and turn that guy on
		for(unsigned int t=0; t<TOUCHQUEUELEN; t++) 
		{
			if(NULL != touchQueue[t]) 
			{
				int s = (int)(SPLIT_COUNT-(1.0*SPLIT_COUNT * touchPoint[t].y)*inverseBackingHeight);
				int ourNoteNumber = touchNoteNumber[t];
				if(activeControl[t]<0 && maxNoteNumber[s] < ourNoteNumber)
				{
					maxNoteNumber[s] = ourNoteNumber;
					maxTouch[s] = t;
				}
			}
		}	
		//TODO: if goofball turns on more than 6 notes we are doomed
		for(unsigned int s=0; s<SPLIT_COUNT; s++)
		{
			if(maxTouch[s] >= 0)
			{
				touchIsMaxNote[maxTouch[s]] = TRUE;
			}
		}
	}
	else
	if(useKeyboardRules) 
	{
		//Nobody is max note yet...
		for(unsigned int t=0; t<TOUCHQUEUELEN; t++) 
		{
			if(NULL != touchQueue[t]) 
			{
				//int s = (int)(SPLITCOUNT-(1.0*SPLITCOUNT * touchPoint[t].y)/backingHeight);
				touchIsMaxNote[t] = (touchPhase[t] == UITouchPhaseBegan && activeControl[t]<0);
			}
		}	
		long maxNoteNumber = -1;
		int maxTouch = -1;
		//Find highest note number and turn that guy on
		for(unsigned int t=0; t<TOUCHQUEUELEN; t++) 
		{
			if(NULL != touchQueue[t]) 
			{
				int ourNoteNumber = touchNoteNumber[t];
				if(maxNoteNumber < ourNoteNumber && activeControl[t]<0)
				{
					maxNoteNumber = ourNoteNumber;
					maxTouch = t;
				}
			}
		}	
		if(maxTouch >= 0)
		{
			touchIsMaxNote[maxTouch] = TRUE;
		}
	}
	else
	{
		for(unsigned int t=0; t<TOUCHQUEUELEN; t++) 
		{
			if(NULL != touchQueue[t]) 
			{
				touchIsMaxNote[t] = TRUE;
			}
		}	
	}
	int totalEnabled=0;
	for(unsigned int i=0; i<TOUCHQUEUELEN; i++) 
	{
		if(NULL != touchQueue[i] && touchIsMaxNote[i])
		{
			totalEnabled++;
		}
	}
	int totalToDisable =  (totalEnabled>POLYPHONYMAX) ? (totalEnabled-POLYPHONYMAX) : 0;
	//NSLog(@"%d to disable",totalToDisable);
	if(totalToDisable > 0)
	{
		for(unsigned int d=0; d<totalToDisable; d++) 
		{
			int item = 0;
			unsigned int minTouch = 0xffffffff;
			for(int j=0; j<TOUCHQUEUELEN; j++) 
			{
				if(touchIsMaxNote[j])
				{
					if(touchNoteNumber[j] < minTouch)
					{
						item = j;
						minTouch = touchNoteNumber[item];
						//NSLog(@"%d disable",minTouch);
					}
				}
			}
			//Disable it
			touchIsMaxNote[item] = FALSE;
		}
	}
}

//Do this to simplify tracking what is down vs up
static inline void DeleteTouchByIndex(const unsigned int idx,const unsigned int t)
{
	touchQueue[idx] = NULL;
}

static inline UITouchPhase FindPhaseByIndex(const unsigned int idx)
{
	return touchPhase[idx];
}


static inline CGPoint FindPointByIndex(const unsigned int idx)
{
	return touchPoint[idx];
}

//And inverse mapping
static inline void* FindTouchByIndex(const unsigned int idx)
{
	return touchQueue[idx];
}

static inline float GetFrequencyForNote(const float note) 
{
	return kMiddleAFrequency * powf(kOctaveFactor, (note - kMiddleANote) / (1.0*NOTE_COUNT));
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
	for(unsigned int i=0;i<FINGERS;i++)
	{
		activeControl[i]=ACTIVECONTROL_PLAYAREA;
		touchQueue[i] = NULL;
		touchMe[i] = 0;
		touchMe[i] = 0;
		touchIsMaxNote[i] = 1;
	}
}



static inline void ButtonStatesInit()
{
	for(unsigned int i=0;i<NOTE_COUNT;i++)
	{
		NoteStates[i]=0;
		MicroStates[i]=0;
	}
}

void TrackFingerChange(const unsigned int touchIndex,const float v,const BOOL isBegin)
{
	if(activeControl[touchIndex]==ACTIVECONTROL_PLAYAREA)
	{
		//Turn off quiet notes
		if(touchIsMaxNote[touchIndex]==0)
		{
			[lastAudio setVol:0 forFinger: touchIndex];	
			//[lastAudio setAttackVol:0 forFinger: touchIndex];	
		}
		else 
		{
			const CGPoint point = FindPointByIndex(touchIndex);
			const float ifl = (1.0*SPLIT_COUNT * (point.x+SnapAdjustH[touchIndex]))*inverseBackingWidth;
			const float jfl = SPLIT_COUNT-(1.0*SPLIT_COUNT * point.y)*inverseBackingHeight;
			
			const float n = ((int)jfl)*VERTICAL_STEP_SIZE + ifl - kOctaveFactor*SPLIT_COUNT - NOTE_OFFSET;
			const float f = GetFrequencyForNote(n);
			const float h = (jfl-((int)jfl));
			const float tm = touchMe[touchIndex];
			float press = (tm<=0) ? DEFAULT_PRESSURE : tm;
			press = atan(press/3)*3;
			//Set the minimum frequency to automatically adjust oscilliscope
			if(f < minimumFrequency)
			{
				minimumFrequency = f;
			}
			frequencyPeriod *= f;
			[lastAudio setNote:f forFinger: touchIndex isAttack: isBegin];	
			[lastAudio setVol:v*press forFinger: touchIndex];	
			[lastAudio setHarmonics:h forFinger: touchIndex];
			[lastAudio setPan:(ifl/SPLIT_COUNT) forFinger: touchIndex];
			//NSLog(@"%f",press);
			
			if(isBegin)
			{
				float gain = SliderValues[SliderPreset][SL_ATANDIST];
				if(gain > 0.2 && susiNgPanalo != NULL)
				{
					float p = (1.0+gain)*press*v;
					[lastAudio setAttackVol:p forFinger: touchIndex];	
				}
				else 
				{
					//[lastAudio setAttackVol:0 forFinger: touchIndex];	
				}
			}			
		}
	}
}

void RecheckFingers()
{
	minimumFrequency = 10000000.0;
	frequencyPeriod = 1;
	for(unsigned int f=0; f < FINGERS; f++)
	{
		const void* touch = FindTouchByIndex(f);
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
	ComputeMaxNotes();
	///*
	for(unsigned int t=0; t < TOUCHQUEUELEN; t++)
	{
		if( touchPhase[t] == UITouchPhaseBegan )
		{
			const float jfl = SPLIT_COUNT-(1.0*SPLIT_COUNT * touchPoint[t].y)*inverseBackingHeight;
			if(jfl > 1)
			{
				touchPhase[t] = UITouchPhaseMoved;
			}
		}
	}
	 //*/
}

static inline void FadeNotes()
{
	for(unsigned int n=0;n<NOTE_COUNT;n++)
	{
		NoteStates[n] *= kNoteFadeRGBFactor;
		MicroStates[n] *= kNoteFadeRGBFactor;
	}
}

void ButtonsTrack()
{
	const BOOL snapHalfTone = (SliderValues[SliderPreset][SL_FRET]>0.25);
	//BOOL snapDownNotes = false;	
	const BOOL snapQuarterTone = (!snapHalfTone && 0.01 < SliderValues[SliderPreset][SL_FRET]);
	const BOOL showMicrotonal = snapQuarterTone || snapHalfTone==false;
	const BOOL snapNotes = snapHalfTone || snapQuarterTone;
	
	for(unsigned int touchIndex=0; touchIndex < FINGERS; touchIndex++)
	{
		if(FindTouchByIndex(touchIndex)!=NULL)
		{
			const UITouchPhase phase = FindPhaseByIndex(touchIndex);		
			const CGPoint point = FindPointByIndex(touchIndex);
			
			const float ifl = (1.0*SPLIT_COUNT * point.x)*inverseBackingWidth;
			const int i = (int)ifl;
			const float jfl = SPLIT_COUNT-(1.0*SPLIT_COUNT * point.y)*inverseBackingHeight;
			const int j = (int)jfl;
			const float di = (ifl-i) - 0.5; 
			
			//Mark a control as active so that it can be used
			if(phase==UITouchPhaseBegan)
			{
				if(j < 1)
				{
					activeControl[touchIndex] = (int)((SLIDER_COUNT* point.x)*inverseBackingWidth);
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
				const BOOL newNote = (phase==UITouchPhaseBegan) || LastJ[touchIndex] != j;
				
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
							SnapAdjustH[touchIndex] = -qdi * (1.0*backingWidth)/SPLIT_COUNT;																						
						}
						else 
						{
							SnapAdjustH[touchIndex] = -di * (1.0*backingWidth)/SPLIT_COUNT;																						
						}
					}
					else 
					{
						if(!snapQuarterTone)
						{
							float snapSensitivity = (SliderValues[SliderPreset][SL_FRET]-0.25)/3*4;
							SnapAdjustH[touchIndex] = 
							(1-snapSensitivity) * SnapAdjustH[touchIndex] +
							snapSensitivity * -di * (1.0*backingWidth)/SPLIT_COUNT;
						}
					}
					
				}
				else 
				{
					SnapAdjustH[touchIndex] = 0;
				}
				LastJ[touchIndex] = j;		
				LastI[touchIndex] = ifl;
				
				const unsigned int n = (VERTICAL_STEP_SIZE*j+i)%NOTE_COUNT;
				if((j>0) && n<NOTE_COUNT)
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
							MicroStates[(n+1)%NOTE_COUNT] = (1+7*MicroStates[(n+1)%NOTE_COUNT])/8;
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
	FadeNotes();
	//frameDrawn=0;
	RecheckFingers();
}



#define SQUAREVERTICESMAX 1200
static int Vertices2Count;
//static GLfloat Vertices2[2*SQUAREVERTICESMAX];
static GLfloat Vertices2Translated[2*SQUAREVERTICESMAX];
static GLubyte Vertices2Colors[4*SQUAREVERTICESMAX];

//Recreate immediate mode
static inline void Vertices2Clear()
{
	Vertices2Count = 0;
}

///UNSAFE!!! NO BOUNDS CHECK!!!
//(all ok now)
static inline void Vertices2Insert(GLfloat x,GLfloat y,GLubyte r,GLubyte g,GLubyte b,GLubyte a)
{
    if (Vertices2Count<SQUAREVERTICESMAX) {
        Vertices2Translated[2*Vertices2Count+0] = x; 
        Vertices2Translated[2*Vertices2Count+1] = y; 
        Vertices2Colors[4*Vertices2Count+0] = r; 
        Vertices2Colors[4*Vertices2Count+1] = g; 
        Vertices2Colors[4*Vertices2Count+2] = b; 
        Vertices2Colors[4*Vertices2Count+3] = a; 
        Vertices2Count++;
    }
}

static inline void Vertices2Render(const int triType)
{
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, Vertices2Translated);
	glEnableVertexAttribArray(ATTRIB_VERTEX);
	glVertexAttribPointer(ATTRIB_COLOR, 4, GL_UNSIGNED_BYTE, 1, 0, Vertices2Colors);
	glEnableVertexAttribArray(ATTRIB_COLOR);	
    glDrawArrays(triType, 0, Vertices2Count);	
}

void ButtonRender(const int i,const int j,const float hilite)
{
	const GLfloat f = 1.0/SPLIT_COUNT;
	const GLfloat l = 2*((i+0)*f-0.5);
	const GLfloat r = 2*((i+1)*f-0.5);
	const GLfloat t = 2*((j+1)*f-0.5);
	const GLfloat b = 2*((j+0)*f-0.5);
	const int n = (j*VERTICAL_STEP_SIZE+i-NOTE_OFFSET)%NOTE_COUNT;
	
	GLfloat nr;// = w*255-hilite*255*k;
	GLfloat ng;// = w*255-hilite*255;
	GLfloat nb;// = w*255+k*hilite*255;
    GLfloat na;
	
    if(NoteColors[n]==1)
	{
		nr = WhiteButtonColors[0]+hilite*(WhiteButtonHilite[0]-WhiteButtonColors[0]);
		ng = WhiteButtonColors[1]+hilite*(WhiteButtonHilite[1]-WhiteButtonColors[1]);
		nb = WhiteButtonColors[2]+hilite*(WhiteButtonHilite[2]-WhiteButtonColors[2]);
		na = WhiteButtonColors[3]+hilite*(WhiteButtonHilite[3]-WhiteButtonColors[3]);
	}
	else
	{
		nr = BlackButtonColors[0]+hilite*(BlackButtonHilite[0]-BlackButtonColors[0]);
		ng = BlackButtonColors[1]+hilite*(BlackButtonHilite[1]-BlackButtonColors[1]);
		nb = BlackButtonColors[2]+hilite*(BlackButtonHilite[2]-BlackButtonColors[2]);
		na = BlackButtonColors[3]+hilite*(BlackButtonHilite[3]-BlackButtonColors[3]);
	}

	Vertices2Clear();

	Vertices2Insert(l,t,nr,ng,nb,na);
	Vertices2Insert(r,t,nr,ng,nb,na);
	Vertices2Insert(l,b,nr*kButtonLBFactor,ng*kButtonLBFactor,nb*kButtonLBFactor,na);
	Vertices2Insert(r,b,nr*kButtonRBFactor,ng*kButtonRBFactor,nb*kButtonRBFactor,na);
	
	Vertices2Render(GL_TRIANGLE_STRIP);
}

void MicroRedButtonRender(int i,int j,float hilite)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-0.1)*f-0.5);
	GLfloat r = 2*((i+0.1)*f-0.5);
	GLfloat t = 2*((j+0.5+0.1)*f-0.5);
	GLfloat b = 2*((j+0.5-0.1)*f-0.5);
	GLfloat cr = MicroButtonColors[0];
	GLfloat cg = MicroButtonColors[1];
	GLfloat cb = MicroButtonColors[2];
	GLfloat h  = MicroButtonColors[3]*hilite;
	Vertices2Clear();
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_TRIANGLES);
}


void NoteNameRenderA(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderB(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);	
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderC(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderD(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Insert(r,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderE(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	 
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderF(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderG(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Insert(r,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert((l+r)/2,(t+b)/2,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderH(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(r,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderI(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert((r+l)/2,t,cr,cg,cb,h);
	Vertices2Insert((r+l)/2,b,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderJ(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert((l+r)/2,t,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert((2*r+l)/3,t,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderK(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(r,t,cr,cg,cb,h);
	Vertices2Insert(l,(t+b)/2,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void NoteNameRenderL(float i,float j,int c)
{
	GLfloat f = 1.0/SPLIT_COUNT;
	GLfloat l = 2*((i-NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat r = 2*((i+NOTEFONT_SIZE+0.5)*f-0.5);
	GLfloat t = 2*((j+0.5+NOTEFONT_SIZE)*f-0.5);
	GLfloat b = 2*((j+0.5-NOTEFONT_SIZE)*f-0.5);
	GLfloat h = 255*NOTEFONT_TRANSPARENCY;
	GLfloat cr = c;
	GLfloat cg = c;
	GLfloat cb = c;
	Vertices2Clear();
	Vertices2Insert(l,t,cr,cg,cb,h);
	Vertices2Insert(l,b,cr,cg,cb,h);
	Vertices2Insert(r,b,cr,cg,cb,h);
	Vertices2Render(GL_LINE_STRIP);
}

void ButtonsRender()
{
	for(unsigned int j=0;j<SPLIT_COUNT;j++)
	{
		for(unsigned int i=0;i<SPLIT_COUNT;i++)
		{
			ButtonRender(i,j,NoteStates[(VERTICAL_STEP_SIZE*j+i)%NOTE_COUNT]);
			switch( (VERTICAL_STEP_SIZE*j+i-NOTE_OFFSET)%NOTE_COUNT )
			{
				case 0:
					NoteNameRenderA(i,j,0);
					break;
				case 2:
					NoteNameRenderB(i,j,0);
					break;
				case 3:
					NoteNameRenderC(i,j,0);
					break;
				case 5:
					NoteNameRenderD(i,j,0);
					break;
				case 7:
					NoteNameRenderE(i,j,0);
					break;
				case 8:
					NoteNameRenderF(i,j,0);
					break;
				case 10:
					NoteNameRenderG(i,j,0);
					break;
				case 12:
					NoteNameRenderH(i,j,0);
					break;
			}
		}
	}
}

void PresetRender()
{
	float i = 10;
	float j = 0.45;
	switch( (int)(11.99*SliderValues[SliderPreset][SL_PRESET]) )
	{
		case 0:
			NoteNameRenderA(i,j,255);
			break;
		case 1:
			NoteNameRenderB(i,j,255);
			break;
		case 2:
			NoteNameRenderC(i,j,255);
			break;
		case 3:
			NoteNameRenderD(i,j,255);
			break;
		case 4:
			NoteNameRenderE(i,j,255);
			break;
		case 5:
			NoteNameRenderF(i,j,255);
			break;
		case 6:
			NoteNameRenderG(i,j,255);
			break;
		case 7:
			NoteNameRenderH(i,j,255);
			break;
		case 8:
			NoteNameRenderI(i,j,255);
			break;
		case 9:
			NoteNameRenderJ(i,j,255);
			break;
		case 10:
			NoteNameRenderK(i,j,255);
			break;
		case 11:
			NoteNameRenderL(i,j,255);
			break;
	}
}

void MicroButtonsRender()
{
	for(unsigned int j=0;j<SPLIT_COUNT;j++)
	{
		//Note that we are over by 1
		for(unsigned int i=0;i<SPLIT_COUNT+1;i++)
		{
			MicroRedButtonRender(i,j,MicroStates[(VERTICAL_STEP_SIZE*j+i)%NOTE_COUNT]);
		}
	}
}

void LinesRender()
{
	if(SliderValues[SliderPreset][SL_FRET]>0.01) {
        //pick colors
        int fret_color_index = 0;
        if(susiNgPanalo != NULL)
            fret_color_index = 1;
        if(SliderValues[SliderPreset][SL_FRET]<0.25)
            fret_color_index = 2;
        GLfloat r = FretLineColorsRGBA[fret_color_index][0];
        GLfloat g = FretLineColorsRGBA[fret_color_index][1];
        GLfloat b = FretLineColorsRGBA[fret_color_index][2];
        GLfloat a = FretLineColorsRGBA[fret_color_index][3];
        
        //render
		Vertices2Clear();
		for(unsigned int i=0;i<SPLIT_COUNT;i++)
		{
			GLfloat v = -1 + i*2.0/SPLIT_COUNT;
			Vertices2Insert(v,-1,r,g,b,a);
			Vertices2Insert(v, 1,r,g,b,a);
		}
		Vertices2Render(GL_LINES);
	}
}

void TracksRender()
{
    //pick colors
    int fret_color_index = 0;
    if(susiNgPanalo != NULL)
        fret_color_index = 1;
    GLfloat r = TrackLineColorsRGBA[fret_color_index][0];
    GLfloat g = TrackLineColorsRGBA[fret_color_index][1];
    GLfloat b = TrackLineColorsRGBA[fret_color_index][2];
    GLfloat a = TrackLineColorsRGBA[fret_color_index][3];
    
    //render
    Vertices2Clear();
    for(unsigned int i=0;i<SPLIT_COUNT;i++)
    {
        GLfloat v = -1 + i*2.0/SPLIT_COUNT;
        Vertices2Insert(-1,v,r,g,b,a);
        Vertices2Insert(1,v,r,g,b,a);
    }
    Vertices2Render(GL_LINES);
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
		for(unsigned int i=0; i<bufferSamples; i+=2)
		{
			Vertices2Insert(
							l+(r-l)*(1.0*i)/(bufferSamples),
							v + a*bufferData[(i+oscilliscopeCursor)%(bufferSamples)], 
							rd,gr, bl, 200);
		}
		Vertices2Render(GL_LINE_STRIP);	
	}
}

void ControlLockRenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,unsigned int slider)
{
	float rad = 0.015;
	float hmid = (r+l)/2;
	float vmid = (2*t+b)/3;
	
	GLfloat h = 255;
	GLfloat cr = 255;
	GLfloat cg = 255;
	GLfloat cb = 255;

    //draw padlock body
	Vertices2Clear();
    Vertices2Insert(hmid-rad,vmid+rad,cr,cg,cb,h);
    Vertices2Insert(hmid+rad,vmid+rad,cr,cg,cb,h);
    Vertices2Insert(hmid+rad,vmid-rad,cr,cg,cb,h);
    Vertices2Insert(hmid-rad,vmid-rad,cr,cg,cb,h);
    Vertices2Insert(hmid-rad,vmid+rad,cr,cg,cb,h);
    Vertices2Render(GL_LINE_STRIP);
    if(SliderValues[SliderPreset][SL_LOCK] >= SL_LOCK_THRESHOLD)
    {
        // draw locked
        Vertices2Clear();
        Vertices2Insert(hmid-rad + rad/2,vmid+rad,cr,cg,cb,h);
        Vertices2Insert(hmid-rad + rad/2,vmid+rad + rad,cr,cg,cb,h);
        
        Vertices2Insert(hmid-rad + rad/2 + rad/4,vmid+rad + rad + rad/4,cr,cg,cb,h);
        Vertices2Insert(hmid+rad - rad/2 - rad/4,vmid+rad + rad + rad/4,cr,cg,cb,h);
        
        Vertices2Insert(hmid+rad - rad/2,vmid+rad + rad,cr,cg,cb,h);
        Vertices2Insert(hmid+rad - rad/2,vmid+rad,cr,cg,cb,h);
        Vertices2Render(GL_LINE_STRIP);
	}
    else
    {
        // draw unlocked (adds rad/2 to the height)
        Vertices2Clear();
        Vertices2Insert(hmid-rad + rad/2,vmid+rad +rad/2,cr,cg,cb,h);
        Vertices2Insert(hmid-rad + rad/2,vmid+rad + rad+rad/2,cr,cg,cb,h);
        
        Vertices2Insert(hmid-rad + rad/2 + rad/4,vmid+rad + rad +rad/2+ rad/4,cr,cg,cb,h);
        Vertices2Insert(hmid+rad - rad/2 - rad/4,vmid+rad + rad +rad/2+ rad/4,cr,cg,cb,h);
        
        Vertices2Insert(hmid+rad - rad/2,vmid+rad + rad+rad/2,cr,cg,cb,h);
        Vertices2Insert(hmid+rad - rad/2,vmid+rad,cr,cg,cb,h);
        Vertices2Render(GL_LINE_STRIP);
    }
	if((tickCounter % 128) < 64 && SliderValues[SliderPreset][SL_LOCK] >= SL_LOCK_THRESHOLD)
	{
        //draw blinking x
		Vertices2Clear();
		Vertices2Insert(hmid-rad/2,vmid-rad/2,PadlockXColorRGB[0],PadlockXColorRGB[1],PadlockXColorRGB[2],h);
		Vertices2Insert(hmid+rad/2,vmid+rad/2,PadlockXColorRGB[0],PadlockXColorRGB[1],PadlockXColorRGB[2],h);
		Vertices2Render(GL_LINE_STRIP);
		Vertices2Clear();
		Vertices2Insert(hmid+rad/2,vmid-rad/2,PadlockXColorRGB[0],PadlockXColorRGB[1],PadlockXColorRGB[2],h);
		Vertices2Insert(hmid-rad/2,vmid+rad/2,PadlockXColorRGB[0],PadlockXColorRGB[1],PadlockXColorRGB[2],h);
		Vertices2Render(GL_LINE_STRIP);
	}
}

void ControlFeedbackSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,unsigned int slider)
{
	GLfloat v = (2*t+b)/3;
	//GLfloat a = (t-b);
	GLfloat n = 12;
	float invN = 1.0/12;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(
						l+(r-l)*i*invN,
						v -0.025 * (1-(1.0*i)*invN), 
						255,255, 255, 
						(1-1.0*i*invN)*255
						);
		Vertices2Insert(
						l+(r-l)*i/n,
						v +0.025 * (1-(1.0*i)*invN), 
						255,255, 255, 
						(1-1.0*i*invN)*255
						);
	}
	Vertices2Render(GL_LINES);	
}

void ControlPresetRenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,unsigned int slider)
{
	GLfloat v = (2*t+b)/3;
	//GLfloat a = (t-b);
	GLfloat n = NUM_PRESETS;
	float invN = 1.0/NUM_PRESETS;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(
						l+(r-l)*i*invN,
						v -0.01, 
						255,255, 255, 
						i*invN*255
						);
		Vertices2Insert(
						l+(r-l)*i*invN,
						v +0.01, 
						255,255, 255, 
						i*invN*255
						);
	}
	Vertices2Render(GL_LINES);	
}

void ControlSnapRenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,unsigned int slider)
{
	GLfloat v = (2*t+b)/3;
	//GLfloat a = (t-b);
	GLfloat n = 12;
	float invN = 1.0/12;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(
			l+(r-l)*i*invN,
			v -0.01 * (1 + (i==3 || (i==10))*2), 
			255,255, 255, 
			i*invN*255
		);
		Vertices2Insert(
			l+(r-l)*i*invN,
			v +0.01 * (1 + (i==3 || (i==10))*2), 
			255,255, 255, 
			i*invN*255
		);
	}
	Vertices2Render(GL_LINES);	
}

void DrawNote(float x,float y)
{
	float d = 0.006;
	//Draw empty line to where we need to be first
	Vertices2Insert(x,y,255,255, 255,0);
	Vertices2Insert(x-d,y,255,255, 255,255);
	Vertices2Insert(x,y-d,255,255, 255,255);
	Vertices2Insert(x+d,y,255,255, 255,255);
	Vertices2Insert(x,y+d,255,255, 255,255);
	Vertices2Insert(x-d,y,255,255, 255,255);
	Vertices2Insert(x-d,y-6*d,255,255, 255,255);
}

void DrawPolyButton(float x, float y, bool active)
{
	float d = 0.008;
    float t = (active?255:64); //note transparency
	Vertices2Clear();
	Vertices2Insert(x-d,y+d,255,255, 255,t);
	Vertices2Insert(x+d,y+d,255,255, 255,t);
	Vertices2Insert(x-d,y-d,255,255, 255,t);
	Vertices2Insert(x+d,y-d,255,255, 255,t);    
	Vertices2Render(GL_TRIANGLE_STRIP);	    
}

void ControlPolyRenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,unsigned int slider)
{
	GLfloat v = (2*t+b)/3;
    GLfloat div_height = 0.04;
	Vertices2Clear();
	//33% line
	Vertices2Insert(
					l+(r-l)*SL_POLY_1_THRESHOLD,
					v -div_height, 
					255,255, 255, 
					255
					);
	Vertices2Insert(
					l+(r-l)*SL_POLY_1_THRESHOLD,
					v +div_height, 
					255,255, 255, 
					255
					);
	Vertices2Insert(l+(r-l)*SL_POLY_1_THRESHOLD,v +0.02,255,255, 255,0);
	Vertices2Insert(l+(r-l)*SL_POLY_2_THRESHOLD,v -0.02,255,255, 255,0);
	//66% line
	Vertices2Insert(
					l+(r-l)*SL_POLY_2_THRESHOLD,
					v -div_height, 
					255,255, 255, 
					255
					);
	Vertices2Insert(
					l+(r-l)*SL_POLY_2_THRESHOLD,
					v +div_height, 
					255,255, 255, 
					255
					);
	Vertices2Render(GL_LINE_STRIP);
	Vertices2Clear();
    Vertices2Insert(l+(r-l)*0.0,v,255,255, 255,255);
    Vertices2Insert(l+(r-l)*1.0,v,255,255, 255,255);
    Vertices2Render(GL_LINE_STRIP);
	
    bool isMultiString = SliderValues[SliderPreset][SL_POLY] >= SL_POLY_1_THRESHOLD;
    bool isFullPoly    = SliderValues[SliderPreset][SL_POLY] >= SL_POLY_2_THRESHOLD;

	DrawPolyButton(l+(r-l)*0.167, v-0.02, true);           // always at lest solo voice
	DrawPolyButton(l+(r-l)*0.5,   v+0.021, isMultiString); // show if multi-string is active
	DrawPolyButton(l+(r-l)*0.833, v-0.02, isFullPoly);     // show if full polyphony is active
	
}

void ControlFMDistortionSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b,GLfloat scale,unsigned int slider)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	float invN = 1.0/60;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i*invN,v + 0.1*a*sinf(200*((i+tickCounter)*invN)+SliderValues[SliderPreset][6]*8*cosf( scale*tickCounter/10.0)), 255,255, 255, i*invN*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}


void ControlFifthsRenderSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	float invN = 1.0/60;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i*invN,v + 0.1*a*sinf(M_PI*3*10.0*((i+tickCounter)*invN)), 255,255, 255, i*invN*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i*invN,v + 0.2*a*sinf(M_PI*10.0*((i+tickCounter)*invN)), 255,255, 255, i*invN*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}

void ControlOctaveSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	float invN = 1.0/60;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i*invN,v + 0.1*a*sinf(M_PI*20.0*((i+tickCounter)*invN)), 255,255, 255, i*invN*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i*invN,v + 0.2*a*sinf(M_PI*10.0*((i+tickCounter)*invN)), 255,255, 255, i*invN*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}

void ControlReverbSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
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
	
void ControlEchoPeriodSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	unsigned int echoLocation = ((totalSamples + stride - (timeTapStart%stride)) % stride);
	//unsigned int echoLocation = ((totalSamples + stride) % stride);
	float p = ((unsigned int)(echoLocation > stride/2)) * 255 * SliderValues[SliderPreset][6];
	Vertices2Clear();
	Vertices2Insert(l,t, 255,255, 255, p);
	Vertices2Insert(r,t, 255,255, 255, p);
	Vertices2Insert(l,b, 255,255, 255, p);
	Vertices2Insert(r,b, 255,255, 255, p);
	Vertices2Render(GL_TRIANGLE_STRIP);		
}

void ControlVolumeSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	GLfloat v = (2*t+b)/3;
	GLfloat a = (t-b);
	GLfloat n = 60;
	float invN = 1.0/60;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i*invN,v + 0.1*a*sinf(M_PI*8.0*((i+tickCounter)*invN)), 255,255, 255, i*invN*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}

static inline float sign(float x)
{
	return (x<=0) ? -1 : 1;
}

void ControlDistortionSkin(GLfloat l,GLfloat r,GLfloat t,GLfloat b)
{
	const GLfloat v = (2*t+b)/3;
	const GLfloat a = (t-b);
	const GLfloat n = 60;
	const float invN = 1.0/60;
	Vertices2Clear();
	for(unsigned int i=0; i<n; i++)
	{
		Vertices2Insert(l+(r-l)*i*invN,v + 0.1*a*sign(sinf(M_PI*8.0*((i+tickCounter)*invN))), 255,255, 255, i*invN*255);
	}
	Vertices2Render(GL_LINE_STRIP);	
}
					
void ControlRender()
{
	GLfloat t = -1 + 2.0/SPLIT_COUNT;
	GLfloat b = -1;
	GLfloat a = (t-b);
	
	GLfloat v = (2*t+b)/3;
	
	GLfloat begin = -1;
	GLfloat end = 1;
	for(unsigned int slider=0; slider < SLIDER_COUNT; slider++)
	{
		GLfloat sl = begin + slider * (end-begin) / SLIDER_COUNT;       //  left border of slider
		GLfloat sr = begin + (slider+1) * (end-begin) / SLIDER_COUNT;   // right border of slider
		GLfloat sv = sl + SliderValues[SliderPreset][slider]*(sr-sl);   // location of slider value
		
		GLfloat cr = 0;
		GLfloat cg = 0;
		GLfloat cb = 0;
        
        cr = SliderColors[slider][0];
        cg = SliderColors[slider][1];
        cb = SliderColors[slider][2];

		int isLocked = (SliderValues[SliderPreset][SL_LOCK] > 0.5);
		if(isLocked && slider < 10)
		{
			cr = 150;
			cg = 150;
			cb = 150;
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
		
		if(slider != SL_ECHOPERIOD)
		{
			Vertices2Clear();
			Vertices2Insert(sl,v+a*0.27, cr,cg, cb, 255);
			Vertices2Insert(sv,v+a*0.27, cr,cg, cb, 255);
			Vertices2Insert(sl,v-a*0.27, cr*0.5*0.5,cg*0.5*0.5, cb*0.5*0.5, 255);	
			Vertices2Insert(sv,v-a*0.27, cr*0.25*0.5,cg*0.25*0.5, cb*0.25*0.5, 255);	
			Vertices2Render(GL_TRIANGLE_STRIP);	
		}
		
		switch(slider)
		{
			case SL_MVOL: ControlVolumeSkin(sl,sr,t,b); break;
			case SL_REVERB: ControlReverbSkin(sl,sr,t,b); break;
			case SL_ATANDIST: ControlDistortionSkin(sl,sr,t,b); break;
			case SL_OCTAVE: ControlOctaveSkin(sl,sr,t,b); break;
			case SL_FMDIST: ControlFMDistortionSkin(sl,sr,t,b,0.25,5); break;
			case SL_ECHOPERIOD: ControlEchoPeriodSkin(sl,sr,t,b); break;
			case SL_ECHOFEEDBACK: ControlFeedbackSkin(sl,sr,t,b,1.0,7); break;
			case SL_ECHOVOL: ControlVolumeSkin(sl,sr,t,b); break;
			case SL_FRET: ControlSnapRenderSkin(sl,sr,t,b,1.0,7); break;
			case SL_POLY: ControlPolyRenderSkin(sl,sr,t,b,1.0,7); break;
			case SL_PRESET: ControlPresetRenderSkin(sl,sr,t,b,1.0,7); break;
			case SL_LOCK: ControlLockRenderSkin(sl,sr,t,b,1.0,7); break;
			//default:
				//TODO
		}
	}
}





void FingerControl(unsigned int touchIndex, float i,float j)
{
	//Slidercontrol spans 5 slots
	float sliderf = 1.0*SLIDER_COUNT*i/SLIDER_COUNT;
	//int slider = (int)sliderf;
	int slider = currentControl;
	float v = sliderf - slider;
	if(v < 0.0)
	{
		v = 0.0;
	}
	if(v > 1.0)
	{
		v = 1.0;
	}
	if(slider == activeControl[touchIndex] && slider != SL_ECHOPERIOD)
	{
		SetValueForFingerControl(slider,v,FALSE);
	}
}

void FingerRenderLines(CGPoint p,unsigned int touchIndex)
{
	CGFloat py=p.y;
	GLfloat x = (0.5-p.x*inverseBackingWidth)*2;
	GLfloat y = (0.5-py*inverseBackingHeight)*2;
	
	Vertices2Clear();	
	GLfloat d = 1.25/SPLIT_COUNT;
	GLfloat l = d - x;
	GLfloat t = d + y;
	GLfloat r = -d - x;
	GLfloat b = -d + y;
/*	float rd = 255;
	float gr = 255;
	float bl = 255;*/
	//rd = touchIsMaxNote[touchIndex] ? 0 : 255;
/*	   
	Vertices2Insert(l,(t+b)/2, rd, gr, bl, FINGER_A);
	Vertices2Insert(r,(t+b)/2, rd, gr, bl, FINGER_A);
	Vertices2Insert((l+r)/2,t, rd, gr, bl, FINGER_A);
	Vertices2Insert((l+r)/2,b, rd, gr, bl, FINGER_A);
	Vertices2Render(GL_LINES);
*/
	float j = SPLIT_COUNT-(1.0*SPLIT_COUNT * py)*inverseBackingHeight;
    float i = (SPLIT_COUNT * p.x)*inverseBackingWidth;
	GLfloat flat = 127 + 127 * cosf((i)*2*M_PI);     //255*(i-((int)(i+0.5)));
	GLfloat sharp = 127 + 127 * cosf((i+0.5)*2*M_PI);//*(((int)(i))-i);
	GLfloat harm = 127 + 127 * cosf((j)*2*M_PI);     //*(((int)(i))-i);

	Vertices2Insert(l,(t+b)/2, flat, sharp, harm, FINGER_A);
	Vertices2Insert(r,(t+b)/2, flat, sharp, harm, FINGER_A);
	Vertices2Insert((l+r)/2,t, flat, sharp, harm, FINGER_A);
	Vertices2Insert((l+r)/2,b, flat, sharp, harm, FINGER_A);
	Vertices2Render(GL_LINES);

}

void FingerRenderRaw2(float i,float j,GLfloat x,GLfloat y,CGFloat cx,CGFloat cy, CGFloat px,CGFloat py, bool cActive, bool pActive)
{
	
	GLfloat d = 1.0/SPLIT_COUNT;
	GLfloat l =  d - x;
	GLfloat t =  d + y;
	GLfloat r = -d - x;
	GLfloat b = -d + y;
//	GLfloat flat  = 127 + 127 * cosf((i)*2*M_PI);     //255*(i-((int)(i+0.5)));
//	GLfloat sharp = 127 + 127 * cosf((i+0.5)*2*M_PI); //*(((int)(i))-i);
//	GLfloat harm  = 127 + 127 * cosf((j)*2*M_PI);     //*(((int)(i))-i);
    GLfloat c_flat  = 255.0*cActive;
    GLfloat c_sharp = 255.0*cActive;
    GLfloat c_harm  = 255.0*cActive;
    GLfloat p_flat  = 255.0*pActive;
    GLfloat p_sharp = 255.0*pActive;
    GLfloat p_harm  = 255.0*pActive;
//	Vertices2Insert(l,t, flat, sharp, harm, FINGER_A);
//	Vertices2Insert(r,t, flat, sharp, harm, FINGER_A);
//	Vertices2Insert(l,b, flat, sharp, harm, FINGER_A);
//	Vertices2Insert(r,b, flat, sharp, harm, FINGER_A);
    //if the previous point is off in slider land, then use current point instead;
    if ((SPLIT_COUNT-(1.0*SPLIT_COUNT * py)*inverseBackingHeight) <1)
    {
        px = cx;
        py = cy;
    }
    GLfloat prx = (0.5-px*inverseBackingWidth)*-2.0;
	GLfloat pry = (0.5-py*inverseBackingHeight)*2.0;

    Vertices2Clear();
	Vertices2Insert(l,t, c_flat, c_sharp, c_harm, FINGER_A/2.0);
	Vertices2Insert(r,t, c_flat, c_sharp, c_harm, FINGER_A/2.0);
	Vertices2Insert(l,b, c_flat, c_sharp, c_harm, FINGER_A/2.0);
	Vertices2Insert(r,b, c_flat, c_sharp, c_harm, FINGER_A/2.0);
	Vertices2Render(GL_TRIANGLE_STRIP);
    Vertices2Clear();
	Vertices2Insert(prx,pry, p_flat, p_sharp, p_harm, FINGER_A/4.0);
	Vertices2Insert(l,t, c_flat, c_sharp, c_harm, FINGER_A/4.0);
	Vertices2Insert(r,b, c_flat, c_sharp, c_harm, FINGER_A/4.0);
	Vertices2Render(GL_TRIANGLE_STRIP);
    Vertices2Clear();
	Vertices2Insert(prx,pry, p_flat, p_sharp, p_harm, FINGER_A/4.0);
	Vertices2Insert(r,t, c_flat, c_sharp, c_harm, FINGER_A/4.0);
	Vertices2Insert(l,b, c_flat, c_sharp, c_harm, FINGER_A/4.0);
	Vertices2Render(GL_TRIANGLE_STRIP);
}

void AdjustmentCheck()
{
	if(currentControl >= 0)
	{
		switch(adjustmentProgress)
		{
			case 8:
			{
				if(currentControl == 3)adjustmentProgress--;
				break;
			}
				
			case 1:
			{
				if(currentControl==4)
				{
					makeAdjustments();
					adjustmentProgress = 8;
				}
				else 
				{
					adjustmentProgress=8;
				}	
				break;
			}
				
			case 2:	
			{
				adjustmentProgress = (currentControl==4) ? 1 : 8;
				break;
			}
				
			case 3:
			{
				adjustmentProgress = (currentControl==3) ? 2 : 8;
				break;
			}
				
			case 4:
			{
				adjustmentProgress = (currentControl==4) ? 3 : 8;
				break;
			}
				
			case 5:	
			{
				adjustmentProgress = (currentControl==3) ? 4 : 8;
				break;
			}
				
			case 6:	
			{
				adjustmentProgress = (currentControl==3) ? 5 : 8;
				break;
			}
				
			case 7:
			{
				adjustmentProgress = (currentControl==4) ? 6 : 8;
				break;
			}			
		}
	}
}

void TempoTrack()
{
	//Can only tap if unlocked!
	if(currentControl == SL_ECHOPERIOD)
	{
		if(SliderValues[SliderPreset][SL_LOCK] < SL_LOCK_THRESHOLD)
		{
			for(unsigned int touchIndex=0; touchIndex < FINGERS; touchIndex++)
			{
				if(FindTouchByIndex(touchIndex)!=NULL)
				{
					if(activeControl[touchIndex] == SL_ECHOPERIOD)
					{
						unsigned int diff = totalSamples - timeTapStart;
						{
							timeTapStart = totalSamples;
							if(diff < ECHOSIZE)
							{
								SliderValues[SliderPreset][SL_ECHOPERIOD] = (1.0 * diff)/ECHOSIZE;
								SyncWithPreset(SliderPreset);
							}
						}
					}
				}
			}
		}
	}
}

void FingerRenderRaw(CGPoint p, CGPoint c, unsigned int touchIndex, unsigned int lastTouchIndex)
{
    if (FindTouchByIndex(lastTouchIndex)==NULL)
    {
        p = c;
    }
	CGFloat px=p.x;
	CGFloat py=p.y;
	CGFloat cx=c.x+SnapAdjustH[touchIndex];
	CGFloat cy=c.y;
	GLfloat x = (0.5-cx*inverseBackingWidth)*2;
	GLfloat y = (0.5-cy*inverseBackingHeight)*2;
	float jfl = SPLIT_COUNT-(1.0*SPLIT_COUNT * cy)*inverseBackingHeight;
	float j = (int)jfl;
	if(j<1)
	{
        UITouchPhase phase = FindPhaseByIndex(touchIndex);
        if(phase==UITouchPhaseMoved)
        {
            float i = (SLIDER_COUNT * c.x)*inverseBackingWidth;
            FingerControl(touchIndex,i,jfl);
        }	
	}
	else 
	{
		float i = (SPLIT_COUNT * cx)*inverseBackingWidth;
		FingerRenderRaw2(i,jfl,x,y,cx,cy,px, py, touchIsMaxNote[touchIndex], touchIsMaxNote[lastTouchIndex]);
	}
}

void FingersRenderAllLines()
{
	for(unsigned int touchIndex=0; touchIndex < FINGERS; touchIndex++)
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
    unsigned int lastTouchIndex = FINGERS-1;
    CGPoint lastPoint = FindPointByIndex(lastTouchIndex);

	for(unsigned int touchIndex=0; touchIndex < FINGERS; touchIndex++)
	{
		UITouch* touch = FindTouchByIndex(touchIndex);
		if(touch != NULL)
		{
            CGPoint currentPoint = FindPointByIndex(touchIndex);
			
            FingerRenderRaw(lastPoint, currentPoint, touchIndex, lastTouchIndex);
            lastPoint = currentPoint;
		}
	}
}

void GradientRender(void)
{
    Vertices2Clear();
    GLfloat l = -1.0;
    GLfloat r =  1.0;
    GLfloat t =  1.0;
    GLfloat m =  1.0/SPLIT_COUNT;
    GLfloat b = -1.0*(SPLIT_COUNT-2)/SPLIT_COUNT;
    GLfloat cr = GradientColors[0];
    GLfloat cg = GradientColors[1];
    GLfloat cb = GradientColors[2];
    GLfloat ca = GradientColors[4];
    Vertices2Insert(l,t,cr*GRADIENT_FADE,cg*GRADIENT_FADE,cb*GRADIENT_FADE,ca);
	Vertices2Insert(r,t,cr,cg,cb,ca);
	Vertices2Insert(l,m,cr,cg,cb,ca);
	Vertices2Insert(r,m,cr,cg,cb,ca);
	Vertices2Insert(l,m,cr,cg,cb,ca);
	Vertices2Insert(r,m,cr,cg,cb,ca);
	Vertices2Insert(l,b,cr,cg,cb,ca);
	Vertices2Insert(r,b,cr*GRADIENT_FADE,cg*GRADIENT_FADE,cb*GRADIENT_FADE,ca);	
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
		
		somethingChanged = true;
		TouchesInit();
		ButtonStatesInit();
		
		sound = [AudioOutput alloc];
		lastAudio = sound;
		[sound init];
		[sound start];
		ButtonsTrack();
		
		//	makeAdjustments();
		ReadPreferences();
    }
	
	
    return self;
}

- (void)render
{	
	tickCounter++;
	[EAGLContext setCurrentContext:context];
	
	glViewport(0, 0, backingWidth,backingHeight);
	
	glUseProgram(program);
    GradientRender();
	ButtonsRender();
    TracksRender();
	LinesRender();
	MicroButtonsRender();	
	ControlRender();
	FingersRender(true);
	FingersRenderAllLines();
	PresetRender();
	ButtonsTrack(); //wrong!
	FadeNotes();
	
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
	inverseBackingWidth = 1.0/backingWidth;
	inverseBackingHeight = 1.0/backingHeight;
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
	int touchCount = [touches count];
	for(unsigned int t=0; t < touchCount; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		UITouchPhase phase = [touch phase];
		if(phase==UITouchPhaseBegan)
		{
			BeginIndexByTouch(touch,v,t);
		}
	}
	ButtonsTrack();
	if(currentControl >= 0)
	{
		AdjustmentCheck();
		TempoTrack();
	}
}


- (void)touchesMoved:(NSSet*)touches atView:(UIView*)v
{
	NSArray* touchArray = [touches allObjects];
	int touchCount = [touches count];
	for(unsigned int t=0; t < touchCount; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		UITouchPhase phase = [touch phase];
		if(phase==UITouchPhaseMoved)
		{
			MoveIndexByTouch(touch,v,t);
		}
		else
		if(phase==UITouchPhaseEnded || phase==UITouchPhaseCancelled)
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
	for(unsigned int t=0; t < touchCount; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		UITouchPhase phase = [touch phase];
		if(phase==UITouchPhaseEnded)
		{
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
		else
		if(phase==UITouchPhaseCancelled)
		{
			deadTouches++;
			int touchIndex = FindIndexByTouch(touch,t);
			if(touchIndex >= 0)
			{
				DeleteTouchByIndex(touchIndex,t);
			}
		}
	}
	if(touchCount == deadTouches)
	{
		for(unsigned int t=0; t < FINGERS; t++)
		{
			DeleteTouchByIndex(t,t);
			[lastAudio setVol:0.0 forFinger:t];
		}
	}
	//ButtonsTrack();
	[self render];
}


- (void)touchesCancelled:(NSSet*)touches atView:(UIView*)v
{
	NSArray* touchArray = [touches allObjects];
	int touchCount = [touches count];
	for(unsigned int t=0; t < touchCount; t++)
	{
		UITouch* touch = [touchArray objectAtIndex:t];
		UITouchPhase phase = [touch phase];
		if(phase==UITouchPhaseEnded || phase==UITouchPhaseCancelled)
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
