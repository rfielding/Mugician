
#import <Foundation/Foundation.h>
#import <AudioUnit/AUComponent.h>

#define FINGERS 8

#define NUM_BUFFERS 4
#define BUFFER_SIZE (1024)
#define ECHO_BITS 16
#define ECHO_SIZE (1<<ECHO_BITS)

#define SLIDER0 0.25
#define SLIDER1 0.79296875
#define SLIDER2 0.663085938
#define SLIDER3 0.735351562
#define SLIDER4 0.25
#define SLIDER5 0.48
#define SLIDER6 0.5
#define SLIDER7 0.0
#define SLIDER8 0.400000006

float bufferL[BUFFER_SIZE];
float bufferR[BUFFER_SIZE];

float minimumFrequency;
float frequencyPeriod;
unsigned int totalSamples;
unsigned int oscilliscopeCursor;

@interface AudioOutput : NSObject {
 @private
  AudioComponentInstance audioUnit;
  AudioStreamBasicDescription audioFormat;
}

- (void) start;

- (void) setPan:(float)p forFinger:(int)f;
- (void) setNote:(float)p forFinger:(int)f;
- (void) setVol:(float)v forFinger:(int)f;
- (void) setAttackVol:(float)v forFinger:(int)f;
- (void) setHarmonics:(float)h forFinger:(int)f;
- (void) setGain:(float)g;
- (void) setReverb:(float)r;
- (void) setMaster:(float)m;
- (void) setPower:(float)w;
- (void) setFM1:(float)f;
- (void) setFM2:(float)f;
- (void) setFM3:(float)f;
- (void) setFM4:(float)f;
@end
