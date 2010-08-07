
#import "AudioOutput.h"
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioOutputUnit.h>
#import <AudioToolbox/AudioServices.h>


@implementation AudioOutput

#define UPPERLIMIT (214748367-10)
#define SINBUFFERSIZE 256

static float sinBuffer[SINBUFFERSIZE];
//TODO: replicate this for atan... which can be negative
//static float atanBuffer[SINBUFFERSIZE];

static float gainp=SLIDER2;
static float reverbp=SLIDER1;
static float masterp=SLIDER0;
static float powerp=SLIDER3;
static float fm1 = SLIDER4;
static float fm2 = SLIDER5;
static float fm3 = SLIDER6;
static float fm4 = SLIDER7;
static const float kSampleRate = 44100.0;
static const int kOutputBus = 0;

static float pan[FINGERS];
static float angle[FINGERS];
static float echoBufferL[ECHO_SIZE];
static float echoBufferR[ECHO_SIZE];

static float harmonicPercentage[FINGERS];
static float lastHarmonicPercentage[FINGERS];

static float lastPitch[FINGERS];
static float pitch[FINGERS];
static float targetPitch[FINGERS];
static float targetFM1=SLIDER4;
static float targetFM2=SLIDER5;
static float targetFM4=SLIDER7;

static float targetVol[FINGERS];
static float currentVol[FINGERS];

#define SAMPLESTOSMEAR 4
static float lastNSamplesL[SAMPLESTOSMEAR];
static float lastNSamplesR[SAMPLESTOSMEAR];

//Presume that samples is BUFFER_SIZE.  When would this not be true? ... on to oscilliscope

//must be a positive number!
static inline float sinFast(float n)
{
	return sinBuffer[(unsigned int)(SINBUFFERSIZE*n/(2*M_PI)) % SINBUFFERSIZE];
}

static inline int echoN(int i,float vL,float vR)
{
	float di = 0.25;
	float d = 0.95;
	unsigned int r = (i+totalSamples)%ECHO_SIZE;
	float p = 0.01;
	for(unsigned int x = 0; x < 10; x++)
	{
		unsigned int a = (r+x*ECHO_SIZE/31)%ECHO_SIZE;
		unsigned int b = (r+x*ECHO_SIZE/11)%ECHO_SIZE;
		unsigned int c = (r+x*ECHO_SIZE/17)%ECHO_SIZE;
		unsigned int e = (r+x*ECHO_SIZE/23)%ECHO_SIZE;
		float newvL = di*vL;
		float newvR = di*vR;
		echoBufferL[a] += newvR;
		echoBufferR[b] += newvR;
		echoBufferL[c] += newvL;
		echoBufferR[e] += newvL;
		di = di * d;
	}
	return r;
}


//Just do a flat limit so that we can crank the volume
///this limiter sucks....  need something without as much distortion
///as arctan, but smoother limiting
static inline SInt32 limiter(float x)
{
	return UPPERLIMIT*atanf(x)/(M_PI/2);
}

static OSStatus makeNoise(AudioBufferList* buffers)
{
	AudioBuffer* outputBufferL = &buffers->mBuffers[0];
	SInt32* dataL = (SInt32*)outputBufferL->mData;
	AudioBuffer* outputBufferR = &buffers->mBuffers[1];
	SInt32* dataR = (SInt32*)outputBufferR->mData;
	
	//I assume that they are the same!
	unsigned int samples = outputBufferL->mDataByteSize / sizeof(SInt32);
	for (unsigned int i = 0; i < samples; ++i) {
		bufferL[i] = 0;
		bufferR[i] = 0;
		dataL[i] = 0;
		dataR[i] = 0;
	}
	for(unsigned int j=0;j<FINGERS;j++)
	{
		//oops.... maybe this was a performance bug, because pitch always above 0 now...
		//just use volume and target volume to determine whether to write buffer
		//if a note is down, the targetVol is greater than 1, and when it's up
		//currentVol is exactly 0, so we don't have a float rounding issue here
		if(currentVol[j] > 0.001 || targetVol[j] > 0.001)
		{
			float harm = lastHarmonicPercentage[j];
			float samplePercentage = 1.0/samples;
			float g = 0.5*gainp;
			float gInv = 1-g;
			float thisFM2 = fm2; //must reach targetFM2 if we are in middle of change
			float thisFM4 = fm4;
			//float fmBase = (gainp*0.5+0.5*powerp+0.5+0.5*fm1)*M_PI*0.5;
			//float fmBase = atan((gainp*0.5+powerp*0.25+powerp*0.25)*M_PI*(0.5+currentVol[j]));
			float fmBase = (gainp*0.25+powerp*0.25+fm1*0.15+(harm)*0.15)*M_PI*atan(currentVol[j]*1.5);
			float fmBase2 = 0.75*fm3;
			float fmAmt = thisFM4*4 + (thisFM2-0.5)/4;
			float harmBaseFactor = (1-powerp/2);
			pitch[j] = targetPitch[j];
			for (unsigned int i = 0; i < samples; ++i) 
			{				
				float harml = (1-harm)*0.5;
				float harmUpFactor = 2*powerp*(harm);
				float harmDownFactor = 2*powerp*harml;//*(1-gainp);
				float harmFifthFactor = 2*fm1*harm;
				
				//float harml2 = harml*0.5;	
				float a = (i*pitch[j]*samplePercentage + angle[j]);
				float f = fmBase2*sinf(a*fmAmt);//+0.5*fm3*sinf(a*(thisFM4)*M_PI*5);
				float c = sinf(a*2)*fmBase;
				float total = 0;
				total += currentVol[j]*sinf( c+ f+a ) * harmBaseFactor;
				total += currentVol[j]*sinf( c+ f+a/2 ) * harmDownFactor;
				total += currentVol[j]*sinf( c+ f+2*a ) * harmUpFactor;				
				total += currentVol[j]*sinf( c+ f+3*a/2 ) * harmFifthFactor;
				bufferL[i] += total * pan[j];
				bufferR[i] += total * (1-pan[j]);
				//lopass filter changes to prevent popping noises
				pitch[j] = 0.9 * pitch[j] + 0.1 * targetPitch[j];
				//if(currentVol[j]+0.1<targetVol[j])
				{
					currentVol[j] = gInv * currentVol[j] + g * targetVol[j]; 
				}
				//harm = (0.99 * harm + 0.01 * harmonicPercentage[j]);
			}
			currentVol[j] = targetVol[j];
			lastPitch[j] = pitch[j];
			lastHarmonicPercentage[j] = harmonicPercentage[j];
			angle[j] += pitch[j];
			//pan[j] = (lastPitch[j]-8)/42;
		}
	}
	//NSLog(@"%f",currentVol[0]);
	fm1 = (3*fm1+targetFM1)/4;
	fm2 = (3*fm2+targetFM2)/4;
	fm4 = (3*fm4+targetFM4)/4;
	float unR = (1-reverbp);
	float unG = (1-gainp);
	//If reverb is low, then turn it off for performance (ie: external recording)
	float p = 0.01;
	float unP = 1-p;
	for (unsigned int i = 0; i < samples; ++i) {
		float distortedL = (unG*bufferL[i]+gainp*atanf(100*gainp*bufferL[i]))/40;
		float distortedR = (unG*bufferR[i]+gainp*atanf(100*gainp*bufferR[i]))/40;
		unsigned int bi = echoN(i,distortedL,distortedR);
		
		//lowpass filter		
		/*
		echoBufferL[bi] += unP*echoBufferL[(bi+ECHO_SIZE-30)%ECHO_SIZE]-p*echoBufferL[bi];
		echoBufferL[bi] += unP*echoBufferL[(bi+ECHO_SIZE-71)%ECHO_SIZE]-p*echoBufferL[bi];
		echoBufferL[bi] += unP*echoBufferL[(bi+ECHO_SIZE-151)%ECHO_SIZE]-p*echoBufferL[bi];
		echoBufferL[bi] += unP*echoBufferL[(bi+ECHO_SIZE-231)%ECHO_SIZE]-p*echoBufferL[bi];
		
		echoBufferR[bi] += unP*echoBufferR[(bi+ECHO_SIZE-17)%ECHO_SIZE]-p*echoBufferR[bi];
		echoBufferR[bi] += unP*echoBufferR[(bi+ECHO_SIZE-67)%ECHO_SIZE]-p*echoBufferR[bi];
		echoBufferR[bi] += unP*echoBufferR[(bi+ECHO_SIZE-121)%ECHO_SIZE]-p*echoBufferR[bi];
		echoBufferR[bi] += unP*echoBufferR[(bi+ECHO_SIZE-511)%ECHO_SIZE]-p*echoBufferR[bi];
		*/
		
		//Smooth out the data by rotating the last 4 samples for averaging
		///*
		float sumL = 0;
		float sumR = 0;
		for(int n=SAMPLESTOSMEAR;n>0;n--)
		{
			lastNSamplesL[n] = lastNSamplesL[n-1];
			lastNSamplesR[n] = lastNSamplesR[n-1];
			sumL += lastNSamplesL[n];
			sumR += lastNSamplesR[n];
		}
		lastNSamplesL[0] = echoBufferL[bi];
		lastNSamplesR[0] = echoBufferR[bi];
		sumL+=lastNSamplesL[0];
		sumR+=lastNSamplesR[0];
		echoBufferL[bi] = sumL/(SAMPLESTOSMEAR);
		echoBufferR[bi] = sumR/(SAMPLESTOSMEAR);
		
		//*/
		dataL[i] = limiter(
						   1.75*masterp*(reverbp*echoBufferL[bi] + unR*distortedL)
		);
		dataR[i] = limiter(
						   1.75*masterp*(reverbp*echoBufferR[bi] + unR*distortedR)
		);
		/*
		lastNSamplesL[0] = dataL[i];
		lastNSamplesR[0] = dataR[i];
		
		sumL+=dataL[i];
		sumR+=dataR[i];
		dataL[i] = sumL/(SAMPLESTOSMEAR);
		dataR[i] = sumR/(SAMPLESTOSMEAR);
		//*/
		echoBufferL[bi] *= reverbp*0.113;		
		echoBufferR[bi] *= reverbp*0.113;		
	}
	//NSLog(@"%f",minimumFrequency);
	oscilliscopeCursor += (unsigned int)(BUFFER_SIZE * 301.54 / minimumFrequency);
	totalSamples += samples;
	totalSamples &= 0xEFFFFFFF;
	return 0;
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
		for(int i=0;i<FINGERS;i++)
		{
			pitch[i] = -1;
			targetPitch[i] = -1;
			currentVol[i] = 0;
			targetVol[i] = 0;
			pan[i] = 0;
		}
		for(int i=0;i<SAMPLESTOSMEAR;i++)
		{
			lastNSamplesL[i] = 0;
			lastNSamplesR[i] = 0;
		}
	}
	for(int i=0;i<SINBUFFERSIZE;i++)
	{
		sinBuffer[i] = sinf( (M_PI * 2 * i) / SINBUFFERSIZE );
	}	
	return self;
}

- (void) start {
  minimumFrequency = 100000;
  totalSamples = 0;
  OSStatus status;
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
	  NSLog(@"AudioComponentInstanceNew:%d",status);
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
		  NSLog(@"AudioUnitSetProperty EnableIO:%d",status);
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
			  NSLog(@"AudioUnitSetProperty StreamFormat:%d",status);
		  }
		  else 
		  {
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
				  NSLog(@"AudioUnitSetProperty SetRenderCallback:%d",status);
			  }
			  else
			  {
				  status = AudioUnitInitialize(audioUnit);
				  if(status)
				  {
					  NSLog(@"AudioUnitInitialize:%d",status);
				  }
				  else 
				  {
					  status = AudioOutputUnitStart(audioUnit);
					  if(status)
					  {
						  NSLog(@"AudioUnitStart:%d",status);					  
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

- (void) setPan:(float)p forFinger:(int)f;
{
	if(0 <= f && f < FINGERS)
	{
		pan[f] = (1-p);
	}
}

- (void) setNote:(float)p forFinger:(int)f;
{
	if(0 <= f && f < FINGERS)
	{
		targetPitch[f] = p;
	}
}

- (void) setVol:(float)p forFinger:(int)f;
{
	if(0 <= f && f < FINGERS)
	{
		targetVol[f] = p;
	}
}

//Set AFTER pitch is set
- (void) setAttackVol:(float)p forFinger:(int)f;
{
	if(0 <= f && f < FINGERS)
	{
		currentVol[f] = p;
		pitch[f] = targetPitch[f];
		angle[f] = 0;
	}
}

- (void) setHarmonics:(float)h forFinger:(int)f;
{
	if(0 <= f && f < FINGERS)
	{
		harmonicPercentage[f] = h;
	}
}

- (void) setGain:(float)g
{
	gainp = g;
}

- (void) setReverb:(float)r
{
	reverbp = r;
}

- (void) setMaster:(float)m
{
	masterp = m;
}

- (void) setPower:(float)w
{
	powerp = w;
}

- (void) setFM1:(float)f
{
	targetFM1 = f;
}
- (void) setFM2:(float)f
{
	targetFM2 = f;
}
- (void) setFM3:(float)f
{
	fm3 = f;
}
- (void) setFM4:(float)f
{
	targetFM4 = f;
}

@end


