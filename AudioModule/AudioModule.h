//
//  AudioModule.h
//  moffice
//
//  Created by 30san on 2018/3/12.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#import "VoiceConverter.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AudioModule : RCTEventEmitter <RCTBridgeModule>
{
  NSTimer *m_Timer;
  double m_urrentTime;
  NSMutableString *m_recordingPath;
  NSMutableString *m_recordingFile;
  NSMutableString *m_playingFile;
}
@property (strong, nonatomic) AVAudioRecorder  *recorder;
@property (strong, nonatomic) AVAudioPlayer    *player;
@property (strong, nonatomic) NSString         *wavFilePath;

@end
