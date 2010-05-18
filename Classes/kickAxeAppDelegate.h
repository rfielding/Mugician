//
//  kickAxeAppDelegate.h
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EAGLView;
@class MyViewController;

@interface kickAxeAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    EAGLView *glView;
	MyViewController *myViewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet EAGLView *glView;
@property (nonatomic, retain) IBOutlet MyViewController *myViewController;

@end

