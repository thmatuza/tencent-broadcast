//
//  TencentAudioProcessCallback.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/09.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import Foundation
import TXLiteAVSDK_Professional
import VideoCast

class TencentAudioProcessCallback: NSObject, TXAudioCustomProcessDelegate {
    weak var source: TencentSource?

    func onRecordPcmData(_ data: Data!, timeStamp: UInt64, sampleRate: Int32, channels: Int32) {
        Logger.debug("onRecordPcmData \(timeStamp), \(sampleRate), \(channels)")
        source?.audioBufferCaptured(data, timeStamp: timeStamp, sampleRate: sampleRate, channels: channels)
    }

    func onRecordRawPcmData(_ data: Data!, timeStamp: UInt64, sampleRate: Int32, channels: Int32, withBgm: Bool) {
        Logger.debug("onRecordRawPcmData \(timeStamp), \(sampleRate), \(channels)")
    }
}
