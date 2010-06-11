
#import "AudioOutput.h"
#import <AudioUnit/AudioUnitProperties.h>
#import <AudioUnit/AudioOutputUnit.h>
#import <AudioToolbox/AudioServices.h>


@implementation AudioOutput

#define UPPERLIMIT (214748367-10)

static unsigned int totalSamples=0;
static float gainp=0.5;
static float reverbp=0.5;
static float masterp=0.25;
static float powerp=0.5;
static const double kSampleRate = 44100.0;
static const int kOutputBus = 0;

static float angle[FINGERS];
static float echoBuffer[ECHO_SIZE];

static float harmonicPercentage[FINGERS];
static float lastHarmonicPercentage[FINGERS];

static float lastPitch[FINGERS];
static float pitch[FINGERS];
static float targetPitch[FINGERS];

static float targetVol[FINGERS];
static float currentVol[FINGERS];


static int echoN(int i,float v)
{
	float di = 0.25;
	float d = 0.9;
	unsigned int r = (i+totalSamples)%ECHO_SIZE;
	float p = 0.01;
	float unP = 1-p;
	for(unsigned int x = 0; x < 10; x++)
	{
		unsigned int a = (r+x*ECHO_SIZE/7)%ECHO_SIZE;
		unsigned int b = (r+x*ECHO_SIZE/11)%ECHO_SIZE;
		unsigned int c = (r+x*ECHO_SIZE/13)%ECHO_SIZE;
		float newv = di*v;
		echoBuffer[a] += newv;
		echoBuffer[b] += newv;
		echoBuffer[c] += newv;
		di = di * d;
	}
	return r;
}


//Just do a flat limit so that we can crank the volume
///this limiter sucks....  need something without as much distortion
///as arctan, but smoother limiting
static SInt32 limiter(float x)
{
	return UPPERLIMIT*atan(x)/(M_PI/2);
}

static OSStatus makeNoise(AudioBufferList* buffers)
{
	AudioBuffer* outputBuffer = &buffers->mBuffers[0];
	SInt32* data = (SInt32*)outputBuffer->mData;
	unsigned int samples = outputBuffer->mDataByteSize / sizeof(SInt32);
	float buffer[samples];
	for (unsigned int i = 0; i < samples; ++i) {
		buffer[i] = 0;
		data[i] = 0;
	}
	for(unsigned int j=0;j<FINGERS;j++)
	{
		//oops.... maybe this was a performance bug, because pitch always above 0 now...
		//just use volume and target volume to determine whether to write buffer
		//if a note is down, the targetVol is greater than 1, and when it's up
		//currentVol is exactly 0, so we don't have a float rounding issue here
		if(currentVol[j] > 0.1 || targetVol[j] > 0.1)
		{
			float harm = lastHarmonicPercentage[j];
			float samplePercentage = 1.0/samples;
			float g = 0.01;
			float gInv = 1-g;
			float unGainp = 1-gainp;
			
			//If we are turning on a note, then don't lpfilter vol and harmonics
			if(currentVol[j] < 0.01)
			{
				pitch[j] = targetPitch[j]; 
				harmonicPercentage[j] = harm;
				angle[j] = 0;
			}
			
			//Only take lpfilter path if we have to
			if( 
			   (targetPitch[j] != pitch[j]) ||
			   (targetVol[j] != currentVol[j]) ||
			   (harmonicPercentage[j] != lastHarmonicPercentage[j]) 
			)
			{
				for (unsigned int i = 0; i < samples; ++i) {				
					float harml = (1-harm)*0.5;
					//float harml2 = harml*0.5;	
					float a = i*pitch[j]*samplePercentage + angle[j];
					//float fm = powerp+(1-powerp)*cos(a*10);
					buffer[i] += currentVol[j]*sin( a );
					buffer[i] += currentVol[j]*sin( a/2 ) * 2*powerp*harml;
					//buffer[i] += currentVol[j]*sin( a/4 ) * powerp*harml;
					buffer[i] += currentVol[j]*sin( 2*a ) *2*powerp*(harm);
					
					//lopass filter changes to prevent popping noises
					pitch[j] = 0.9 * pitch[j] + 0.1 * targetPitch[j];
					currentVol[j] = gInv * currentVol[j] + g * targetVol[j]; 
					harm = (0.99 * harm + 0.01 * harmonicPercentage[j]);
				}
			}
			else 
			{
				float harml = (1-harm)*0.5;
				//float harml2 = harml*0.5;	
				for (unsigned int i = 0; i < samples; ++i) {		
					float a = i*pitch[j]*samplePercentage + angle[j];
					//float fm = powerp+(1-powerp)*cos(a*10);
					buffer[i] += currentVol[j]*sin( a );
					buffer[i] += currentVol[j]*sin( a/2 ) * 2*powerp*harml;
					//buffer[i] += currentVol[j]*sin( a/4 ) * powerp*harml;
					buffer[i] += currentVol[j]*sin( 2*a ) *2*powerp*(harm);
				}
			}
			
			lastPitch[j] = pitch[j];
			lastHarmonicPercentage[j] = harmonicPercentage[j];
			angle[j] += pitch[j];
		}
	}
	float unR = (1-reverbp);
	float unG = (1-gainp);
	//If reverb is low, then turn it off for performance (ie: external recording)
	if(reverbp > 0.04)
	{
		float p = 0.1;
		float unP = 1-p;
		for (unsigned int i = 0; i < samples; ++i) {
			float distorted = (unG*buffer[i]+gainp*atan(100*gainp*buffer[i]))/40;
			unsigned int bi = echoN(i,distorted);
			
			//lowpass filter			
			echoBuffer[bi] += unP*echoBuffer[(bi+ECHO_SIZE-3)%ECHO_SIZE]-p*echoBuffer[bi];
			echoBuffer[bi] += unP*echoBuffer[(bi+ECHO_SIZE-7)%ECHO_SIZE]-p*echoBuffer[bi];
			echoBuffer[bi] += unP*echoBuffer[(bi+ECHO_SIZE-11)%ECHO_SIZE]-p*echoBuffer[bi];
			echoBuffer[bi] += unP*echoBuffer[(bi+ECHO_SIZE-13)%ECHO_SIZE]-p*echoBuffer[bi];
			data[i] = limiter(1.75*masterp*(reverbp*echoBuffer[bi] + unR*distorted));
			echoBuffer[bi] *= reverbp*0.125;
		}
	}
	else 
	{
		for (unsigned int i = 0; i < samples; ++i) {
			float distorted = (unG*buffer[i]+gainp*atan(100*gainp*buffer[i]))/40;
			data[i] = limiter(1.75*masterp*distorted);
		}
	}

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
		}
	}
	return self;
}

- (void) start {
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
		  audioFormat.mChannelsPerFrame = 1;
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

@end


