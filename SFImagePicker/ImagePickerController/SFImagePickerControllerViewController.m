//
//  SFImagePickerControllerViewController.m
//  SFImagePicker
//
//  Created by malczak on 1/7/13.
//  Copyright (c) 2013 segfaultsoft. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>
#import <QuartzCore/QuartzCore.h>

#import "SFImagePickerControllerViewController.h"
#import "SFViewControllerModel.h"
#import "SFGroupTableViewController.h"
#import "SFAssetTableViewController.h"

/**
 
 http://stackoverflow.com/questions/2962162/non-fullscreen-uinavigationcontroller
 http://stackoverflow.com/questions/2526990/adding-a-uinavigationcontroller-as-a-subview-of-uiview
 
 http://stackoverflow.com/questions/8084050/when-to-use-addchildviewcontroller-vs-pushviewcontroller
 
  [      ]
  [ Nav. ]
  [      ]
  [______]
  [ sel. ]
 
 */

@interface SFImagePickerControllerViewController ()

@end

@implementation SFImagePickerControllerViewController

@synthesize delegate;

-(id) init {
    self = [super init];
    if(self) {
        model = [[SFViewControllerModel alloc] init];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    CGRect frm =  [[UIScreen mainScreen] applicationFrame];
    self.view = [[UIView alloc] initWithFrame:frm];
    self.view.clipsToBounds = YES;
    self.view.backgroundColor = [UIColor redColor];
    self.view.bounds = CGRectMake(0,0,frm.size.width,frm.size.height);
    
    UIImage *selectedOverlayImage = [UIImage imageNamed:@"Overlay.png"];
    model.selectedOverlayImage = selectedOverlayImage;
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    CGRect viewRect = self.view.frame;
    CGFloat navHeight = viewRect.size.height - 90;
    
    // create main navigation controller to display assets
    navigationController = [[UINavigationController alloc] init];
    
//	[cancelButton release];
    
    [self addChildViewController:navigationController];
    [self.view addSubview:navigationController.view];
    navigationController.view.frame = CGRectMake(0, 0, viewRect.size.width, navHeight);
    
    
    CGRect selectedRect = CGRectMake(0, navHeight, viewRect.size.width, viewRect.size.height - navHeight);
    //create selected assets scroll view
    selectedAssetsView = [[UIScrollView alloc] initWithFrame:selectedRect];
    selectedAssetsView.pagingEnabled = YES;
    selectedAssetsView.bounces = NO;
    selectedAssetsView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:selectedAssetsView];
    
    //empty selection prompt
    emptySelectionPrompt = [[UILabel alloc] initWithFrame:selectedRect];
    emptySelectionPrompt.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    emptySelectionPrompt.textAlignment = NSTextAlignmentCenter;
    emptySelectionPrompt.text = [NSString stringWithFormat:@"Select up to %d photos", [self getAllowedSelectionSize]];
    CALayer *layer = emptySelectionPrompt.layer;
    layer.shadowColor = [[UIColor blackColor] CGColor];
    layer.shadowOpacity = 0.8;
    layer.shadowRadius = 4;
    layer.shouldRasterize = YES;
    [self.view addSubview:emptySelectionPrompt];
    
    
    // initialize assets library access
    [ALAssetsLibrary disableSharedPhotoStreamsSupport];
    model.assetsLibrary = [[ALAssetsLibrary alloc] init];
    
    // get array of all available groups
    void (^completeBlock)(ALAssetsGroup *group, BOOL *stop) = ^(ALAssetsGroup *group, BOOL *stop)
    {
        // finished
        if(group == nil) {
            [self performSelectorOnMainThread:@selector(groupEnummerationDone) withObject:nil waitUntilDone:YES];
//            dispatch_async( dispatch_get_main_queue(), ^(void){
//                [self groupEnummerationDone];
//            });
            return;
        }
        
        [model.assetGroups addObject: group];
        NSLog(@"Num : %d", [model.assetGroups count]);
    };
    
    void (^failureBlock)(NSError *error) = ^(NSError *error) {
        // alert ;/
        NSLog(@"error");
    };
    
    [model.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:completeBlock failureBlock:failureBlock];
    
}

- (void)groupEnummerationDone
{
    SFGroupTableViewController *groupTableViewController = [[SFGroupTableViewController alloc] initWithStyle:UITableViewStylePlain];
    [self createDefaultButtonsInNavigation:groupTableViewController.navigationItem withCancel:YES];
    groupTableViewController.delegate = self;
    groupTableViewController.model = model;
    [navigationController pushViewController:groupTableViewController animated:YES];
}

- (void)assetsEnummerationDone
{
    SFAssetTableViewController *assetTableViewController = [[SFAssetTableViewController alloc] initWithStyle:UITableViewStylePlain];
    [self createDefaultButtonsInNavigation:assetTableViewController.navigationItem withCancel:NO];
    assetTableViewController.delegate = self;
    assetTableViewController.model = model;
    [navigationController pushViewController:assetTableViewController animated:YES];
}

-(void)createDefaultButtonsInNavigation:(UINavigationItem*) navigationItem withCancel:(BOOL) cancel
{
    
    if(cancel == YES) {
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelImagePicker)];
        [navigationItem setLeftBarButtonItem:cancelButton];
    }

    UIBarButtonItem *acceptButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(acceptImagePicker)];
	[navigationItem setRightBarButtonItem:acceptButton];   
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

#pragma mark -- Delegate user decisions --
-(void) cancelImagePicker
{
    if( [self.delegate respondsToSelector:@selector(sfImagePickerContollerDidCancel:)] ) {
        [self.delegate performSelector:@selector(sfImagePickerContollerDidCancel:) withObject:self];
    }
}

-(void) acceptImagePicker
{
    if( [self.delegate respondsToSelector:@selector(sfImagePickerContoller:didFinishWithInfo:)] ) {

        // selected assets NSURL's
        NSArray* info = [NSArray arrayWithArray:model.selectedAssets];
/*
        NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
        
        for(ALAsset *asset in model.sele) {
            
            NSMutableDictionary *workingDictionary = [[NSMutableDictionary alloc] init];
            [workingDictionary setObject:[asset valueForProperty:ALAssetPropertyType] forKey:@"UIImagePickerControllerMediaType"];
            [workingDictionary setObject:[UIImage imageWithCGImage:[[asset defaultRepresentation] fullScreenImage]] forKey:@"UIImagePickerControllerOriginalImage"];
            [workingDictionary setObject:[[asset valueForProperty:ALAssetPropertyURLs] valueForKey:[[[asset valueForProperty:ALAssetPropertyURLs] allKeys] objectAtIndex:0]] forKey:@"UIImagePickerControllerReferenceURL"];
            
            [returnArray addObject:workingDictionary];
            
            [workingDictionary release];
        }
 */
        
        
        [self.delegate performSelector:@selector(sfImagePickerContoller:didFinishWithInfo:) withObject:self withObject:[NSArray arrayWithObject:info]];
    }
}



#pragma mark -- Allowed selection size getter/setter --
-(void)setAllowedSelectionSize:(UInt16)value {
    model.allowedSelectionSize = value;
}

-(UInt16)getAllowedSelectionSize {
    return model.allowedSelectionSize;
}


#pragma mark -- SFAssetsControllerDelegate --

-(void)userSelectedGroup:(ALAssetsGroup *)group
{
//    [self dismissViewControllerAnimated:YES completion:nil];
    
    model.selectedGroup = group;
    
    void (^completeBlock)(ALAsset *result, NSUInteger index, BOOL *stop) = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
        
        if (result == nil) {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self assetsEnummerationDone];
            });
            return;
        }
        
        [model.selectedGroupAssets addObject:result];
    };
    
    [model.selectedGroup enumerateAssetsUsingBlock:completeBlock];
}

-(void)userSelectedAsset:(ALAsset *)asset
{
    if(asset == nil) {
        return;
    }
    
    // if selected deselect
    UIView *thumb;
    id url = [asset valueForProperty:ALAssetPropertyAssetURL];
    
    int selectedCount = [model.selectedAssets count];
    int selectedIndex = [model.selectedAssets indexOfObject:url];

    if( selectedIndex != NSNotFound ) {
        
        thumb = [model.selectedAssetsThumbnails objectAtIndex:selectedIndex];
        [thumb removeFromSuperview];
        //remove
            
        [model.selectedAssets removeObjectAtIndex:selectedIndex];
        [model.selectedAssetsThumbnails removeObjectAtIndex:selectedIndex];
            
        [self layoutSelectedAssets];
        
    } else
    if ( selectedCount < model.allowedSelectionSize) {

        emptySelectionPrompt.hidden = YES;

        CGSize thumbSize = CGSizeMake(75, 75);
        
        thumb = [self createThumbViewWithAsset:asset];
        thumb.bounds = CGRectMake( 0, 0, thumbSize.width, thumbSize.height);
        [selectedAssetsView addSubview:thumb];
        
        [model.selectedAssets addObject:url];
        [model.selectedAssetsThumbnails addObject:thumb];
 
        [self layoutSelectedAssets];
    } else {
        //show info
        emptySelectionPrompt.hidden = NO;
        emptySelectionPrompt.alpha = 0.0;
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionRepeat|UIViewAnimationOptionAutoreverse|UIViewAnimationOptionCurveEaseInOut
                         animations:^(void) {
                             [UIView setAnimationRepeatCount:0.8f];
                             emptySelectionPrompt.alpha = 1.0;
                         }
                         completion:^(BOOL finished){
                             if(finished) {
                                 emptySelectionPrompt.alpha = 1.0;
                                 emptySelectionPrompt.hidden = YES;
                             }
                         }];

    }
    

}

#pragma mark -- Upadate selected assets view --

-(void)updateSelectedAssetsView {
    int assetsCount = [model.selectedAssets count];
    
    emptySelectionPrompt.hidden = (assetsCount>0);

    //NSArray *thumbs = selectedAssetsView.subviews;

    CGSize thumbSize = CGSizeMake(75, 75);

    selectedAssetsView.contentSize = CGSizeMake( (thumbSize.width + 4) * assetsCount - 4, thumbSize.height);
    
    int index = 0;
    while ( index < assetsCount ) {
        ALAsset *asset = [model.selectedAssets objectAtIndex:index];
        UIImage *thumbImage = [UIImage imageWithCGImage:asset.thumbnail];
        UIImageView *thumb = [[UIImageView alloc] initWithFrame:CGRectMake( (thumbSize.width + 4) * index , 0, thumbSize.width, thumbSize.height)];
        thumb.image = thumbImage;
        [selectedAssetsView addSubview:thumb];
        index += 1;
    }
}

-(void) layoutSelectedAssets {
    
    UIView *thumb = nil;
    
    int count = [model.selectedAssetsThumbnails count];
    
    
    NSLog(@"count %d",count);

    if(count) {
        float X = 4;
        int index = 0;
        
        while(index<count) {
            thumb = [model.selectedAssetsThumbnails objectAtIndex:index];
            thumb.frame = CGRectMake( X, 4, thumb.bounds.size.width, thumb.bounds.size.height);
            NSLog(@" %f + %f",X,thumb.frame.size.width);
            X += 75 + 4;
            index += 1;
        }
        
        selectedAssetsView.contentSize = CGSizeMake( X, thumb.frame.size.height);
        [selectedAssetsView scrollRectToVisible:thumb.frame animated:NO];
    }
   
}

-(UIView*) createThumbViewWithAsset:(ALAsset*) asset {
    UIImage *thumbImage = [UIImage imageWithCGImage:asset.thumbnail];
    UIImageView *thumb = [[UIImageView alloc] init];
    thumb.image = thumbImage;
    return thumb;
}

-(void)dealloc
{
    self.delegate = nil;
    model = nil;
}

@end
