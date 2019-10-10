//
//  TencentSession.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/04.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import Foundation

import AVFoundation
import UIKit
import VideoCast

open class TencentSession {
    var pbOutput: PixelBufferOutput?
    var micSource: MicSource?
    var cameraSource: TencentSource?
    var pixelBufferSource: PixelBufferSource?
    var videoSampleSource: VideoSampleSource?
    var videoSampleSmoother: Smoother?
    var audioAppSampleSource: AudioSampleSource?
    var audioAppSampleSmoother: Smoother?
    var audioMicSampleSource: AudioSampleSource?
    var audioMicSampleSmoother: Smoother?
    var pbAspect: AspectTransform?
    var pbPosition: PositionTransform?

    var videoSplit: Split?
    var aspectTransform: AspectTransform?
    var atAspectMode: AspectTransform.AspectMode = .fill
    var positionTransform: PositionTransform?
    var audioMixer: AudioMixer?
    var videoMixer: IVideoMixer?
    var vtEncoder: IEncoder?
    var aacEncoder: IEncoder?
    var h264Packetizer: ITransform?
    var aacPacketizer: ITransform?

    var aacSplit: Split?
    var vtSplit: Split?
    var muxer: MP4Multiplexer?

    var outputSession: IOutputSession?

    var adtsEncoder: ITransform?
    var annexbEncoder: ITransform?
    var tsMuxer: TSMultiplexer?
    var fileSink: FileSink?

    var sessionStarted = false

    let graphManagementQueue = DispatchQueue(label: "jp.co.cyberagent.VideoCast.session.graph")
    let minVideoBitrate = 32000

    var bpsCeiling = 0

    private var _torch = false
    private var _audioChannelCount = 1
    private var _audioSampleRate: Float = 48000
    private var _micGain: Float = 1
    var _cameraState: VCCameraState
    var _mirrorPreview = true
    var preViewContainer: UIView?

    open var sessionState = VCSessionState.none {
        didSet {
            if Thread.isMainThread {
                delegate.connectionStatusChanged?(sessionState)
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.delegate.connectionStatusChanged?(strongSelf.sessionState)
                }
            }
        }
    }

    open var previewView: VCPreviewView

    open var videoSize: CGSize = CGSize() {
        didSet {
            aspectTransform?.setBoundingSize(boundingWidth: Int(videoSize.width), boundingHeight: Int(videoSize.height))
            positionTransform?.setPosition(x: Int(videoSize.width / 2), y: Int(videoSize.height / 2))
            positionTransform?.setSize(
                width: Int(Float(videoSize.width) * videoZoomFactor),
                height: Int(Float(videoSize.height) * videoZoomFactor)
            )
            positionTransform?.setContextSize(width: Int(videoSize.width), height: Int(videoSize.height))
            videoMixer?.setFrameSize(
                width: Int(videoSize.width),
                height: Int(videoSize.height)
            )
        }
    }
    open var bitrate: Int                       // Change will not take place until the next Session
    open var fps: Int                           // Change will not take place until the next Session
    open var keyframeInterval: Int              // Change will not take place until the next Session
    open var videoCodecType: VCVideoCodecType   // Change will not take place until the next Session
    open var autoreconnect: Bool = true
    open var reconnectPeriod: TimeInterval = .init(5)
    public let useInterfaceOrientation: Bool
    open var cameraState: VCCameraState {
        get { return _cameraState }
        set {
            if _cameraState != newValue {
                cameraSource?.toggleCamera()
                _cameraState = newValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.updatePreview()
                }
            }
        }
    }
    open var mirrorPreview: Bool {
        get { return _mirrorPreview }
        set {
            if _mirrorPreview != newValue {
                _mirrorPreview = newValue
                updatePreview()
            }
        }
    }
    open var orientationLocked: Bool = false {
        didSet { cameraSource?.orientationLocked = orientationLocked }
    }
    open var torch: Bool {
        get { return _torch }
        set {
            if let cameraSource = cameraSource {
                _torch = cameraSource.setTorch(newValue)
            }
        }
    }
    open var videoZoomFactor: Float = 1 {
        didSet {
            positionTransform?.setSize(
                width: Int(Float(videoSize.width) * videoZoomFactor),
                height: Int(Float(videoSize.height) * videoZoomFactor)
            )
        }
    }
    open var audioChannelCount: Int {
        get { return _audioChannelCount }
        set {
            _audioChannelCount = max(1, min(newValue, 2))
            audioMixer?.setChannelCount(_audioChannelCount)
        }
    }
    open var audioSampleRate: Float {
        get { return _audioSampleRate }
        set {
            _audioSampleRate = newValue
            audioMixer?.setFrequencyInHz(newValue)
        }
    }
    open var micGain: Float {      // [0..1]
        get { return _micGain }
        set {
            if let audioMixer = audioMixer, let micSource = micSource {
                audioMixer.setSourceGain(WeakRefISource(value: micSource), gain: newValue)
            }
            _micGain = newValue
        }
    }
    open var focusPointOfInterest = CGPoint(x: 0.5, y: 0.5) {   // (0,0) is top-left, (1,1) is bottom-right
        didSet {
            cameraSource?.setFocusPointOfInterest(x: Float(focusPointOfInterest.x), y: Float(focusPointOfInterest.y))
        }
    }
    open var exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5) {
        didSet {
            cameraSource?.setExposurePointOfInterest(x: Float(exposurePointOfInterest.x),
                                                     y: Float(exposurePointOfInterest.y))
        }
    }
    open var continuousAutofocus = false {
        didSet {
            cameraSource?.setContinuousAutofocus(continuousAutofocus)
        }
    }
    open var continuousExposure = true {
        didSet {
            cameraSource?.setContinuousExposure(continuousExposure)
        }
    }
    open var useAdaptiveBitrate = false { /* Default is off */
        didSet {
            bpsCeiling = bitrate
        }
    }
    open internal(set) var estimatedThroughput = 0    /* Bytes Per Second. */
    open var aspectMode: VCAspectMode = .fit {
        didSet {
            switch aspectMode {
            case .fill:
                atAspectMode = .fill
            case .fit:
                atAspectMode = .fit
            }
        }
    }
    open var filter: IVideoFilter = BasicVideoFilterBGRA() {    /* Default is normal */
        didSet {
            guard let videoMixer = videoMixer, let cameraSource = cameraSource else {
                return Logger.debug("unexpected return")
            }

            Logger.info("FILTER IS : \(filter)")
            videoMixer.setSourceFilter(WeakRefISource(value: cameraSource), filter: filter)
        }
    }

    // swiftlint:disable:next weak_delegate
    public let delegate: TencentSessionDelegate

    public init(
        preViewContainer: UIView?,
        videoSize: CGSize,
        frameRate fps: Int,
        bitrate bps: Int,
        videoCodecType: VCVideoCodecType = .h264,
        useInterfaceOrientation: Bool = false,
        cameraState: VCCameraState = .back,
        aspectMode: VCAspectMode = .fit,
        delegate: TencentSessionDelegate = .init()) {
        self.delegate = delegate

        self.preViewContainer = preViewContainer
        self.bitrate = bps
        self.fps = fps
        self.keyframeInterval = fps * 2 // default 2 sec
        self.videoCodecType = videoCodecType
        self.useInterfaceOrientation = useInterfaceOrientation

        self.previewView = .init()

        self._cameraState = cameraState
        updatePreview()

        // initialize videoSize and ascpectMode in internal function to call didSet
        initInternal(videoSize: videoSize,
                     aspectMode: aspectMode)
    }

    private func initInternal(
        videoSize: CGSize,
        aspectMode: VCAspectMode) {
        self.videoSize = videoSize
        self.aspectMode = aspectMode

        graphManagementQueue.async { [weak self] in
            self?.setupGraph()
        }
    }

    deinit {
        endSession()
        videoSampleSmoother?.stop()
        videoSampleSmoother = nil
        audioAppSampleSmoother?.stop()
        audioAppSampleSmoother = nil
        audioMicSampleSmoother?.stop()
        audioMicSampleSmoother = nil
        audioMixer?.stop()
        audioMixer = nil
        videoMixer?.stop()
        videoMixer = nil
        videoSplit = nil
        aspectTransform = nil
        positionTransform = nil
        micSource?.stop()
        micSource = nil
        cameraSource = nil
        pbOutput = nil
        resetPixelBufferSourceInternal()
    }

    open func startRtmpSession(url: String, streamKey: String) {
        graphManagementQueue.async { [weak self] in
            self?.startRtmpSessionInternal(url: url, streamKey: streamKey)
        }
    }

    open func startSRTSession(url: String) {
        graphManagementQueue.async { [weak self] in
            self?.startSRTSessionInternal(url: url)
        }
    }

    open func endSession() {
        sessionStarted = false

        h264Packetizer = nil
        aacPacketizer = nil

        if let vtEncoder = vtEncoder {
            videoSplit?.removeOutput(vtEncoder)
        }

        vtEncoder = nil
        aacEncoder = nil

        vtSplit = nil
        aacSplit = nil

        muxer?.stop {
            self.muxer = nil
        }

        outputSession?.stop {
            self.outputSession = nil
        }

        annexbEncoder = nil
        adtsEncoder = nil
        tsMuxer = nil
        fileSink = nil

        bitrate = bpsCeiling

        sessionState = .ended
    }

    open func getCameraPreviewLayer(_ previewLayer: inout AVCaptureVideoPreviewLayer) {
        assertionFailure("unsupported getCameraPreviewLayer")
    }

    open func addPixelBufferSource(image: UIImage, rect: CGRect, aspectMode: VCAspectMode = .fit) {
        graphManagementQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.addPixelBufferSourceInternal(image: image, rect: rect, aspectMode: aspectMode)
        }
    }

    open func resetPixelBufferSource() {
        graphManagementQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.resetPixelBufferSourceInternal()
        }
    }

    @available(iOS 9.0, *)
    open func pushVideo(_ sampleBuffer: CMSampleBuffer) {
        videoSampleSource?.pushSample(sampleBuffer)
    }

    open func pushAudioApp(_ sampleBuffer: CMSampleBuffer) {
        audioAppSampleSource?.pushSample(sampleBuffer)
    }

    open func pushAudioMic(_ sampleBuffer: CMSampleBuffer) {
        audioMicSampleSource?.pushSample(sampleBuffer)
    }
}

extension TencentSession {
    func setOrientation(_ portrait: Bool) {
        cameraSource?.setOrientation(portrait)
    }

    func setLogViewMargin(_ margin: UIEdgeInsets) {
        cameraSource?.setLogViewMargin(margin)
    }

    func showVideoDebugLog(_ isShow: Bool) {
        cameraSource?.showVideoDebugLog(isShow)
    }

    func setBeautyStyle(_ beautyStyle: Int, beautyLevel: Float, whitenessLevel: Float, ruddinessLevel: Float) {
        cameraSource?.setBeautyStyle(beautyStyle,
                                     beautyLevel: beautyLevel,
                                     whitenessLevel: whitenessLevel,
                                     ruddinessLevel: ruddinessLevel)
    }

    func setEyeScaleLevel(_ eyeScaleLevel: Float) {
        cameraSource?.setEyeScaleLevel(eyeScaleLevel)
    }

    func setFaceScaleLevel(_ faceScaleLevel: Float) {
        cameraSource?.setFaceScaleLevel(faceScaleLevel)
    }

    func setFilter(_ filterImage: UIImage?) {
        cameraSource?.setFilter(filterImage)
    }

    func setGreenScreenFile(_ file: URL?) {
        cameraSource?.setGreenScreenFile(file)
    }

    func selectMotionTmpl(_ tmplName: String?, inDir tmplDir: String?) {
        cameraSource?.selectMotionTmpl(tmplName, inDir: tmplDir)
    }

    func setFaceVLevel(_ vLevel: Float) {
        cameraSource?.setFaceVLevel(vLevel)
    }

    func setFaceShortLevel(_ shortLevel: Float) {
        cameraSource?.setFaceShortLevel(shortLevel)
    }

    func setNoseSlimLevel(_ slimLevel: Float) {
        cameraSource?.setNoseSlimLevel(slimLevel)
    }

    func setChinLevel(_ chinLevel: Float) {
        cameraSource?.setChinLevel(chinLevel)
    }

    func setMixLevel(_ mixLevel: Float) {
        cameraSource?.setMixLevel(mixLevel)
    }
}
