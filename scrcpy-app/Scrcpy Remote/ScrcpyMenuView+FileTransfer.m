//
//  ScrcpyMenuView+FileTransfer.m
//  Scrcpy Remote
//
//  File transfer category for ScrcpyMenuView
//

#import "ScrcpyMenuView+FileTransfer.h"
#import "ScrcpyMenuView+Private.h"
#import "ADBClient.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <PhotosUI/PhotosUI.h>

@implementation ScrcpyMenuView (FileTransfer)

#pragma mark - ActionSheet for Source Selection

- (void)showSendFilesOrPhotosActionSheet {
    NSLog(@"📤 [ScrcpyMenuView] Showing Send Files or Photos ActionSheet");

    UIViewController *topVC = [self topViewController];
    if (!topVC) {
        NSLog(@"❌ [ScrcpyMenuView] Cannot present ActionSheet - no top view controller");
        return;
    }

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Send Files or Photos", nil)
                                                                         message:NSLocalizedString(@"Choose the source of files to send to the device", nil)
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    // Browse Files action
    UIAlertAction *browseFilesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Browse Files", nil)
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"📂 [ScrcpyMenuView] User selected Browse Files");
        [self showFilePicker];
    }];
    [actionSheet addAction:browseFilesAction];

    // Browse Photo Library action
    UIAlertAction *browsePhotosAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Browse Photo Library", nil)
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"🖼️ [ScrcpyMenuView] User selected Browse Photo Library");
        if (@available(iOS 14.0, *)) {
            [self showPhotoPicker];
        } else {
            NSLog(@"⚠️ [ScrcpyMenuView] Photo Library requires iOS 14.0 or later");
        }
    }];
    [actionSheet addAction:browsePhotosAction];

    // Cancel action
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"❌ [ScrcpyMenuView] User cancelled Send Files or Photos");
    }];
    [actionSheet addAction:cancelAction];

    // For iPad: configure popover presentation
    if (actionSheet.popoverPresentationController) {
        UIWindow *window = [self activeWindow];
        actionSheet.popoverPresentationController.sourceView = window;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(window.bounds.size.width / 2, window.bounds.size.height / 2, 0, 0);
        actionSheet.popoverPresentationController.permittedArrowDirections = 0;
    }

    [topVC presentViewController:actionSheet animated:YES completion:nil];
}

#pragma mark - Photo Picker

- (void)showPhotoPicker API_AVAILABLE(ios(14.0)) {
    NSLog(@"🖼️ [ScrcpyMenuView] Showing photo picker");

    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 0; // 0 means unlimited selection
    config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
        [PHPickerFilter imagesFilter],
        [PHPickerFilter videosFilter]
    ]];

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;

    UIViewController *topVC = [self topViewController];
    if (topVC) {
        [topVC presentViewController:picker animated:YES completion:nil];
    } else {
        NSLog(@"❌ [ScrcpyMenuView] Cannot present photo picker - no top view controller");
    }
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14.0)) {
    [picker dismissViewControllerAnimated:YES completion:nil];

    NSLog(@"🖼️ [ScrcpyMenuView] Picked %lu items from photo library", (unsigned long)results.count);

    if (results.count == 0) {
        return;
    }

    // Process selected items and get file URLs
    NSMutableArray<NSURL *> *fileURLs = [NSMutableArray array];
    dispatch_group_t group = dispatch_group_create();
    NSString *tempDir = NSTemporaryDirectory();

    for (PHPickerResult *result in results) {
        NSItemProvider *provider = result.itemProvider;

        // Check for image
        if ([provider hasItemConformingToTypeIdentifier:UTTypeImage.identifier]) {
            dispatch_group_enter(group);
            [provider loadFileRepresentationForTypeIdentifier:UTTypeImage.identifier completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (url && !error) {
                    // Copy to temp directory with original filename
                    NSString *fileName = url.lastPathComponent;
                    NSString *tempPath = [tempDir stringByAppendingPathComponent:fileName];
                    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];

                    // Remove existing file if needed
                    [[NSFileManager defaultManager] removeItemAtURL:tempURL error:nil];

                    NSError *copyError;
                    if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:tempURL error:&copyError]) {
                        @synchronized (fileURLs) {
                            [fileURLs addObject:tempURL];
                        }
                        NSLog(@"🖼️ [ScrcpyMenuView] Copied image to temp: %@", tempPath);
                    } else {
                        NSLog(@"❌ [ScrcpyMenuView] Failed to copy image: %@", copyError);
                    }
                } else {
                    NSLog(@"❌ [ScrcpyMenuView] Failed to load image: %@", error);
                }
                dispatch_group_leave(group);
            }];
        }
        // Check for video
        else if ([provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
            dispatch_group_enter(group);
            [provider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
                if (url && !error) {
                    // Copy to temp directory with original filename
                    NSString *fileName = url.lastPathComponent;
                    NSString *tempPath = [tempDir stringByAppendingPathComponent:fileName];
                    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];

                    // Remove existing file if needed
                    [[NSFileManager defaultManager] removeItemAtURL:tempURL error:nil];

                    NSError *copyError;
                    if ([[NSFileManager defaultManager] copyItemAtURL:url toURL:tempURL error:&copyError]) {
                        @synchronized (fileURLs) {
                            [fileURLs addObject:tempURL];
                        }
                        NSLog(@"🎬 [ScrcpyMenuView] Copied video to temp: %@", tempPath);
                    } else {
                        NSLog(@"❌ [ScrcpyMenuView] Failed to copy video: %@", copyError);
                    }
                } else {
                    NSLog(@"❌ [ScrcpyMenuView] Failed to load video: %@", error);
                }
                dispatch_group_leave(group);
            }];
        }
    }

    // Wait for all items to be loaded, then start transfer
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (fileURLs.count > 0) {
            NSLog(@"📤 [ScrcpyMenuView] Starting transfer of %lu photo/video items", (unsigned long)fileURLs.count);

            // Store file URLs and start transfer
            self.pendingFileURLs = [fileURLs mutableCopy];
            self.isFileTransferCancelled = NO;
            self.hasFileTransferError = NO;
            self.currentTransferIndex = 0;

            // Show progress popup
            [self showFileTransferProgress];

            // Start file transfer
            [self startFileTransfer];
        } else {
            NSLog(@"⚠️ [ScrcpyMenuView] No files to transfer after processing");
        }
    });
}

#pragma mark - File Picker

- (void)showFilePicker {
    NSLog(@"📂 [ScrcpyMenuView] Showing file picker");

    // Create document picker for selecting files
    NSArray *contentTypes = @[UTTypeItem, UTTypeData, UTTypeContent];
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
                                              initForOpeningContentTypes:contentTypes
                                              asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = YES;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;

    // Find the top view controller to present from
    UIViewController *topVC = [self topViewController];
    if (topVC) {
        [topVC presentViewController:picker animated:YES completion:nil];
    } else {
        NSLog(@"❌ [ScrcpyMenuView] Cannot present file picker - no top view controller");
    }
}

- (UIViewController *)topViewController {
    UIViewController *topVC = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow) {
                    topVC = window.rootViewController;
                    while (topVC.presentedViewController) {
                        topVC = topVC.presentedViewController;
                    }
                    return topVC;
                }
            }
        }
    }
    return topVC;
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSLog(@"📂 [ScrcpyMenuView] Picked %lu files", (unsigned long)urls.count);

    if (urls.count == 0) {
        return;
    }

    // Store file URLs and start transfer
    self.pendingFileURLs = [urls mutableCopy];
    self.isFileTransferCancelled = NO;
    self.hasFileTransferError = NO;
    self.currentTransferIndex = 0;

    // Show progress popup
    [self showFileTransferProgress];

    // Start file transfer
    [self startFileTransfer];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSLog(@"📂 [ScrcpyMenuView] File picker cancelled");
}

#pragma mark - File Transfer Progress UI

- (void)showFileTransferProgress {
    NSLog(@"📤 [ScrcpyMenuView] Showing file transfer progress popup");

    UIWindow *window = [self activeWindow];
    if (!window) return;

    // Initialize dictionaries
    self.fileProgressViews = [NSMutableDictionary dictionary];
    self.fileStatusLabels = [NSMutableDictionary dictionary];

    // Calculate popup size
    CGFloat popupWidth = 320.0;
    CGFloat rowHeight = 60.0;
    CGFloat headerHeight = 50.0;
    CGFloat cancelButtonHeight = 50.0;
    CGFloat padding = 16.0;
    CGFloat maxContentHeight = MIN(self.pendingFileURLs.count * rowHeight, 300.0);
    CGFloat popupHeight = headerHeight + maxContentHeight + cancelButtonHeight + padding * 2;

    // Create popup container
    self.fileTransferPopupView = [[UIView alloc] init];
    self.fileTransferPopupView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.95];
    self.fileTransferPopupView.layer.cornerRadius = 16.0;
    self.fileTransferPopupView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.fileTransferPopupView.layer.shadowOffset = CGSizeMake(0, 4);
    self.fileTransferPopupView.layer.shadowOpacity = 0.4;
    self.fileTransferPopupView.layer.shadowRadius = 10.0;

    // Center the popup
    CGFloat popupX = (window.bounds.size.width - popupWidth) / 2;
    CGFloat popupY = (window.bounds.size.height - popupHeight) / 2;
    self.fileTransferPopupView.frame = CGRectMake(popupX, popupY, popupWidth, popupHeight);

    // Header label
    self.fileTransferHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, padding, popupWidth - padding * 2, 30)];
    self.fileTransferHeaderLabel.text = [NSString stringWithFormat:@"📤 Sending %lu file(s)...", (unsigned long)self.pendingFileURLs.count];
    self.fileTransferHeaderLabel.textColor = [UIColor whiteColor];
    self.fileTransferHeaderLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    self.fileTransferHeaderLabel.textAlignment = NSTextAlignmentCenter;
    [self.fileTransferPopupView addSubview:self.fileTransferHeaderLabel];

    // Scroll view for file list
    self.fileTransferScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(padding, headerHeight, popupWidth - padding * 2, maxContentHeight)];
    self.fileTransferScrollView.showsVerticalScrollIndicator = YES;
    [self.fileTransferPopupView addSubview:self.fileTransferScrollView];

    // Add file rows
    CGFloat yOffset = 0;
    for (NSInteger i = 0; i < (NSInteger)self.pendingFileURLs.count; i++) {
        NSURL *fileURL = self.pendingFileURLs[i];
        NSString *fileName = fileURL.lastPathComponent;
        NSString *fileKey = [NSString stringWithFormat:@"%ld", (long)i];

        // File row container
        UIView *rowView = [[UIView alloc] initWithFrame:CGRectMake(0, yOffset, self.fileTransferScrollView.bounds.size.width, rowHeight - 4)];

        // File name label
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 4, rowView.bounds.size.width, 22)];
        nameLabel.text = fileName;
        nameLabel.textColor = [UIColor whiteColor];
        nameLabel.font = [UIFont systemFontOfSize:14.0];
        nameLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [rowView addSubview:nameLabel];

        // Progress view
        UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        progressView.frame = CGRectMake(0, 30, rowView.bounds.size.width, 4);
        progressView.progressTintColor = [UIColor systemBlueColor];
        progressView.trackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        progressView.progress = 0.0;
        [rowView addSubview:progressView];
        self.fileProgressViews[fileKey] = progressView;

        // Status label
        UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 38, rowView.bounds.size.width, 18)];
        statusLabel.text = NSLocalizedString(@"Waiting...", nil);
        statusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
        statusLabel.font = [UIFont systemFontOfSize:12.0];
        [rowView addSubview:statusLabel];
        self.fileStatusLabels[fileKey] = statusLabel;

        [self.fileTransferScrollView addSubview:rowView];
        yOffset += rowHeight;
    }
    self.fileTransferScrollView.contentSize = CGSizeMake(self.fileTransferScrollView.bounds.size.width, yOffset);

    // Cancel/Close button (capsule shape)
    CGFloat cancelButtonWidth = 120.0;
    self.fileTransferCloseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.fileTransferCloseButton.frame = CGRectMake((popupWidth - cancelButtonWidth) / 2, popupHeight - cancelButtonHeight - padding + 8, cancelButtonWidth, 36);
    self.fileTransferCloseButton.backgroundColor = [UIColor systemRedColor];
    self.fileTransferCloseButton.layer.cornerRadius = 18.0;
    [self.fileTransferCloseButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [self.fileTransferCloseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fileTransferCloseButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightMedium];
    [self.fileTransferCloseButton addTarget:self action:@selector(cancelFileTransfer) forControlEvents:UIControlEventTouchUpInside];
    [self.fileTransferPopupView addSubview:self.fileTransferCloseButton];

    // Initial state
    self.fileTransferPopupView.alpha = 0.0;
    self.fileTransferPopupView.transform = CGAffineTransformMakeScale(0.9, 0.9);

    [window addSubview:self.fileTransferPopupView];

    // Animate in
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
        self.fileTransferPopupView.alpha = 1.0;
        self.fileTransferPopupView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)hideFileTransferProgress {
    if (!self.fileTransferPopupView) return;

    [UIView animateWithDuration:0.2 animations:^{
        self.fileTransferPopupView.alpha = 0.0;
        self.fileTransferPopupView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [self.fileTransferPopupView removeFromSuperview];
        self.fileTransferPopupView = nil;
        self.fileTransferScrollView = nil;
        self.fileProgressViews = nil;
        self.fileStatusLabels = nil;
        self.pendingFileURLs = nil;
        self.fileTransferCloseButton = nil;
        self.fileTransferHeaderLabel = nil;
    }];
}

- (void)cancelFileTransfer {
    NSLog(@"❌ [ScrcpyMenuView] File transfer cancelled by user");
    self.isFileTransferCancelled = YES;
    [self hideFileTransferProgress];
}

- (void)updateFileProgress:(NSInteger)fileIndex progress:(float)progress status:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *fileKey = [NSString stringWithFormat:@"%ld", (long)fileIndex];
        UIProgressView *progressView = self.fileProgressViews[fileKey];
        UILabel *statusLabel = self.fileStatusLabels[fileKey];

        if (progressView) {
            [progressView setProgress:progress animated:YES];
        }
        if (statusLabel) {
            statusLabel.text = status;
            if ([status containsString:@"Complete"]) {
                statusLabel.textColor = [UIColor systemGreenColor];
            } else if ([status containsString:@"Failed"] || [status containsString:@"Cancelled"]) {
                statusLabel.textColor = [UIColor systemRedColor];
            }
        }
    });
}

#pragma mark - ADB File Transfer

- (void)startFileTransfer {
    if (self.isFileTransferCancelled) {
        return;
    }

    if (self.currentTransferIndex >= (NSInteger)self.pendingFileURLs.count) {
        NSLog(@"✅ [ScrcpyMenuView] All files transfer attempts completed");
        [self updateFileTransferCompletionUI];
        return;
    }

    NSURL *fileURL = self.pendingFileURLs[self.currentTransferIndex];
    [self transferFile:fileURL atIndex:self.currentTransferIndex];
}

- (void)updateFileTransferCompletionUI {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Update header
        if (self.hasFileTransferError) {
            self.fileTransferHeaderLabel.text = @"⚠️ Transfer Complete (with errors)";
            self.fileTransferHeaderLabel.textColor = [UIColor systemOrangeColor];
        } else {
            self.fileTransferHeaderLabel.text = @"✅ Transfer Complete";
            self.fileTransferHeaderLabel.textColor = [UIColor systemGreenColor];
        }

        // Update button to "Close" with appropriate color
        [UIView animateWithDuration:0.2 animations:^{
            [self.fileTransferCloseButton setTitle:@"Close" forState:UIControlStateNormal];
            self.fileTransferCloseButton.backgroundColor = self.hasFileTransferError ?
                [UIColor systemOrangeColor] : [UIColor systemGreenColor];
        }];
    });
}

- (void)transferFile:(NSURL *)fileURL atIndex:(NSInteger)index {
    NSLog(@"📤 [ScrcpyMenuView] Transferring file %ld: %@", (long)index, fileURL.lastPathComponent);

    // Update status to "Transferring..."
    [self updateFileProgress:index progress:0.1 status:NSLocalizedString(@"Transferring...", nil)];

    // Start security-scoped access
    BOOL accessGranted = [fileURL startAccessingSecurityScopedResource];
    if (!accessGranted) {
        NSLog(@"⚠️ [ScrcpyMenuView] Could not access security scoped resource");
    }

    // Get file path
    NSString *localPath = fileURL.path;
    NSString *fileName = fileURL.lastPathComponent;

    // Get default path from settings
    NSString *defaultPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"settings.send_files.default_path"];
    if (!defaultPath || defaultPath.length == 0) {
        defaultPath = @"/sdcard/Download";
    }
    NSString *remotePath = [NSString stringWithFormat:@"%@/%@", defaultPath, fileName];

    NSLog(@"📤 [ScrcpyMenuView] ADB push: %@ -> %@", localPath, remotePath);

    // Build ADB push command (no need for -s flag, ADB uses the connected device)
    NSArray *command = @[@"push", localPath, remotePath];

    // Execute ADB command asynchronously
    __weak typeof(self) weakSelf = self;
    [[ADBClient shared] executeADBCommandAsync:command callback:^(NSString * _Nullable output, int returnCode) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // Stop security-scoped access
        if (accessGranted) {
            [fileURL stopAccessingSecurityScopedResource];
        }

        if (strongSelf.isFileTransferCancelled) {
            [strongSelf updateFileProgress:index progress:0.0 status:@"Cancelled"];
            return;
        }

        if (returnCode == 0) {
            NSLog(@"✅ [ScrcpyMenuView] File transferred successfully: %@", fileName);
            NSString *successStatus = [NSString stringWithFormat:@"✓ %@", remotePath];
            [strongSelf updateFileProgress:index progress:1.0 status:successStatus];
        } else {
            NSLog(@"❌ [ScrcpyMenuView] File transfer failed: %@ - %@", fileName, output);
            strongSelf.hasFileTransferError = YES;
            NSString *errorStatus = [NSString stringWithFormat:@"✗ %@", output ?: NSLocalizedString(@"Unknown error", nil)];
            if (errorStatus.length > 50) {
                errorStatus = [[errorStatus substringToIndex:47] stringByAppendingString:@"..."];
            }
            [strongSelf updateFileProgress:index progress:0.0 status:errorStatus];
        }

        // Transfer next file
        [strongSelf transferNextFile];
    }];

    // Simulate progress while waiting (since ADB doesn't provide progress)
    [self simulateProgressForFile:index];
}

- (void)simulateProgressForFile:(NSInteger)index {
    // Simulate progress updates while waiting for transfer
    __weak typeof(self) weakSelf = self;
    __block float progress = 0.1;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (progress < 0.9) {
            if (weakSelf.isFileTransferCancelled) break;
            if (weakSelf.currentTransferIndex != index) break;

            usleep(200000); // 200ms
            progress += 0.05;
            if (progress > 0.9) progress = 0.9;

            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (!strongSelf || strongSelf.isFileTransferCancelled) return;
                if (strongSelf.currentTransferIndex != index) return;

                NSString *fileKey = [NSString stringWithFormat:@"%ld", (long)index];
                UIProgressView *progressView = strongSelf.fileProgressViews[fileKey];
                UILabel *statusLabel = strongSelf.fileStatusLabels[fileKey];
                if (progressView && statusLabel && [statusLabel.text isEqualToString:NSLocalizedString(@"Transferring...", nil)]) {
                    [progressView setProgress:progress animated:YES];
                }
            });
        }
    });
}

- (void)transferNextFile {
    self.currentTransferIndex++;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startFileTransfer];
    });
}

@end
