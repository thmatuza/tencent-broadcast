//
//  ViewController.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/04.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import UIKit
import VideoCast
import MBProgressHUD

final class SampleFilter: BasicVideoFilter {
    override class var fragmentFunc: String {
        return "invertColors"
    }
}

class ViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var btnFlash: UIButton!
    @IBOutlet weak var btnConnect: UIButton!
    @IBOutlet weak var lblBitrate: UILabel!
    @IBOutlet weak var pickerView: UIView!

    let imgFlashOn = UIImage(named: "icons8-flash-on-50")
    let imgFlashOff = UIImage(named: "icons8-flash-off-50")
    let imgRecordStart = UIImage(named: "icon-record-start")
    let imgRecordStop = UIImage(named: "icon-record-stop")

    var session: TencentSession!
    var videoBitrate: Int = 0
    var audioBitrate: Int = 0

    var _connecting = false
    var connecting: Bool {
        get {
            return _connecting
        }
        set {
            if !_connecting && newValue {
                btnConnect.alpha = 1.0
                UIView.animate(withDuration: 0.1, delay: 0.0,
                               options: [.curveEaseInOut, .repeat, .autoreverse, .allowUserInteraction],
                               animations: {() -> Void in
                                self.btnConnect.alpha = 0.1
                }, completion: {(_: Bool) -> Void in
                })
            } else if connecting && !newValue {
                UIView.animate(withDuration: 0.1, delay: 0.0,
                               options: [.curveEaseInOut, .beginFromCurrentState],
                               animations: {() -> Void in
                                self.btnConnect.alpha = 1.0
                }, completion: {(_: Bool) -> Void in
                })
            }
            _connecting = newValue
        }
    }

    var isFiltered = false

    var screenPortrait = false
    var logSwitch = false
    var btnBeauty: UIButton!
    var btnScreenOrientation: UIButton!
    var btnLog: UIButton!
    var vBeauty: BeautySettingPanel!
    var hub: MBProgressHUD!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view, typically from a nib.
        initSession()
        lblBitrate.text = ""

        let delegate = session.delegate

        delegate.connectionStatusChanged = { [weak self] sessionState in
            guard let strongSelf = self else { return }

            switch strongSelf.session.sessionState {
            case .starting, .reconnecting:
                strongSelf.connecting = true
                strongSelf.btnConnect.setImage(strongSelf.imgRecordStop, for: .normal)

            case .started:
                strongSelf.connecting = false
                strongSelf.btnConnect.setImage(strongSelf.imgRecordStop, for: .normal)

            case .previewStarted:
                break

            default:
                strongSelf.connecting = false
                strongSelf.btnConnect.setImage(strongSelf.imgRecordStart, for: .normal)
                strongSelf.session.videoSize = strongSelf.getVideoSize()
                strongSelf.lblBitrate.text = ""
            }
        }

        delegate.didAddCameraSource = { [weak self] session in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.initUI()
                strongSelf.vBeauty.resetValues()
            }
        }

        delegate.detectedThroughput = { [weak self] throughputInBytesPerSecond, videorate, oBitrate in
            guard let strongSelf = self else { return }
            let bitrateText = """
            bitrate: \(oBitrate / 1000) kbps
            video:   \(strongSelf.videoBitrate / 1000) kbps
            audio:   \(strongSelf.audioBitrate / 1000) kbps
            """
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.lblBitrate.text = bitrateText
            }
        }

        delegate.bitrateChanged = { [weak self] videoBitrate, audioBitrate in
            self?.videoBitrate = videoBitrate
            self?.audioBitrate = audioBitrate
        }

        btnFlash.setImage(imgFlashOff, for: .normal)
        btnFlash.setImage(imgFlashOn, for: [.normal, .selected])
        updateFlashBtn()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    deinit {
        btnConnect = nil
        previewView = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: false)
        refreshVideoSize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: false)
    }

    override func viewDidLayoutSubviews() {
        session.previewView.frame = previewView.bounds
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        refreshVideoSize()
    }

    @IBAction func btnFlashTouch(_ sender: UIButton) {
        session.torch = !sender.isSelected
        updateFlashBtn()
    }

    @IBAction func btnSwitchCameraTouch(_ sender: UIButton) {
        let newState: VCCameraState
        switch session.cameraState {
        case .back:
            newState = .front
        case .front:
            newState = .back
        }
        switchCameraTouch(newState)
    }

    private func switchCameraTouch(_ newState: VCCameraState) {
        session.cameraState = newState

        // try to set current torch state
        session.torch = session.torch
        updateFlashBtn()
    }

    @IBAction func btnConnectTouch(_ sender: AnyObject) {
        switch session.sessionState {
        case .none, .previewStarted, .ended, .error:
            session.bitrate = OptionsModel.shared.bitrate
            session.fps = OptionsModel.shared.framerate
            session.keyframeInterval = OptionsModel.shared.keyframeInterval
            session.useAdaptiveBitrate = OptionsModel.shared.bitrateMode == .automatic
            session.videoCodecType = OptionsModel.shared.videoCodec

            videoBitrate = 0
            audioBitrate = 0

            let server = ServerModel.shared.server

            if server.url.starts(with: "rtmp") {
                session.startRtmpSession(
                    url: server.url,
                    streamKey: server.streamName
                )
            }
            if server.url.starts(with: "srt") {
                guard var urlComponents = URLComponents(string: server.url) else { return }
                var items = urlComponents.queryItems ?? []
                items.append(URLQueryItem(name: "streamid", value: server.streamName))
                urlComponents.queryItems = items

                session.startSRTSession(
                    url: urlComponents.url!.absoluteString
                )
            }
        default:
            session.endSession()
        }
    }

    @IBAction func btnFilterTouch(_ sender: AnyObject) {
        isFiltered.toggle()
        self.session.filter = isFiltered ? SampleFilter() : BasicVideoFilterBGRA()
    }

    private func initSession() {
#if USE_VIDEOCAST_PREVIEW
        let preViewContainer: UIView? = nil
#else
        let preViewContainer = previewView
#endif
        session = TencentSession(
            preViewContainer: preViewContainer,
            videoSize: getVideoSize(),
            frameRate: OptionsModel.shared.framerate,
            bitrate: OptionsModel.shared.bitrate,
            videoCodecType: OptionsModel.shared.videoCodec,
            useInterfaceOrientation: true,
            aspectMode: .fill
        )
#if USE_VIDEOCAST_PREVIEW
        previewView.addSubview(session.previewView)
#endif
        session.previewView.frame = previewView.bounds
        switchCameraTouch(.front)
    }

    private func updateFlashBtn() {
        btnFlash.isSelected = session.torch
    }

    private func getVideoSize() -> CGSize {
        let (width, height) = OptionsModel.shared.videoSizes[OptionsModel.shared.videoSizeIndex]
        let isLandscape: Bool
        if OptionsModel.shared.orientation == .default {
            isLandscape = UIDevice.current.orientation.isLandscape
        } else {
            isLandscape = OptionsModel.shared.orientation == .landscape
        }
        return isLandscape ?
            CGSize(width: width, height: height) :
            CGSize(width: height, height: width)
    }

    private func refreshVideoSize() {
        switch session.sessionState {
        case .starting, .started, .reconnecting:
            break
        default:
            session.videoSize = getVideoSize()
        }
    }

    private func initUI() {
        let size = UIScreen.main.bounds.size
        let ICON_SIZE: CGFloat = 46
        let startSpace: CGFloat = 12
        let centerInterVal: CGFloat = (size.width - 2 * startSpace - ICON_SIZE) / 6
        let iconY: CGFloat = size.height - ICON_SIZE / 2 - 10

        btnBeauty = UIButton(type: .custom)
        btnBeauty.center = CGPoint(x: startSpace + ICON_SIZE / 2 + centerInterVal * 2, y: iconY)
        btnBeauty.bounds = CGRect(x: 0, y: 0, width: ICON_SIZE, height: ICON_SIZE)
        btnBeauty.setImage(UIImage(named: "beauty"), for: .normal)
        btnBeauty.addTarget(self, action: #selector(self.clickBeauty(_:)), for: .touchUpInside)
        view.addSubview(btnBeauty)

        btnScreenOrientation = UIButton(type: .custom)
        btnScreenOrientation.center = CGPoint(x: startSpace + ICON_SIZE / 2 + centerInterVal * 4, y: iconY)
        btnScreenOrientation.bounds = CGRect(x: 0, y: 0, width: ICON_SIZE, height: ICON_SIZE)
        btnScreenOrientation.setImage(UIImage(named: "portrait"), for: .normal)
        btnScreenOrientation.addTarget(self, action: #selector(self.clickScreenOrientation(_:)), for: .touchUpInside)
        view.addSubview(btnScreenOrientation)

        btnLog = UIButton(type: .custom)
        btnLog.center = CGPoint(x: startSpace + ICON_SIZE / 2 + centerInterVal * 5, y: iconY)
        btnLog.bounds = CGRect(x: 0, y: 0, width: ICON_SIZE, height: ICON_SIZE)
        btnLog.setImage(UIImage(named: "log"), for: .normal)
        btnLog.addTarget(self, action: #selector(self.clickLog(_:)), for: .touchUpInside)
        view.addSubview(btnLog)

        let controlHeight = CGFloat(BeautySettingPanel.height)
        vBeauty = BeautySettingPanel(frame: CGRect(x: 0,
                                                   y: view.frame.size.height - controlHeight,
                                                   width: view.frame.size.width,
                                                   height: controlHeight))
        vBeauty.isHidden = true
        vBeauty.delegate = self
        vBeauty.pituDelegate = self
        view.addSubview(vBeauty)
    }

    @objc private func clickBeauty(_ btn: UIButton) {
        vBeauty.isHidden = false
        hideToolButtons(true)
    }

    @objc private func clickScreenOrientation(_ btn: UIButton) {
        screenPortrait = !screenPortrait

        if screenPortrait {
            btn.setImage(UIImage(named: "landscape"), for: .normal)
            session.setOrientation(false)
        } else {
            btn.setImage(UIImage(named: "portrait"), for: .normal)
            session.setOrientation(true)
        }
    }

    @objc private func clickLog(_ btn: UIButton) {
        if logSwitch {
            btn.setImage(UIImage(named: "log"), for: .normal)
        } else {
            btn.setImage(UIImage(named: "log2"), for: .normal)
        }
        logSwitch = !logSwitch
        session.setLogViewMargin(UIEdgeInsets(top: 120, left: 10, bottom: 60, right: 10))
        session.showVideoDebugLog(logSwitch)
    }

    private func hideToolButtons(_ bHide: Bool) {
        btnBeauty.isHidden = bHide
        btnScreenOrientation.isHidden = bHide
        btnLog.isHidden = bHide
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
        vBeauty.isHidden = true
        hideToolButtons(false)
    }
}

extension ViewController: BeautyLoadPituDelegate {
    func onLoadPituStart() {
        DispatchQueue.main.async {
            self.hub = MBProgressHUD.showAdded(to: self.view, animated: true)
            self.hub.mode = .text
            self.hub.label.text = "Start loading resources"
        }
    }

    func onLoadPituProgress(_ progress: CGFloat) {
        DispatchQueue.main.async {
            self.hub.label.text = "Loading resources\(Int(progress * 100)) %"
        }
    }

    func onLoadPituFinished() {
        DispatchQueue.main.async {
            self.hub.label.text = "The resource is loaded successfully"
            self.hub.hide(animated: false, afterDelay: 1)
        }
    }

    func onLoadPituFailed() {
        DispatchQueue.main.async {
            self.hub.label.text = "Resource loading failed"
            self.hub.hide(animated: true, afterDelay: 1)
        }
    }
}

extension ViewController: BeautySettingPanelDelegate {
    func onSetBeautyStyle(_ beautyStyle: Int, beautyLevel: Float, whitenessLevel: Float, ruddinessLevel: Float) {
        session.setBeautyStyle(beautyStyle,
                               beautyLevel: beautyLevel,
                               whitenessLevel: whitenessLevel,
                               ruddinessLevel: ruddinessLevel)
    }

    func onSetEyeScaleLevel(_ eyeScaleLevel: Float) {
        session.setEyeScaleLevel(eyeScaleLevel)
    }

    func onSetFaceScaleLevel(_ faceScaleLevel: Float) {
        session.setFaceScaleLevel(faceScaleLevel)
    }

    func onSetFilter(_ filterImage: UIImage?) {
        session.setFilter(filterImage)
    }

    func onSetGreenScreenFile(_ file: URL?) {
        session.setGreenScreenFile(file)
    }

    func onSelectMotionTmpl(_ tmplName: String?, inDir tmplDir: String?) {
        session.selectMotionTmpl(tmplName, inDir: tmplDir)
    }

    func onSetFaceVLevel(_ vLevel: Float) {
        session.setFaceVLevel(vLevel)
    }

    func onSetFaceShortLevel(_ shortLevel: Float) {
        session.setFaceShortLevel(shortLevel)
    }

    func onSetNoseSlimLevel(_ slimLevel: Float) {
        session.setNoseSlimLevel(slimLevel)
    }

    func onSetChinLevel(_ chinLevel: Float) {
        session.setChinLevel(chinLevel)
    }

    func onSetMixLevel(_ mixLevel: Float) {
        session.setMixLevel(mixLevel)
    }
}
