//
//  MicSource.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/01/09.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

import Foundation
import AVFoundation

/*!
 *  Capture audio from the device's microphone.
 *
 */
open class MicSource: ISource {
    open func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self).hashValue)
    }

    public static func == (lhs: MicSource, rhs: MicSource) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    open var filter: IFilter?
    open var audioUnit: AudioUnit? {
        return _audioUnit
    }

    private var interruptionHandler: InterruptionHandler?

    private var _audioUnit: AudioComponentInstance?
    private var component: AudioComponent?

    private let sampleRate: Double
    private var channelCount: Int

    private weak var output: IOutput?

    private let handleInputBuffer: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        inNumberFrames,
        ioData ) -> OSStatus in
        let mc = unsafeBitCast(inRefCon, to: MicSource.self)
        guard let audioUnit = mc.audioUnit else {
            Logger.debug("unexpected return")
            return 0
        }

        let buffer = AudioBuffer(mNumberChannels: 2, mDataByteSize: 0, mData: nil)

        var buffers = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)

        let status = AudioUnitRender(audioUnit,
                                     ioActionFlags,
                                     inTimeStamp,
                                     inBusNumber,
                                     inNumberFrames,
                                     &buffers)

        guard status == noErr else {
            Logger.debug("unexpected return: \(status)")
            return status
        }
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(&buffers)

        mc.inputCallback(data: inputDataPtr[0].mData, data_size:
            Int(inputDataPtr[0].mDataByteSize), inNumberFrames: Int(inNumberFrames))

        return status
    }

    /*!
     *  Constructor.
     *
     *  \param audioSampleRate the sample rate in Hz to capture audio at.
     *         Best results if this matches the mixer's sampling rate.
     *  \param excludeAudioUnit An optional lambda method that is called when the source generates its Audio Unit.
     *                          The parameter of this method will be a reference to its Audio Unit.  This is useful for
     *                          applications that may be capturing Audio Unit data and
     *                          do not wish to capture this source.
     *
     */
    // swiftlint:disable:next function_body_length
    public init(sampleRate: Double = 48000,
                preferedChannelCount: Int = 2,
                excludeAudioUnit: ((AudioUnit) -> Void)? = nil,
                mode: AVAudioSession.Mode = .default) {
        self.sampleRate = sampleRate
        self.channelCount = preferedChannelCount

        let session = AVAudioSession.sharedInstance()

        let permission = { [weak self] (granted: Bool) in
            guard let strongSelf = self else { return }

            if granted {

                do {
                    try session.setCategory(.playAndRecord,
                                            options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
                    try session.setActive(true)
                } catch {
                    Logger.error("Failed to set up audio session: \(error)")
                    return
                }

                do {
                    try session.setMode(mode)
                } catch {
                    Logger.error("Failed to set mode: \(error)")
                }

                do {
                    try session.setPreferredInputNumberOfChannels(preferedChannelCount)
                } catch {
                    Logger.info("Failed to set preferred input number of channels: \(error)")
                }

                let channelCount = session.inputNumberOfChannels
                strongSelf.channelCount = channelCount

                var acd = AudioComponentDescription(
                    componentType: kAudioUnitType_Output,
                    componentSubType: kAudioUnitSubType_RemoteIO,
                    componentManufacturer: kAudioUnitManufacturer_Apple,
                    componentFlags: 0,
                    componentFlagsMask: 0)

                strongSelf.component = AudioComponentFindNext(nil, &acd)

                guard let component = strongSelf.component else {
                    Logger.debug("unexpected return")
                    return
                }
                AudioComponentInstanceNew(component, &strongSelf._audioUnit)
                guard let audioUnit = strongSelf._audioUnit else {
                    Logger.error("AudioComponentInstanceNew failed")
                    return
                }

                excludeAudioUnit?(audioUnit)
                var flagOne: UInt32 = 1

                AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input, 1, &flagOne, UInt32(MemoryLayout<UInt32>.size))

                var desc = AudioStreamBasicDescription()
                desc.mSampleRate = sampleRate
                desc.mFormatID = kAudioFormatLinearPCM
                desc.mFormatFlags =
                    kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
                desc.mChannelsPerFrame = UInt32(channelCount)
                desc.mFramesPerPacket = 1
                desc.mBitsPerChannel = 16
                desc.mBytesPerFrame = desc.mBitsPerChannel / 8 * desc.mChannelsPerFrame
                desc.mBytesPerPacket = desc.mBytesPerFrame * desc.mFramesPerPacket

                var cb = AURenderCallbackStruct(
                    inputProc: strongSelf.handleInputBuffer,
                    inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(strongSelf).toOpaque()))
                AudioUnitSetProperty(
                    audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &desc,
                    UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
                AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_SetInputCallback,
                                     kAudioUnitScope_Global, 1, &cb,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))

                strongSelf.interruptionHandler = InterruptionHandler()
                strongSelf.interruptionHandler?.source = self

                if let interruptionHandler = strongSelf.interruptionHandler {
                    NotificationCenter.default.addObserver(
                        interruptionHandler,
                        selector: #selector(InterruptionHandler.handleInterruption(notification:)),
                        name: AVAudioSession.interruptionNotification, object: nil
                    )
                }

                AudioUnitInitialize(audioUnit)
                let ret = AudioOutputUnitStart(audioUnit)
                if ret != noErr {
                    Logger.error("Failed to start microphone!")
                }
            }
        }

        session.requestRecordPermission(permission)
    }

    deinit {
        stop()
    }

    open func stop() {
        if let audioUnit = _audioUnit {
            if let interruptionHandler = interruptionHandler {
                NotificationCenter.default.removeObserver(interruptionHandler)
                interruptionHandler.source = nil
            }

            AudioOutputUnitStop(audioUnit)
            AudioComponentInstanceDispose(audioUnit)
            _audioUnit = nil
        }
    }

    /*! ISource::setOutput */
    open func setOutput(_ output: IOutput) {
        self.output = output
        if let mixer = output as? IAudioMixer {
            mixer.registerSource(self)
        }
    }

    /*! Used by the Audio Unit as a callback method */
    open func inputCallback(data: UnsafeMutableRawPointer?, data_size: Int, inNumberFrames: Int) {
        guard let output = output, let data = data else {
            Logger.debug("unexpected return")
            return
        }

        let md = AudioBufferMetadata()

        md.data = (Int(sampleRate),
                   16,
                   channelCount,
                   AudioFormatFlags(kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked),
                   channelCount * 2,
                   inNumberFrames,
                   false,
                   false,
                   WeakRefISource(value: self)
        )

        output.pushBuffer(data, size: data_size, metadata: md)
    }

    open func interruptionBegan() {
        guard let audioUnit = audioUnit else {
            Logger.debug("unexpected return")
            return
        }
        Logger.debug("interruptionBegan")
        AudioOutputUnitStart(audioUnit)
    }

    open func interruptionEnded() {
        guard let audioUnit = audioUnit else {
            Logger.debug("unexpected return")
            return
        }
        Logger.debug("interruptionEnded")
        AudioOutputUnitStart(audioUnit)
    }
}

private class InterruptionHandler: NSObject {
    public var source: MicSource?

    @objc func handleInterruption(notification: Notification) {
        guard let interuptionType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] else {
            Logger.debug("unexpected return")
            return
        }
        let interuptionVal = AVAudioSession.InterruptionType(
            rawValue: (interuptionType as AnyObject).uintValue )

        if interuptionVal == .began {
            source?.interruptionBegan()
        } else {
            source?.interruptionEnded()
        }
    }
}
