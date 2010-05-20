
#import <Foundation/Foundation.h>
#import <AudioUnit/AUComponent.h>

#define FINGERS 10
#define NUM_BUFFERS 4
#define BUFFER_SIZE (1024)
#define ECHO_BITS 16
#define ECHO_SIZE (1<<ECHO_BITS)

@interface AudioOutput : NSObject {
 @private
  AudioComponentInstance audioUnit;
  AudioStreamBasicDescription audioFormat;
}

- (void) start;

- (void) setNote:(float)p forFinger:(int)f;
- (void) setVol:(float)v forFinger:(int)f;
- (void) setHarmonics:(float)h forFinger:(int)f;
- (void) setGain:(float)g;
- (void) setReverb:(float)r;
- (void) setMaster:(float)m;
- (void) setPower:(float)w;
@end
