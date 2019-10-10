//
//  TencentSource.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/04.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import GLKit
import VideoCast
import TXLiteAVSDK_Professional
import GPUImage

enum HomeOrientation: Int32 {
    case right = 0
    case down
    case left
    case up
}

class TencentSource: ISource {
    var filter: IFilter?
    var orientationLocked: Bool = false
    var deviceOrientation: UIDeviceOrientation = .portrait

    private var matrix: GLKMatrix4 = GLKMatrix4Identity

    private weak var videoOutput: IOutput?
    private weak var audioOutput: IOutput?

    private var callbackSession: TencentVideoProcessCallback?
    private var audioCallbackSession: TencentAudioProcessCallback?

    private var fps: Int = 0

    private var txLivePublisher: TXLivePush?
    private var isFlash = false

    private var preViewContainer: UIView?

    public init() {
    }

    deinit {
        callbackSession = nil
        audioCallbackSession = nil
    }

    func setOutput(_ output: IOutput) {
        assertionFailure("use setVideoOutput or setAudioOutput")
    }

    func setVideoOutput(_ output: IOutput) {
        self.videoOutput = output
    }

    func setAudioOutput(_ output: IOutput) {
        self.audioOutput = output
    }

    func setupCamera(preViewContainer: UIView?, fps: Int = 15, useFront: Bool = true,
                     useInterfaceOrientation: Bool = false) {
        let config = TXLivePushConfig()
        config.videoFPS = Int32(fps)
        config.frontCamera = useFront
        config.customModeType = CUSTOM_MODE_AUDIO_CAPTURE | CUSTOM_MODE_VIDEO_PREPROCESS
        syncSafe {
            let txLivePublisher = TXLivePush(config: config)

            let callbackSession: TencentVideoProcessCallback = .init()
            callbackSession.source = self
            txLivePublisher?.videoProcessDelegate = callbackSession
            self.callbackSession = callbackSession
            
            if !orientationLocked {
                NotificationCenter.default.addObserver(
                    callbackSession,
                    selector:
                    #selector(type(of: callbackSession).orientationChanged(notification:)),
                    name: UIApplication.didChangeStatusBarOrientationNotification,
                    object: nil)
            }

            // AudioProcessDelegate doesn't work yet
            audioCallbackSession = .init()
            audioCallbackSession?.source = self
            txLivePublisher?.audioProcessDelegate = audioCallbackSession

            if preViewContainer == nil {
                self.preViewContainer = UIView(frame: CGRect(x: 0, y: 0, width: 720, height: 1280))
            } else {
                self.preViewContainer = preViewContainer
            }
            txLivePublisher?.startPreview(self.preViewContainer)
            self.txLivePublisher = txLivePublisher
        }
    }

    func toggleCamera() {
        txLivePublisher?.switchCamera()
    }

    func setTorch(_ torchOn: Bool) -> Bool {
        guard let txLivePublisher = txLivePublisher else {
            return false
        }
        let ret = txLivePublisher.toggleTorch(torchOn)
        if ret {
            isFlash = torchOn
        }
        return isFlash
    }
    
    func setOrientation(_ portrait: Bool) {
        guard let txLivePublisher = txLivePublisher else {
            return
        }

        if portrait {
            if let config = txLivePublisher.config {
                config.homeOrientation = HomeOrientation.down.rawValue
                txLivePublisher.config = config
                
                txLivePublisher.setRenderRotation(0)
            }
        } else {
            if let config = txLivePublisher.config {
                config.homeOrientation = HomeOrientation.right.rawValue
                txLivePublisher.config = config
                
                txLivePublisher.setRenderRotation(90)
            }
        }
    }

    func setLogViewMargin(_ margin: UIEdgeInsets) {
        txLivePublisher?.setLogViewMargin(margin)
    }

    func showVideoDebugLog(_ isShow: Bool) {
        txLivePublisher?.showVideoDebugLog(isShow)
    }

    @discardableResult
    func setFocusPointOfInterest(x: Float, y: Float) -> Bool {
        guard let txLivePublisher = txLivePublisher else {
            return false
        }
        txLivePublisher.setFocusPosition(CGPoint(x: CGFloat(x), y: CGFloat(y)))
        return true
    }

    @discardableResult
    func setContinuousAutofocus(_ wantsContinuous: Bool) -> Bool {
        Logger.warn("unsupport setContinuousAutofocus")
        return false
    }

    @discardableResult
    func setExposurePointOfInterest(x: Float, y: Float) -> Bool {
        Logger.warn("unsupport setExposurePointOfInterest")
        return false
    }

    @discardableResult
    func setContinuousExposure(_ wantsContinuous: Bool) -> Bool {
        Logger.warn("unsupport setContinuousExposure")
        return false
    }

    /*! Used by Objective-C Capture Session */
    func bufferCaptured(pixelBuffer: CVPixelBuffer) {
        guard let output = videoOutput else { return }

        let md = VideoBufferMetadata(ts: .init(value: 1, timescale: Int32(fps)))

        md.data = (1, matrix, false, WeakRefISource(value: self))

        var pb: IPixelBuffer = PixelBuffer(pixelBuffer, temporary: true)

        pb.state = .enqueued
        output.pushBuffer(&pb, size: MemoryLayout<PixelBuffer>.size, metadata: md)

    }

    // AudioProcessDelegate doesn't work yet
    func audioBufferCaptured(_ data: Data!, timeStamp: UInt64, sampleRate: Int32, channels: Int32) {
        /*guard let output = audioOutput else { return }

        let md = AudioBufferMetadata(ts: .init(value: CMTimeValue(timeStamp), timescale: Int32(1)))

        md.data = (Int(sampleRate),
                   16,
                   channels,
                   AudioFormatFlags(kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked),
                   channels * 2,
                   inNumberFrames,
                   false,
                   false,
                   WeakRefISource(value: self)
        )

        data.withUnsafeBytes {
            output.pushBuffer($0.baseAddress!, size: data.count, metadata: md)
        }*/
    }
    
    func reorientCamera() {
        guard let txLivePublisher = txLivePublisher else {
            return
        }
        switch UIDevice.current.orientation {
        case .portrait:
            if deviceOrientation != .portrait {
                if let config = txLivePublisher.config {
                    config.homeOrientation = HomeOrientation.down.rawValue
                    txLivePublisher.config = config
                    txLivePublisher.setRenderRotation(0)
                    deviceOrientation = .portrait
                }
            }
        case .landscapeLeft:
            if deviceOrientation != .landscapeLeft {
                if let config = txLivePublisher.config {
                    config.homeOrientation = HomeOrientation.right.rawValue
                    txLivePublisher.config = config
                    txLivePublisher.setRenderRotation(0)
                    deviceOrientation = .landscapeLeft
                }
            }
        case .landscapeRight:
            if deviceOrientation != .landscapeRight {
                if let config = txLivePublisher.config {
                    config.homeOrientation = HomeOrientation.left.rawValue
                    txLivePublisher.config = config
                    txLivePublisher.setRenderRotation(0)
                    deviceOrientation = .landscapeRight
                }
            }
        default:
            break
        }
    }
}

extension TencentSource {
    func setBeautyStyle(_ beautyStyle: Int, beautyLevel: Float, whitenessLevel: Float, ruddinessLevel: Float) {
        txLivePublisher?.setBeautyStyle(
            TX_Enum_Type_BeautyStyle(rawValue: beautyStyle)!,
            beautyLevel: beautyLevel,
            whitenessLevel: whitenessLevel,
            ruddinessLevel: ruddinessLevel)
    }

    func setEyeScaleLevel(_ eyeScaleLevel: Float) {
        txLivePublisher?.setEyeScaleLevel(eyeScaleLevel)
    }

    func setFaceScaleLevel(_ faceScaleLevel: Float) {
        txLivePublisher?.setFaceScaleLevel(faceScaleLevel)
    }

    func setFilter(_ filterImage: UIImage?) {
        txLivePublisher?.setFilter(filterImage)
    }

    func setGreenScreenFile(_ file: URL?) {
        txLivePublisher?.setGreenScreenFile(file)
    }

    func selectMotionTmpl(_ tmplName: String?, inDir tmplDir: String?) {
        txLivePublisher?.selectMotionTmpl(tmplName, inDir: tmplDir)
    }

    func setFaceVLevel(_ vLevel: Float) {
        txLivePublisher?.setFaceVLevel(vLevel)
    }

    func setFaceShortLevel(_ shortLevel: Float) {
        txLivePublisher?.setFaceShortLevel(shortLevel)
    }

    func setNoseSlimLevel(_ slimLevel: Float) {
        txLivePublisher?.setNoseSlimLevel(slimLevel)
    }

    func setChinLevel(_ chinLevel: Float) {
        txLivePublisher?.setChinLevel(chinLevel)
    }

    func setMixLevel(_ mixLevel: Float) {
        txLivePublisher?.setSpecialRatio(mixLevel / 10.0)
    }
}
