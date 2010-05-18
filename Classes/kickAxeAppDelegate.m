//
//  kickAxeAppDelegate.m
//  kickAxe
//
//  Created by Robert Fielding on 4/7/10.
//  Copyright Check Point Software 2010. All rights reserved.
//

#import "kickAxeAppDelegate.h"
#import "EAGLView.h"
#import "MyViewController.h"

@implementation kickAxeAppDelegate

@synthesize window;
@synthesize glView;
@synthesize myViewController;




- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions   
{
    MyViewController *aViewController = [[MyViewController alloc]
											   
											   initWithNibName:@"MyViewController" bundle:[NSBundle mainBundle]];
    [self setMyViewController:aViewController];
	UIView *controllersView = [aViewController view];
	[controllersView addSubview:glView];
	
	[window addSubview:controllersView];
	
	
    [window makeKeyAndVisible];
	
    [aViewController release];
	
	[glView startAnimation];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [glView stopAnimation];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [glView startAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [glView stopAnimation];
}

- (void)dealloc
{
    [window release];
    [glView release];

    [super dealloc];
}

@end
