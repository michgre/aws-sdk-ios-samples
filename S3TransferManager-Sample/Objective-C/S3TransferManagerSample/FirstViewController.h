/*
 * Copyright 2010-2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import <UIKit/UIKit.h>

@interface FirstViewController : UIViewController

// Status Label
@property (nonatomic, weak) IBOutlet UILabel *uploadStatusLabel;

// Buttons
@property (nonatomic, weak) IBOutlet UIButton *uploadButton;
@property (nonatomic, weak) IBOutlet UIButton *pauseButton;
@property (nonatomic, weak) IBOutlet UIButton *resumeButton;
@property (nonatomic, weak) IBOutlet UIButton *cancelButton;

// File Upload Progress Views (Bars)
@property (strong, nonatomic) IBOutlet UIProgressView *progressView1;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView2;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView3;

// Button Handlers
- (IBAction)uploadButtonPressed:(id)sender;
- (IBAction)pauseButtonPressed:(id)sender;
- (IBAction)resumeButtonPressed:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;

@end
