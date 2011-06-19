#import "AudioOutput.h"
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioOutputUnit.h>
#import <AudioToolbox/AudioServices.h>

//vol x 2, lpf 0.75 -> 0.50
@implementation AudioOutput


//#define UPPERLIMIT (214748367-10)
#define MAX_AUDIO_VALUE (1<<24)
#define OVERALL_GAIN 4.0
//#define LPFAMT 0.5
//.75
//.75

//static unsigned int reverb_size = REVERBSIZE;
static float gainp=0.5;
static float reverbp=0.0;
static float reverbpTarget=0.5;
static float masterp=0.0;
static float masterpTarget=0.5;
static float powerp=0.0;
static float powerpTarget=0.5;
static float currentFM1=0.5;
static float targetFM1=0.5;
static float delayFeedback=0.5;
static float delayVolume=0.0;
static float delayVolumeTarget=0.5;

static const float kSampleRate = 44100.0;
static const unsigned int kOutputBus = 0;

static float lastTotal[FINGERS];
static float angle[FINGERS];

static float reverbBufferL[REVERBSIZE];
static float reverbBufferR[REVERBSIZE];

static float echoBufferL[ECHOSIZE];
static float echoBufferR[ECHOSIZE];

static float targetHarmonicPercentage[FINGERS];
static float lastHarmonicPercentage[FINGERS];

static int attack[FINGERS];
static float pitch[FINGERS];
static float targetPitch[FINGERS];

static float targetVol[FINGERS];
static float currentVol[FINGERS];
static float targetPan[FINGERS];
static float currentPan[FINGERS];

static BOOL soundEnginePaused = NO;

#define sinFast sinf 

static inline SInt32 limiter(float x)
{
//	return UPPERLIMIT*atanf(x)/(M_PI/2);
    return 2.0* MAX_AUDIO_VALUE *atanf(x)/M_PI;
}

static OSStatus fixGDLatency()
{
	float latency = 0.005;
	
	OSStatus 
	status = AudioSessionSetProperty(
											  kAudioSessionProperty_PreferredHardwareIOBufferDuration,
											  sizeof(latency),&latency
											  );
	UInt32 allowMixing = true;
	status = AudioSessionSetProperty(
											  kAudioSessionProperty_OverrideCategoryMixWithOthers,
											  sizeof(allowMixing),&allowMixing
											  );
	
	
	/*
	AudioStreamBasicDescription auFmt;
	UInt32 auFmtSize = sizeof(AudioStreamBasicDescription);	
	AudioUnitGetProperty(audioUnit,
						 kAudioUnitProperty_StreamFormat,
						 kAudioUnitScope_Output,
						 kOutputBus,
						 &auFmt,
						 &auFmtSize);
	*/
	//NSLog(@"Samples: %d,%f  %fms",bufferSamples,auFmt.mSampleRate, bufferSamples*1000/auFmt.mSampleRate);
	return status;
}

static void reverbN(int r,float vL,float vR)
{
	const float di = 0.5;
	const float d = 0.95;
	const float d0 = di*d;
	const float d1 = d0*d;
	const float d2 = d1*d;
	const float d3 = d2*d;
	const float d4 = d3*d;
	const float d5 = d4*d;
	const float d6 = d5*d;
	const float d7 = d6*d;
	const float d8 = d7*d;
	unsigned int a;
	unsigned int b;
	unsigned int c;
	unsigned int e;
	float newvL;
	float newvR;

	a = (r+9362)%REVERBSIZE;
	b = (r+5957)%REVERBSIZE;
	c = (r+3855)%REVERBSIZE;
	e = (r+2849)%REVERBSIZE;
	newvL = d0*vL;
	newvR = d0*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+2*9362)%REVERBSIZE;
	b = (r+2*5957)%REVERBSIZE;
	c = (r+2*3855)%REVERBSIZE;
	e = (r+2*2849)%REVERBSIZE;
	newvL = d1*vL;
	newvR = d1*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+3*9362)%REVERBSIZE;
	b = (r+3*5957)%REVERBSIZE;
	c = (r+3*3855)%REVERBSIZE;
	e = (r+3*2849)%REVERBSIZE;
	newvL = d2*vL;
	newvR = d2*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+4*9362)%REVERBSIZE;
	b = (r+4*5957)%REVERBSIZE;
	c = (r+4*3855)%REVERBSIZE;
	e = (r+4*2849)%REVERBSIZE;
	newvL = d3*vL;
	newvR = d3*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+5*9362)%REVERBSIZE;
	b = (r+5*5957)%REVERBSIZE;
	c = (r+5*3855)%REVERBSIZE;
	e = (r+5*2849)%REVERBSIZE;
	newvL = d4*vL;
	newvR = d4*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+6*9362)%REVERBSIZE;
	b = (r+6*5957)%REVERBSIZE;
	c = (r+6*3855)%REVERBSIZE;
	e = (r+6*2849)%REVERBSIZE;
	newvL = d5*vL;
	newvR = d5*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+7*5957)%REVERBSIZE;
	b = (r+7*3855)%REVERBSIZE;
	c = (r+7*3449)%REVERBSIZE;
	e = (r+7*2849)%REVERBSIZE;
	newvL = d6*vL;
	newvR = d6*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+8*5957)%REVERBSIZE;
	b = (r+8*3855)%REVERBSIZE;
	c = (r+8*3449)%REVERBSIZE;
	e = (r+8*2849)%REVERBSIZE;
	newvL = d7*vL;
	newvR = d7*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
	a = (r+9*5957)%REVERBSIZE;
	b = (r+9*3855)%REVERBSIZE;
	c = (r+9*3449)%REVERBSIZE;
	e = (r+9*2849)%REVERBSIZE;
	newvL = d8*vL;
	newvR = d8*vR;
	reverbBufferL[a] += newvL;
	reverbBufferR[b] += newvR;
	reverbBufferL[c] += newvR;
	reverbBufferR[e] += newvL;
}


static inline void makeNoiseInit(SInt32* dataL,SInt32* dataR,unsigned int samples)
{
	for (unsigned int i = 0; i < samples; ++i) {
		bufferL[i] = 0;
		bufferR[i] = 0;
		dataL[i] = 0;
		dataR[i] = 0;
	}
}

static inline void makeNoisePerFinger(SInt32* dataL,SInt32* dataR,unsigned int samples,float isamples,unsigned int finger)
{
	if(currentVol[finger] > 0.001 || targetVol[finger] > 0.001)
	{
		if(currentVol[finger] < 0.001)
		{
			pitch[finger] = targetPitch[finger];
			angle[finger] = 0;
		}		
		int goingUp = (targetVol[finger] > currentVol[finger]);
		float vrate = 0.999 - 0.002 * goingUp*(8*gainp+0.25*(powerp+currentFM1));
		
		float harmBaseFactor = (1-powerp/2);
		float volf = currentVol[finger];
		float panf = currentPan[finger];
		float pitchf = pitch[finger];
		float volt = targetVol[finger];
		float harmt = targetHarmonicPercentage[finger];
		float pitcht = targetPitch[finger];
		float pant = targetPan[finger];
		float anglef = angle[finger];
		float harmf = lastHarmonicPercentage[finger];
		float a = 0;
		
		float sampleAdjust = samples / 1024.0;
		//float progress = pitchf/samples;
		for (unsigned int i = 0; i < samples; ++i) 
		{	
			a = i*pitchf*isamples + anglef;
			a *= sampleAdjust;
			
			float harml = (1-harmf);
			float harmUpFactor = 2*powerp*harmf;
			float harmDownFactor = powerp*harml;
			
			float total = 0;			
			float fm = volf*M_PI*currentFM1*sinFast(a*2);
			total += volf*sinFast( fm+a   ) * harmBaseFactor;
			total += volf*sinFast( fm+2*a ) * harmUpFactor;					
			total += volf*sinFast( fm+a/2 ) * harmDownFactor;
			
			//float finalValue = (lastTotal[finger]+total)/2;
			
			bufferL[i] += total * panf;
			bufferR[i] += total * (1-panf);
			
			//lastTotal[finger] = total;
			
			volf   = vrate*volf + (1-vrate)*volt; 
			harmf  = 0.995*harmf   + 0.005*harmt;
			panf   = 0.99995*panf  + 0.00005*pant;
			pitchf = 0.995*pitchf  + 0.005*pitcht;		
		}
		
		angle[finger] += pitchf;
		while (angle[finger] > 2048*M_PI)
		{
			angle[finger] -= 2048*M_PI;
		}
		
		//None of these moves should take more than 1024 samples
		lastHarmonicPercentage[finger] = harmf;
		currentVol[finger] = volf;
		currentPan[finger] = panf;
		pitch[finger] = pitchf; 
	}
}

static inline void makeNoisePostProcessing(SInt32* dataL,SInt32* dataR,unsigned short samples)
{
	//1.8
	float lp0 = 0.9872585; //4throot of 0.99
	float unLp0 = 1-lp0;
	currentFM1 = unLp0*targetFM1 + lp0*currentFM1;
	float unG = (1-gainp);
	
	float halfReverbp = reverbp*0.5;
	//If reverb is low, then turn it off for performance (ie: external recording)
	for (unsigned int i = 0; i < samples; ++i) 
	{
		unsigned int rBufferIndex  = (i+totalSamples)%REVERBSIZE;
		unsigned int rBufferIndex2 = (i+totalSamples+1)%REVERBSIZE;
		unsigned int eBufferIndex  = (i+totalSamples)%stride;
		
		float bL = bufferL[i];
		float bR = bufferR[i];
//		float sL = (unG*bL+gainp*atanf(100*gainp*bL))/40;
//		float sR = (unG*bR+gainp*atanf(100*gainp*bR))/40;
		float sL = (unG*bL*20+gainp*atanf(100*gainp*bL))/(20+20*unG);
		float sR = (unG*bR*20+gainp*atanf(100*gainp*bR))/(20+20*unG);
		float eL = 0;
		float eR = 0;
		float rL = 0;
		float rR = 0;
		
		if(delayVolume > 0)
		{
			echoBufferL[eBufferIndex] *= delayFeedback;
			eL = echoBufferR[eBufferIndex]*delayVolume;
			echoBufferL[eBufferIndex] += sL;
	
			echoBufferR[eBufferIndex] *= delayFeedback;
			eR = echoBufferL[eBufferIndex]*delayVolume;
			echoBufferR[eBufferIndex] += sR;
		}
		
		if(reverbp > 0)
		{
			
			rL = (reverbBufferR[rBufferIndex] + reverbBufferR[rBufferIndex2])
					* halfReverbp;
			rR = (reverbBufferL[rBufferIndex] + reverbBufferL[rBufferIndex2])
					* halfReverbp;

			reverbN(rBufferIndex,
					sL*0.75 + bL*0.0125 + 0.25*eL + 0.111*rL,
					sR*0.75 + bR*0.0125 + 0.25*eR + 0.111*rR
            );
			
			reverbBufferL[rBufferIndex] =0;
			reverbBufferR[rBufferIndex] =0;
		}
		
		
		dataL[i] = limiter(
//						   masterp*(sL + rL + eL)
						   masterp*OVERALL_GAIN*(sL + rL + eL)
		);
		dataR[i] = limiter(
//						   masterp*(sR + rR + eR)
						   masterp*OVERALL_GAIN*(sR + rR + eR)
		);
	}
	
	masterp = lp0*masterp + unLp0*masterpTarget;
	powerp  = lp0*powerp  + unLp0*powerpTarget;
	reverbp = lp0*reverbp + unLp0*reverbpTarget;
	delayVolume = lp0*delayVolume + unLp0*delayVolumeTarget;
	
	totalSamples += samples;
	totalSamples &= 0xefffffff;
}

static OSStatus makeNoise(AudioBufferList* buffers)
{
	AudioBuffer* outputBufferL = &buffers->mBuffers[0];
	SInt32* dataL = (SInt32*)outputBufferL->mData;
	AudioBuffer* outputBufferR = &buffers->mBuffers[1];
	SInt32* dataR = (SInt32*)outputBufferR->mData;
	
	//Go ahead and do this if we didn't get an oversized buffer for some reason
	unsigned int samples = outputBufferL->mDataByteSize / sizeof(SInt32);
	unsigned int intendedSamples = samples;
	if(samples > 4*1024)
	{
		//Let it skip until buffer size comes back..nothing else we can do
		samples = 4*1024;
	}
	{
		makeNoiseInit(dataL,dataR,samples);
		float isamples = 1.0/samples;
		for(unsigned int finger=0;finger<FINGERS;finger++)
		{
			makeNoisePerFinger(dataL,dataR,samples,isamples,finger);
		}
		
		makeNoisePostProcessing(dataL,dataR,samples);
	}
	
	bool isBufferDifferent = samples != bufferSamples || samples != intendedSamples;
	//Do this because in the background somebody might be reading the echo buffer for data
	bufferSamples = samples;
	if(isBufferDifferent)
	{
		fixGDLatency();
	}	
	
	return 0;
}

static void makeNoiseSetup()
{
	for(unsigned int i=0;i<FINGERS;i++)
	{
		pitch[i] = -1;
		targetPitch[i] = -1;
		currentVol[i] = 0;
		targetVol[i] = 0;
		targetPan[i] = 0;
		lastTotal[i] = 0;
		attack[i] = 0;
	}
	for(unsigned int i=0;i<REVERBSIZE;i++)
	{
		reverbBufferL[i] = 0;
		reverbBufferR[i] = 0;
	}
}

static OSStatus playCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
	assert(inBusNumber == kOutputBus);
	return makeNoise(ioData);
}

- (id)init {
	if ((self = [super init])) {
		makeNoiseSetup();
	}
	return self;
}

// Set Audio Session category
- (BOOL)audioSessionSetCategory:(NSString*)category
{
	NSError *categoryError = nil;
	AVAudioSession *session = [AVAudioSession sharedInstance];
	if (![session setCategory:category error:&categoryError]) 
	{
		//Failed
		NSLog(@"Error setting Audio session category %@: %@", 
			 category, categoryError.localizedDescription);
		return NO;
	}
	
	NSLog(@"Audio session category %@ set successfully", category);
	
	UInt32 allowMixing = true;
	OSStatus result = AudioSessionSetProperty (kAudioSessionProperty_OverrideCategoryMixWithOthers,
											   sizeof (allowMixing), &allowMixing);
	if (result)	
	{
		NSLog(@"ERROR enabling audio mixing: %ld", result);
	}
	
	return YES;
} 

// Set Audio session active or inactive
- (BOOL)audioSessionSetActive:(BOOL)active 
{
	NSError *activationError = nil;
	if ([[AVAudioSession sharedInstance] setActive:active error:&activationError]) 
	{
		NSLog(@"Audio session set active %@ succeeded", active ? @"YES" : @"NO");
		return YES;
	} 
	else 
	{	//Failed
		
		NSLog(@"ERROR setting Audio session active %@: %@", active ? @"YES" : @"NO", 
			 activationError.localizedDescription);
		return NO;
	}
}

// Begin Interruption handler. NOTE: Audio session is already de-activated at this point
- (void)beginInterruption
{	
	if (soundEnginePaused)
	{
		// nothing to do
		NSLog(@"beginInterruption: sound engine already paused, exiting");
		return;
	}
	
    NSLog(@"Audio session interrupted"); 
	
	// Set flag
	soundEnginePaused = YES;
	
	// Do any Audio unit teardown, save state, etc. if needed
}

// Interruption resume handler for iOS4 and later
- (void)endInterruptionWithFlags:(NSUInteger)flags
{			
	if (!soundEnginePaused)		
		return; // nothing to do
	
	// NOTE: The AVAudioSessionInterruptionFlags_ShouldResume indicates whether the app 
	// should resume playback as per the HIG	
	if (flags != AVAudioSessionInterruptionFlags_ShouldResume)
	{
		NSLog(@"AVAudioSessionInterruptionFlags_ShouldResume set to NO");
		// Possible about re-activate here
	}
		
	NSLog(@"Audio session resuming"); 
	
	// Re-activate Audio Session first
	[self audioSessionSetActive:YES];
	
	soundEnginePaused = NO;
}

// Interruption resume handler for iOS 3.x (pre-iOS4)
- (void)endInterruption
{	
	[self endInterruptionWithFlags:AVAudioSessionInterruptionFlags_ShouldResume];
}

- (void) start {
  stride = 1024;
  bufferSamples = 256;
  minimumFrequency = 100000;
  totalSamples = 0;
  OSStatus status;
	
  // Set audio session category and make it active
  [self audioSessionSetCategory:AVAudioSessionCategoryPlayback];
  [self audioSessionSetActive:YES];
	
	// Register observer to be notified when application is suspended
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(beginInterruption) 
												 name:UIApplicationDidEnterBackgroundNotification object:nil];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(endInterruption) 
												 name:UIApplicationDidBecomeActiveNotification object:nil];		
	
  // Describe audio component
  AudioComponentDescription desc;
  desc.componentType = kAudioUnitType_Output;
  desc.componentSubType = kAudioUnitSubType_RemoteIO;
  desc.componentFlags = 0;
  desc.componentFlagsMask = 0;
  desc.componentManufacturer = kAudioUnitManufacturer_Apple;
  
  // Get component
  AudioComponent outputComponent = AudioComponentFindNext(NULL, &desc);
  
  // Get audio units
  status = AudioComponentInstanceNew(outputComponent, &audioUnit);
  if(status)
  {
	  NSLog(@"AudioComponentInstanceNew:%ld",status);
  }
  else 
  {
	  // Enable playback
	  UInt32 enableIO = 1;
	  status = AudioUnitSetProperty(audioUnit,
									kAudioOutputUnitProperty_EnableIO,
									kAudioUnitScope_Output,
									kOutputBus,
									&enableIO,
									sizeof(UInt32));
	  if(status)
	  {
		  NSLog(@"AudioUnitSetProperty EnableIO:%ld",status);
	  }
	  else 
	  {
		  audioFormat.mSampleRate = 44100.0;
		  audioFormat.mFormatID = kAudioFormatLinearPCM;
		  audioFormat.mFormatFlags  = kAudioFormatFlagsAudioUnitCanonical;
		  audioFormat.mBytesPerPacket = sizeof(AudioUnitSampleType);
		  audioFormat.mFramesPerPacket = 1;
		  audioFormat.mBytesPerFrame = sizeof(AudioUnitSampleType);
		  audioFormat.mChannelsPerFrame = 2;
		  audioFormat.mBitsPerChannel = 8 * sizeof(AudioUnitSampleType);
		  audioFormat.mReserved = 0;	
		  // Apply format
		  status = AudioUnitSetProperty(audioUnit,
										kAudioUnitProperty_StreamFormat,
										kAudioUnitScope_Input,
										kOutputBus,
										&audioFormat,
										sizeof(AudioStreamBasicDescription));
		  if(status)
		  {
			  NSLog(@"AudioUnitSetProperty StreamFormat:%ld",status);
		  }
		  else 
		  {
			  UInt32 maxFrames = 1024*4;
			  AudioUnitSetProperty(audioUnit,
											kAudioUnitProperty_MaximumFramesPerSlice,
											kAudioUnitScope_Input,
											kOutputBus,
											&maxFrames,
											sizeof(maxFrames));
			  
			  AURenderCallbackStruct callback;
			  callback.inputProc = &playCallback;
			  callback.inputProcRefCon = self;
			  
			  // Set output callback
			  status = AudioUnitSetProperty(audioUnit,
											kAudioUnitProperty_SetRenderCallback,
											kAudioUnitScope_Global,
											kOutputBus,
											&callback,
											sizeof(AURenderCallbackStruct));
			  if(status)
			  {
				  NSLog(@"AudioUnitSetProperty SetRenderCallback:%ld",status);
			  }
			  else
			  {
				  status = AudioUnitInitialize(audioUnit);
				  if(status)
				  {
					  NSLog(@"AudioUnitInitialize:%ld",status);
				  }
				  else 
				  {
					  status = AudioOutputUnitStart(audioUnit);
					  if(status)
					  {
						  NSLog(@"AudioUnitStart:%ld",status);					  
					  }
				  }				  
			  }
		  }
	  }
  }
}

- (void) dealloc
{
  AudioUnitUninitialize(audioUnit);
  [super dealloc];
}

- (void) setPan:(float)p forFinger:(unsigned int)f;
{
	if(f < FINGERS)
	{
		targetPan[f] = (1-p);
	}
}

- (void) setNote:(float)p forFinger:(unsigned int)f isAttack:(unsigned int)a;
{
	if(f < FINGERS)
	{
		targetPitch[f] = p;
		attack[f] = a;
	}
}

- (void) setVol:(float)p forFinger:(unsigned int)f;
{
	if(f < FINGERS)
	{
		targetVol[f] = p;
	}
}

//Set AFTER pitch is set
- (void) setAttackVol:(float)p forFinger:(unsigned int)f;
{
	if(f < FINGERS)
	{
		currentVol[f] = p;
		pitch[f] = targetPitch[f];
		angle[f] = 0;
	}
}

- (void) setHarmonics:(float)h forFinger:(unsigned int)f;
{
	if(f < FINGERS)
	{
		targetHarmonicPercentage[f] = h;
	}
}

- (void) setGain:(float)g
{
	gainp = g;
}

- (void) setReverb:(float)r
{
	reverbpTarget = r;
}

- (void) setMaster:(float)m
{
	masterpTarget = m;
}

- (void) setPower:(float)w
{
	powerpTarget = w;
}

- (void) setFM1:(float)f
{
	targetFM1 = f;
}

- (void) setDelayTime:(float)f
{
	unsigned int newStride = f*ECHOSIZE;
	//Get rid of junk outside out buffer if we have to increase delay time
	if(newStride > stride)
	{
		for(unsigned int i=stride; i<newStride; i++)
		{
			echoBufferL[i] = 0;
			echoBufferR[i] = 0;
		}
	}
	stride = newStride;
}
- (void) setDelayFeedback:(float)f
{
	delayFeedback = f;
}
- (void) setDelayVolume:(float)f
{
	delayVolumeTarget = f;
}

@end


