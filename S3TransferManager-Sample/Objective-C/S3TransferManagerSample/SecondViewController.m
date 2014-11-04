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

#import "SecondViewController.h"
#import "S3.h"
#import "Constants.h"
#import "DisplayImageController.h"

// Enum used to set UI state
typedef enum UIState
{
    Paused, Cancelled, Ready, Downloading, Completed, Failed
} UIState;

@interface SecondViewController ()

// URLs for test files
@property (nonatomic, strong) AWSS3TransferManagerDownloadRequest *downloadRequest1;
@property (nonatomic, strong) AWSS3TransferManagerDownloadRequest *downloadRequest2;
@property (nonatomic, strong) AWSS3TransferManagerDownloadRequest *downloadRequest3;

// Progress indicators
@property (strong, nonatomic) IBOutlet UIProgressView *progressView1;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView2;
@property (strong, nonatomic) IBOutlet UIProgressView *progressView3;

// Labels to display downloaded file names
@property (weak, nonatomic) IBOutlet UILabel *file1Label;
@property (weak, nonatomic) IBOutlet UILabel *file2Label;
@property (weak, nonatomic) IBOutlet UILabel *file3Label;
@property (weak, nonatomic) IBOutlet UIButton *viewImage1Button;
@property (weak, nonatomic) IBOutlet UIButton *viewImage2Button;
@property (weak, nonatomic) IBOutlet UIButton *viewImage3Button;

// Data to compute download progress
@property (nonatomic) int64_t file1Size;
@property (nonatomic) int64_t file1AlreadyDownloaded;

@property (nonatomic) int64_t file2Size;
@property (nonatomic) int64_t file2AlreadyDownloaded;

@property (nonatomic) int64_t file3Size;
@property (nonatomic) int64_t file3AlreadyDownloaded;

@property (nonatomic) int fileIndex;

@end

@implementation SecondViewController

// Set button state based on UIState enum
- (void) updateUIForState:(enum UIState )state
{
    switch (state)
    {
        case Paused:
            self.downloadStatusLabel.text = StatusLabelReady;
            self.downloadButton.enabled = false;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = true;
            self.cancelButton.enabled = true;
            break;
            
        case Cancelled:
            self.downloadStatusLabel.text = StatusLabelCancelled;
            self.downloadButton.enabled = true;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            self.cancelButton.enabled = false;
            [self cleanProgress];
            break;
            
        case Ready:
            self.downloadStatusLabel.text = StatusLabelReady;
            self.downloadButton.enabled = true;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            self.cancelButton.enabled = false;
            self.file1Label.text = S3KeyDownloadName1;
            self.file2Label.text = S3KeyDownloadName2;
            self.file3Label.text = S3KeyDownloadName3;
            self.viewImage1Button.enabled = false;
            self.viewImage2Button.enabled = false;
            self.viewImage3Button.enabled = false;
            break;
            
        case Downloading:
            self.downloadStatusLabel.text = StatusLabelDownloading;
            self.downloadButton.enabled = false;
            self.pauseButton.enabled = true;
            self.resumeButton.enabled = false;
            self.cancelButton.enabled = true;
            break;
            
        case Completed:
            self.downloadStatusLabel.text = StatusLabelCompleted;
            self.downloadButton.enabled = true;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            self.cancelButton.enabled = false;
            self.viewImage1Button.enabled = true;
            self.viewImage2Button.enabled = true;
            self.viewImage3Button.enabled = true;
            break;
            
        case Failed:
            self.downloadStatusLabel.text = StatusLabelFailed;
            self.downloadButton.enabled = false;
            self.pauseButton.enabled = false;
            self.resumeButton.enabled = false;
            self.cancelButton.enabled = false;
            break;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Update UI
    [self cleanProgress];
    [self updateUIForState:Ready];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) submitDownloadRequest:(AWSS3TransferManagerDownloadRequest *)request
{
    // Submit an asynchronous download request
    AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
    __block AWSS3TransferManagerDownloadRequest *currentRequest = request;
    static int completedCount = 0;
    
    [[transferManager download:currentRequest] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                          withBlock:^id(BFTask *task)
     {
         // An task.error will be non-nil when a download is paused or cancelled. This is expected behavior, so update the UI
         if (task.error != nil)
         {
             if (task.error.code == AWSS3TransferManagerErrorCancelled)
             {
                 NSLog(@"Download cancelled while downloading: %@", [task.error.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey]);
                 completedCount = 0;
                 [self updateUIForState:Ready];
             }
             else if (task.error.code == AWSS3TransferManagerErrorPaused)
             {
                 NSLog(@"%s %@","Download paused while downloading :", [task.error.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey]);
                 [self updateUIForState:Paused];
             }
             else /* an actual error occured */
             {
                 NSLog(@"%s %@","Error downloading :", [task.error.userInfo objectForKey:NSURLErrorFailingURLStringErrorKey]);
                 [self updateUIForState:Failed];
             }
         }
         else
         {
             // The download operation completed without error
             completedCount++;
             
             NSLog(@"Download of %@ completed", (currentRequest).key);
             NSLog(@"completedCount = %d", completedCount);
             
             // Only update the UI to completed when all three downloads complete
             if (completedCount == 3)
             {
                 [self updateUIForState:Completed];
                 completedCount = 0;
             }
             
         }
         
         return nil;
     }];
}

- (IBAction)downloadButtonPressed:(id)sender {
    
    __weak typeof (self) weakSelf = self;
    
    // Create URLs to the location to store the downloaded files
    NSString *downloadingFilePath1 = [NSTemporaryDirectory() stringByAppendingPathComponent:LocalFileName1];
    NSURL *downloadingFileURL1 = [NSURL fileURLWithPath:downloadingFilePath1];
    
    NSString *downloadingFilePath2 = [NSTemporaryDirectory() stringByAppendingPathComponent:LocalFileName2];
    NSURL *downloadingFileURL2 = [NSURL fileURLWithPath:downloadingFilePath2];
    
    NSString *downloadingFilePath3 = [NSTemporaryDirectory() stringByAppendingPathComponent:LocalFileName3];
    NSURL *downloadingFileURL3 = [NSURL fileURLWithPath:downloadingFilePath3];
    
    // If the files already exists, delete them
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if ([fileManager fileExistsAtPath:downloadingFilePath1]) {
        if (![fileManager removeItemAtPath:downloadingFilePath1
                                     error:&error]) {
            NSLog(@"Error: %@", error);
        }
    }
    
    if ([fileManager fileExistsAtPath:downloadingFilePath2]) {
        if (![fileManager removeItemAtPath:downloadingFilePath2
                                     error:&error]) {
            NSLog(@"Error: %@", error);
        }
    }
    
    if ([fileManager fileExistsAtPath:downloadingFilePath3]) {
        if (![fileManager removeItemAtPath:downloadingFilePath3
                                     error:&error]) {
            NSLog(@"Error: %@", error);
        }
    }
    
    // Create download requests
    self.downloadRequest1 = [AWSS3TransferManagerDownloadRequest new];
    self.downloadRequest1.bucket = S3BucketName;
    self.downloadRequest1.key = S3KeyDownloadName1;
    self.downloadRequest1.downloadingFileURL = downloadingFileURL1;
    self.downloadRequest1.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite)
    {
        // Create a code block that S3 will call with progress updates
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.file1AlreadyDownloaded = totalBytesWritten;
            weakSelf.file1Size = totalBytesExpectedToWrite;
            [weakSelf updateProgress];
        });
    };

    self.downloadRequest2 = [AWSS3TransferManagerDownloadRequest new];
    self.downloadRequest2.bucket = S3BucketName;
    self.downloadRequest2.key = S3KeyDownloadName2;
    self.downloadRequest2.downloadingFileURL = downloadingFileURL2;
    self.downloadRequest2.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite)
    {
        // Create a code block that S3 will call with progress updates
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.file2AlreadyDownloaded = totalBytesWritten;
            weakSelf.file2Size = totalBytesExpectedToWrite;
            [weakSelf updateProgress];
        });
    };
    
    self.downloadRequest3 = [AWSS3TransferManagerDownloadRequest new];
    self.downloadRequest3.bucket = S3BucketName;
    self.downloadRequest3.key = S3KeyDownloadName3;
    self.downloadRequest3.downloadingFileURL = downloadingFileURL3;
    self.downloadRequest3.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite)
    {
        // Create a code block that S3 will call with progress updates
        dispatch_sync(dispatch_get_main_queue(), ^{
            weakSelf.file3AlreadyDownloaded = totalBytesWritten;
            weakSelf.file3Size = totalBytesExpectedToWrite;
            [weakSelf updateProgress];
        });
    };

    
    // Update UI
    [self updateUIForState:Downloading];
    [self cleanProgress];
    
    // Download files
    [self downloadFiles];
   
}

- (void) downloadFiles
{
    // Submit ansychronous calls to download the files
    if (self.downloadRequest1.state == AWSS3TransferManagerRequestStateRunning || self.downloadRequest1.state == AWSS3TransferManagerRequestStatePaused)
        [self submitDownloadRequest:self.downloadRequest1];
    
    if (self.downloadRequest2.state == AWSS3TransferManagerRequestStateRunning || self.downloadRequest2.state == AWSS3TransferManagerRequestStatePaused)
        [self submitDownloadRequest:self.downloadRequest2];
    
    if (self.downloadRequest3.state == AWSS3TransferManagerRequestStateRunning || self.downloadRequest3.state == AWSS3TransferManagerRequestStatePaused)
        [self submitDownloadRequest:self.downloadRequest3];
}

- (IBAction)cancelButtonPressed:(id)sender
{
    
    // Cancel the download requests and update the UI when all operations complete.
    NSMutableArray *tasksToCancel = [[NSMutableArray alloc] init];
    
    [tasksToCancel addObject:[self.downloadRequest1 cancel]];
    [tasksToCancel addObject:[self.downloadRequest2 cancel]];
    [tasksToCancel addObject:[self.downloadRequest3 cancel]];
    
    [[BFTask taskForCompletionOfAllTasks:tasksToCancel] continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id(BFTask *task) {
        [self updateUIForState:Cancelled];
        return task;
    }];
}

- (IBAction)pauseButtonPressed:(id)sender {
   
    // Pause the current download operations and update the UI when all operations complete
    // NOTE: If the files you are uploading are < 5MB the upload will simply be cancelled. If the files you are uploading are > 5MB the S3 Transfer Manager will pause the upload operation
    NSMutableArray *tasksToPause = [[NSMutableArray alloc] init];
    
    [tasksToPause addObject:[self.downloadRequest1 pause]];
    [tasksToPause addObject:[self.downloadRequest2 pause]];
    [tasksToPause addObject:[self.downloadRequest3 pause]];
    
    [[BFTask taskForCompletionOfAllTasks:tasksToPause] continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:^id(BFTask *task) {
        [self updateUIForState:Paused];
        return task;
    }];
}

- (IBAction)resumeButtonPressed:(id)sender {
    
    // The SDK will automatically handle restarting the download if the file is > 5MB, otherwise the download will start over
    [self downloadFiles];
    [self updateUIForState:Downloading];
}

- (void)updateProgress
{
    // Calculate length of progress bar
    if (self.file1AlreadyDownloaded <= self.file1Size)
    {
        self.progressView1.progress = (float)self.file1AlreadyDownloaded / (float)self.file1Size;
    }
    
    if (self.file2AlreadyDownloaded <= self.file2Size)
    {
        self.progressView2.progress = (float)self.file2AlreadyDownloaded / (float)self.file2Size;
    }
    
    if (self.file3AlreadyDownloaded <= self.file3Size)
    {
        self.progressView3.progress = (float)self.file3AlreadyDownloaded / (float)self.file3Size;
    }
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    // The view button has been pressed, switch to display image view controller
    UIButton *viewButton = (UIButton*)sender;
    DisplayImageController * viewController = segue.destinationViewController;
    viewController.fileIndex = (int)viewButton.tag;
}

- (void) cleanProgress {
    
    // reset progress bars and values used to calculate progress bar completion.
    self.progressView1.progress = 0;
    self.progressView2.progress = 0;
    self.progressView3.progress = 0;
    
    self.file1Size = 0;
    self.file1AlreadyDownloaded = 0;

    self.file2Size = 0;
    self.file2AlreadyDownloaded = 0;
    
    self.file3Size = 0;
    self.file3AlreadyDownloaded = 0;
}

@end

