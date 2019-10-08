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

class TencentSource: ISource {
    var filter: IFilter?
    var orientationLocked: Bool = false

    private var matrix: GLKMatrix4 = GLKMatrix4Identity

    private weak var output: IOutput?

    private var callbackSession: TencentVideoProcessCallback?

    private var fps: Int = 0

    private var preViewContainer: UIView?

    private var txLivePublisher: TXLivePush?

    func setOutput(_ output: IOutput) {
        self.output = output
    }

    public init() {
    }

    deinit {
        callbackSession = nil
    }

    func getPreviewLayer(_ outAVCaptureVideoPreviewLayer: inout AVCaptureVideoPreviewLayer) {
    }

    func setupCamera(fps: Int = 15, useFront: Bool = true,
                     useInterfaceOrientation: Bool = false) {
        let config = TXLivePushConfig()
        config.videoFPS = Int32(fps)
        config.frontCamera = useFront
        syncSafe {
            let txLivePublisher = TXLivePush(config: config)

            callbackSession = .init()
            callbackSession?.source = self
            txLivePublisher?.videoProcessDelegate = callbackSession
            preViewContainer = UIView(frame: CGRect(x: 0, y: 0, width: 720, height: 1280))

            txLivePublisher?.startPreview(preViewContainer)
            txLivePublisher?.showVideoDebugLog(true)

            self.txLivePublisher = txLivePublisher
        }
    }

    func toggleCamera() {
    }

    func setTorch(_ torchOn: Bool) -> Bool {
        return false
    }

    @discardableResult
    func setFocusPointOfInterest(x: Float, y: Float) -> Bool {
        return false
    }

    @discardableResult
    open func setContinuousAutofocus(_ wantsContinuous: Bool) -> Bool {
        return false
    }

    @discardableResult
    open func setExposurePointOfInterest(x: Float, y: Float) -> Bool {
        return false
    }

    @discardableResult
    open func setContinuousExposure(_ wantsContinuous: Bool) -> Bool {
        return false
    }

    /*! Used by Objective-C Capture Session */
    func bufferCaptured(pixelBuffer: CVPixelBuffer) {
        guard let output = output else { return }

        let md = VideoBufferMetadata(ts: .init(value: 1, timescale: Int32(fps)))

        md.data = (1, matrix, false, WeakRefISource(value: self))

        var pb: IPixelBuffer = PixelBuffer(pixelBuffer, temporary: true)

        pb.state = .enqueued
        output.pushBuffer(&pb, size: MemoryLayout<PixelBuffer>.size, metadata: md)

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
