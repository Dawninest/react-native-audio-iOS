//
//  AudioModule.m
//  moffice
//
//  Created by 30san on 2018/3/12.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import "AudioModule.h"

@implementation AudioModule

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents{
  return @[@"onRecording",@"onPlaying"];
}

// 开始录音
RCT_EXPORT_METHOD(startRecordingAudio:(NSString *)savePath
                  mediaId:(NSString *)mediaId
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  dispatch_async(dispatch_get_main_queue(), ^{
    [self startRecording:savePath mediaId:mediaId options:options resolver:resolve rejecter:reject];
  });
}

// 结束录音
RCT_EXPORT_METHOD(stopRecordingAudio:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  dispatch_async(dispatch_get_main_queue(), ^{
     [self stopRecording:resolve rejecter:reject];
  });
}

// 开始播放
RCT_EXPORT_METHOD(startPlayingAudio:(NSString *)audioPath
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  dispatch_async(dispatch_get_main_queue(), ^{
    [self startPlaying:audioPath resolver:resolve rejecter:reject];
  });
}
// 结束播放
RCT_EXPORT_METHOD(stopPlayingAudio:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject){
  dispatch_async(dispatch_get_main_queue(), ^{
    [self stopPlaying:resolve rejecter:reject];
  });
}

#pragma mark -- startRecording --
- (void)startRecording:(NSString *)savePath
               mediaId:(NSString *)mediaId
               options:(NSDictionary *)options
              resolver:(RCTPromiseResolveBlock)resolve
              rejecter:(RCTPromiseRejectBlock)reject{
  NSError *audioSessionError;
  NSError *recorderInitError;
  if (self.recorder.isRecording) {
    [self stopTimer];
    [self.recorder stop];
    return;
  }
  if(self.player.isPlaying){
    [self stopTimer];
    [self.player stop];
    [self deleteWavFile];
  }
  m_recordingPath = [[NSMutableString alloc] initWithString:savePath];
  m_recordingFile = [[NSMutableString alloc] initWithString:mediaId];
  NSString *errorStr = [[NSString alloc] init];
  if(m_recordingPath != nil){
    if([m_recordingPath hasPrefix:@"file://"]){
      [m_recordingPath deleteCharactersInRange:NSMakeRange(0, 7)];
    }
    NSFileManager *fileManger = [NSFileManager defaultManager];
    if(![fileManger fileExistsAtPath:m_recordingPath]){
      [fileManger createDirectoryAtPath:m_recordingPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    if(m_recordingFile!=nil&&![m_recordingFile isEqual:@""]){
      if([m_recordingPath hasSuffix:@"/"]){
        self.wavFilePath = [[[m_recordingPath stringByAppendingString:m_recordingFile] stringByAppendingPathExtension:@"wav"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
      }else{
        self.wavFilePath = [[[[m_recordingPath stringByAppendingString:@"/" ] stringByAppendingString:m_recordingFile] stringByAppendingPathExtension:@"wav"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
      }
      
    } else{
      errorStr=@"audioName is invalid";
    }
  } else {
    errorStr=@"audioPath is null";
  }
  if([errorStr isEqual:@""]) {
    if(self.recorder == nil){
      self.recorder = [[AVAudioRecorder alloc]initWithURL:[NSURL fileURLWithPath:self.wavFilePath] settings:[VoiceConverter GetAudioRecorderSettingDict] error:&recorderInitError];
    }
    m_urrentTime = 0;
    if ([self.recorder prepareToRecord]) {//准备录音
      BOOL canRecord =[self canRecord];//录音权限判断，无权限则去设置
      if (canRecord) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&audioSessionError];
        [[AVAudioSession sharedInstance] setActive:YES error:&audioSessionError];
        self.recorder.meteringEnabled = YES;
        [self.recorder.delegate self];
        [self.recorder record];//开始录音 
        [self startRecordingSuccesss];
        m_Timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(updateRecordingInfo) userInfo:NULL repeats:YES];
        resolve(@"record start");
      }else{
          reject(@"can't record",NULL,NULL);
      }
    } else {
      reject(@"audioPath is invalid",NULL,NULL);
    }
  } else {
    if (recorderInitError) {
      reject([recorderInitError localizedDescription],NULL,NULL);
    } else if (audioSessionError) {
      reject([audioSessionError localizedDescription],NULL,NULL);
    } else {
      reject(errorStr,NULL,NULL);
    }
  }
}

-(void)stopTimer{
  if(m_Timer != nil){
    [m_Timer invalidate];
  }
}

- (void)deleteWavFile{
  NSFileManager * fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:self.wavFilePath]) {
    NSError * error;
    [fileManager removeItemAtPath:self.wavFilePath error:&error];
  }
}

#pragma mark - 录音权限判断-7.0之后可用
- (BOOL)canRecord{
  __block BOOL bCanRecord = YES;
  if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0){
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if ([audioSession respondsToSelector:@selector(requestRecordPermission:)]) {
      [audioSession performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
        if (granted) {
          bCanRecord = YES;
        } else {
          bCanRecord = NO;
        }
      }];
    }
  }
  if (bCanRecord == NO) {//无权限则提供跳转到设置界面去设置，暂时不给这里取消去跳转
    [self textAlertWithTitle:nil message:@"需要获取您的麦克风权限" buttionName:@"去设置" handler:^(UIAlertAction *action) {
      NSURL * url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
      if([[UIApplication sharedApplication] canOpenURL:url]) {
        NSURL*url =[NSURL URLWithString:UIApplicationOpenSettingsURLString];
        [[UIApplication sharedApplication] openURL:url];
      }
    } cancelButtonName:@"取消"];
    return NO;
  }else{
    return YES;
  }
}

- (void)startRecordingSuccesss{
  // 开始录音
  [self sendEventWithName:@"onRecording" body:@{@"currentTime":[NSString stringWithFormat:@"%d", 0] ,@"amplitude":[NSString stringWithFormat:@"%d", 0]}];
}

- (void)updateRecordingInfo {
  if(self.recorder.isRecording){
    m_urrentTime +=0.2;
    float amplitude = 0;
    [self.recorder updateMeters];
    float minDecibels = -60.0f;
    float decibels = [self.recorder averagePowerForChannel:0];
    if (decibels < minDecibels) {
      amplitude = 0.0f;
    } else if (decibels >= 0.0f) {
      amplitude = 8.0f;
    } else {
      float root = 2.0f;
      float minAmp = powf(10.0f, 0.05f * minDecibels);
      float inverseAmpRange = 1.0f / (1.0f - minAmp);
      float amp = powf(10.0f, 0.05f * decibels);
      float adjAmp = (amp - minAmp) * inverseAmpRange;
      amplitude = powf(adjAmp, 1.0f / root)*8;
    }
    [self sendEventWithName:@"onRecording" body:@{@"currentTime":[NSString stringWithFormat:@"%f", m_urrentTime],@"amplitude":[NSString stringWithFormat:@"%d", (int)amplitude]}];
  }
}


#pragma mark -- stopRecording --
- (void)stopRecording:(RCTPromiseResolveBlock)resolve
             rejecter:(RCTPromiseRejectBlock)reject{
  NSMutableDictionary *audioParam = [[NSMutableDictionary alloc] init];
  NSString *amrPath = [[NSString alloc] init];
  if (self.recorder.isRecording) {//录音中
    [self stopTimer];
    [self.recorder stop];//停止录音
    self.recorder = nil;
    //#pragma wav转amr
    amrPath = [self.wavFilePath stringByDeletingPathExtension];
    if ([NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@.wav",amrPath]]) {
      [VoiceConverter ConvertWavToAmr:self.wavFilePath amrSavePath:amrPath];
      [audioParam setObject:m_recordingPath forKey:@"audioPath"];
      [audioParam setObject:m_recordingFile forKey:@"fileName"];
      [audioParam setObject:[[self getVoiceFileInfoByPath:self.wavFilePath] objectForKey:@"duration"] forKey:@"duration"];
      [self deleteWavFile];
      resolve(audioParam);
      [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }else{
      reject(@"iOS recorder is not recording",NULL,NULL);
    }
  } else{
    reject(@"iOS recorder is not recording",NULL,NULL);
  }
}
#pragma mark -- startPlaying --
- (void)startPlaying:(NSString *)audioPath
            resolver:(RCTPromiseResolveBlock)resolve
            rejecter:(RCTPromiseRejectBlock)reject{
  NSLog(@"begin to play audio file!");
  NSError *audioSessionError;
  NSError *playerInitError;
  NSFileManager *file = [NSFileManager defaultManager];
  NSString *errorStr = [[NSString alloc] init];
  if (self.recorder.isRecording) {
    [self stopTimer];
    [self.recorder stop];
  }
  if(self.player.isPlaying){
    [self stopTimer];
    [self.player stop];
  }
  if ([audioPath isKindOfClass:[NSString class]]) {
    m_playingFile = [[NSMutableString alloc] initWithString:audioPath];
    if ([m_playingFile hasPrefix:@"file://"]) {
      [m_playingFile deleteCharactersInRange:NSMakeRange(0, 7)];
    }
    self.wavFilePath=[[[NSMutableString alloc] initWithString:m_playingFile] stringByAppendingString:@".wav"];
    if ([file fileExistsAtPath:m_playingFile]) {
      [[AVAudioSession sharedInstance] setActive:YES error:&audioSessionError];
      [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:&audioSessionError];
      //amr转wav
      if ([VoiceConverter ConvertAmrToWav:m_playingFile wavSavePath:self.wavFilePath]) {
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:self.wavFilePath] error:&playerInitError];
      }else{
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL URLWithString:m_playingFile] error:&playerInitError];
      }
      [self.player.delegate self];
      [self.player play];
      [self startPlayingSuccesss];
      m_Timer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(updatePlayingInfo) userInfo:NULL repeats:YES];
    } else {
      errorStr = @"语音不存在";
    }
  } else {
    errorStr = @"audio URL must be a string variable!";
  }
  if (errorStr.length > 0) {
    reject(errorStr,NULL,NULL);
  } else if (audioSessionError) {
    reject([audioSessionError localizedDescription],NULL,NULL);
  } else if (playerInitError) {
    reject([playerInitError localizedDescription],NULL,NULL);
  }
}

- (void)startPlayingSuccesss{
  [self sendEventWithName:@"onPlaying" body:@{@"currentTime":[NSString stringWithFormat:@"%d", 0],@"duration":[NSString stringWithFormat:@"%f", self.player.duration]}];
}

- (void)updatePlayingInfo{
  if(self.player.isPlaying){
    if(self.player.currentTime > 0){
      [self sendEventWithName:@"onPlaying" body:@{@"currentTime":[NSString stringWithFormat:@"%f", self.player.currentTime],@"duration":[NSString stringWithFormat:@"%f", self.player.duration]}];
    }
  } else {
    [self sendEventWithName:@"onPlaying" body:@{@"currentTime":[NSString stringWithFormat:@"%d", -1],@"duration":[NSString stringWithFormat:@"%f", self.player.duration]}];
    [self stopTimer];
    [self deleteWavFile];
  }
}

#pragma mark -- startPlaying --
- (void)stopPlaying:(RCTPromiseResolveBlock)resolve
           rejecter:(RCTPromiseRejectBlock)reject{
  NSMutableDictionary *audioParam = [[NSMutableDictionary alloc] init];
  if(self.player.isPlaying){
    [audioParam setObject:m_playingFile forKey:@"fileURL"];
    [self stopTimer];
    [self.player stop];
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
    resolve(audioParam);
    [self deleteWavFile];
  } else{
    resolve(@"the player is not playing");
  }
}

#pragma mark - tool
- (void)textAlertWithTitle:(NSString *)title message:(NSString *)message buttionName:(NSString *)buttionName handler:(void (^ __nullable)(UIAlertAction *action))handler cancelButtonName:(NSString *)cancelButtonName{
  UIAlertController *canRecordController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
  [canRecordController addAction:[UIAlertAction actionWithTitle:buttionName style:UIAlertActionStyleDefault handler:handler]];
  [canRecordController addAction:[UIAlertAction actionWithTitle:cancelButtonName style:UIAlertActionStyleDefault handler:nil]];
  UIViewController *currentViewController = [self getCurrentViewController];
  [currentViewController presentViewController:canRecordController animated:YES completion:nil];
}

//获取当前viewcontroller
- (UIViewController *)getCurrentViewController{
  UIViewController *currentViewController = nil;
  UIWindow *window = [[UIApplication sharedApplication]keyWindow];
  if (window.windowLevel != UIWindowLevelNormal) {
    NSArray *windows = [[UIApplication sharedApplication]windows];
    for (UIWindow *tmpWin in windows) {
      if (tmpWin.windowLevel == UIWindowLevelNormal) {
        window = tmpWin;
        break;
      }
    }
  }
  UIView *frontView = [[window subviews]objectAtIndex:0];
  id nextResponder = [frontView nextResponder];
  if ([nextResponder isKindOfClass:[UIViewController class]]) {
    currentViewController = nextResponder;
  }else{
    currentViewController = window.rootViewController;
  }
  return currentViewController;
}

#pragma mark - 获取音频文件信息
- (NSMutableDictionary *)getVoiceFileInfoByPath:(NSString *)filePath {
  NSFileManager *filemanager = [[NSFileManager alloc] init];
  NSMutableDictionary *attributes;
  NSString *duration;
  if ([filemanager fileExistsAtPath:filePath]) {
    attributes = [[NSMutableDictionary alloc] initWithDictionary:[filemanager attributesOfItemAtPath:filePath error:nil]];
  }
  NSRange range = [filePath rangeOfString:@"wav"];
  if (range.length > 0) {
    AVAudioPlayer *play = [[AVAudioPlayer alloc]initWithContentsOfURL:[NSURL URLWithString:filePath] error:nil];
    duration = [[NSString alloc] initWithFormat:@"%d", (int)play.duration];
  }
  [attributes setObject:duration forKey:@"duration"];
  return attributes;
}

@end
