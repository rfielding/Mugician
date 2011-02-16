
#import <Foundation/Foundation.h>
#import <AudioUnit/AUComponent.h>

#define FINGERS 10

#define NUM_BUFFERS 3

#define ECHOSIZE (1<<18)
#define REVERBSIZE (1<<16)

//#define BUFFER_SIZE (1024)

//1Mb buffer
//#define ECHO_BITS 20
//#define ECHO_SIZE (1<<ECHO_BITS)
//#define ECHO_MASK (ECHO_SIZE-1)

float bufferL[1024*4]; //bufferSamples could be smaller!  should not be larger
float bufferR[1024*4];
unsigned int bufferSamples;
//unsigned int echo_size;

float minimumFrequency;
float frequencyPeriod;
unsigned int stride;
unsigned int oscilliscopeCursor;
unsigned int totalSamples;
AudioComponentInstance audioUnit;
AudioStreamBasicDescription audioFormat;

@interface AudioOutput : NSObject {
 @private
}

- (void) start;

- (void) setPan:(float)p forFinger:(unsigned int)f;
- (void) setNote:(float)p forFinger:(unsigned int)f isAttack:(unsigned int)a;
- (void) setVol:(float)v forFinger:(unsigned int)f;
- (void) setAttackVol:(float)v forFinger:(unsigned int)f;
- (void) setHarmonics:(float)h forFinger:(unsigned int)f;
- (void) setGain:(float)g;
- (void) setReverb:(float)r;
- (void) setMaster:(float)m;
- (void) setPower:(float)w;
- (void) setFM1:(float)f;
- (void) setDelayTime:(float)f;
- (void) setDelayFeedback:(float)f;
- (void) setDelayVolume:(float)f;
@end
