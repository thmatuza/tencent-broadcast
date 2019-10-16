//
//  BeautySettingPanel.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/08.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import UIKit
import VideoCast
import AFNetworking
import ZipArchive

enum PanelBeautyStyle: Int {
    case smooth = 0
    case nature = 1
    case pitu = 2
}

enum PanelMenuIndex: Int {
    case beauty
    case filter
    case motion
    case koubei
    case green
}

enum FilterType: Int {
    case none = 0
    case normal
    case yinghong
    case yunshang
    case chunzhen
    case bailan
    case yuanqi
    case chaotuo
    case xiangfen
    case white      // Whitening filter
    case langman    // Romantic filter
    case qingxin    // Fresh filter
    case weimei     // Aesthetic filter
    case fennen     // Pink filter
    case huaijiu    // Nostalgic filter
    case landiao    // Blues filter
    case qingliang  // Cool filter
    case rixi       // Japanese filter
}

private let BeautyViewMargin: CGFloat = 8
private let BeautyViewSliderHeight: CGFloat = 30
private let BeautyViewCollectionHeight: CGFloat = 50
private let BeautyViewTitleWidth: CGFloat = 40

// swiftlint:disable:next type_body_length
class BeautySettingPanel: UIView {
    private func L(_ x: String) -> String {
        return NSLocalizedString(x, comment: "")
    }
    private enum BeautyMenuItem: Int {
        case smooth
        case nature
        case piTu
        static let lastBeautyTypeItem = BeautyMenuItem.piTu.rawValue
        case white
        case red
        static let lastBeautyValueItem = BeautyMenuItem.red.rawValue
        case eye
        case faceScale
        case vFace
        case chin
        case shortFace
        case nose
    }

    weak var delegate: BeautySettingPanelDelegate?
    weak var pituDelegate: BeautyLoadPituDelegate?

    private var optionsContainer: [[String]]!
    private var selectedIndexMap: [PanelMenuIndex: IndexPath]!
    private var motionNameMap: [String: String]!

    private var currentMenuIndex: PanelMenuIndex = .beauty

    private var beautyValueMap: [Int: Float]!

    private var filterMap: [Int: Float]!
    private var menuArray: [String]!
    private var motionAddressDic: [String: String]!
    private var koubeiAddressDic: [String: String]!
    private var operation: URLSessionDownloadTask?
    private var beautyLevel: Float = 0
    private var whiteLevel: Float = 0
    private var ruddyLevel: Float = 0
    private var beautyStyle: PanelBeautyStyle = .smooth

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    private func commonInit() {
        beautyValueMap = .init()
        filterMap = .init()

        beautySlider.frame = CGRect(
            x: BeautyViewMargin * 4,
            y: BeautyViewMargin,
            width: frame.size.width - 10 * BeautyViewMargin - BeautyViewSliderHeight,
            height: BeautyViewSliderHeight)
        addSubview(beautySlider)
        beautySlider.autoresizingMask = .flexibleWidth

        beautyLabel.frame = CGRect(
            x: beautySlider.frame.size.width + beautySlider.frame.origin.x + BeautyViewMargin,
            y: BeautyViewMargin,
            width: BeautyViewSliderHeight,
            height: BeautyViewSliderHeight)
        beautyLabel.layer.cornerRadius = beautyLabel.frame.size.width / 2
        beautyLabel.layer.masksToBounds = true
        addSubview(beautyLabel)
        beautyLabel.autoresizingMask = .flexibleLeftMargin

        filterSlider.frame = CGRect(
            x: BeautyViewMargin * 4,
            y: BeautyViewMargin,
            width: frame.size.width - 10 * BeautyViewMargin - BeautyViewSliderHeight,
            height: BeautyViewSliderHeight)
        filterSlider.isHidden = true
        addSubview(filterSlider)
        filterSlider.autoresizingMask = .flexibleWidth

        filterLabel.frame = CGRect(
            x: filterSlider.frame.size.width + filterSlider.frame.origin.x + BeautyViewMargin,
            y: BeautyViewMargin,
            width: BeautyViewSliderHeight,
            height: BeautyViewSliderHeight)
        filterLabel.layer.cornerRadius = filterLabel.frame.size.width / 2
        filterLabel.layer.masksToBounds = true
        filterLabel.isHidden = true
        addSubview(filterLabel)
        filterLabel.autoresizingMask = .flexibleLeftMargin

        menuArray = [L("美颜"),
                     L("滤镜"),
                     L("动效"),
                     L("抠背"),
                     L("绿幕")]

        let effectArray = [L("清除"),
                           L("标准"),
                           L("樱红"),
                           L("云裳"),
                           L("纯真"),
                           L("白兰"),
                           L("元气"),
                           L("超脱"),
                           L("香氛"),
                           L("美白"),
                           L("浪漫"),
                           L("清新"),
                           L("唯美"),
                           L("粉嫩"),
                           L("怀旧"),
                           L("蓝调"),
                           L("清亮"),
                           L("日系")]

        let beautyArray = [L("美颜(光滑)"),
                           L("美颜(自然)"),
                           L("美颜(P图)"),
                           L("美白"),
                           L("红润"),
                           L("大眼"),
                           L("瘦脸"),
                           L("V脸"),
                           L("下巴"),
                           L("短脸"),
                           L("瘦鼻")]

        let motionArray = [L("清除"), "video_boom", "video_nihongshu", "video_3DFace_dogglasses2",
                           "video_fengkuangdacall", "video_Qxingzuo_iOS", "video_caidai_iOS",
                           "video_liuhaifadai", "video_rainbow", "video_purplecat",
                           "video_huaxianzi", "video_baby_agetest"]

        motionAddressDic = [
            "video_3DFace_dogglasses2": video_3DFace_dogglasses2,
            "video_baby_agetest": video_baby_agetest,
            "video_caidai_iOS": video_caidai_iOS,
            "video_huaxianzi": video_huaxianzi,
            "video_liuhaifadai": video_liuhaifadai,
            "video_nihongshu": video_nihongshu,
            "video_rainbow": video_rainbow,
            "video_boom": video_boom,
            "video_fengkuangdacall": video_fengkuangdacall,
            "video_purplecat": video_purplecat,
            "video_Qxingzuo_iOS": video_Qxingzuo_iOS
        ]

        let koubeiArray = [L("清除"), "video_xiaofu"]
        koubeiAddressDic = ["video_xiaofu": video_xiaofu]

        let greenArray = [L("清除"), "goodluck"]

        optionsContainer = [beautyArray, effectArray, motionArray, koubeiArray, greenArray]
        selectedIndexMap = .init(minimumCapacity: optionsContainer.count)

        optionsCollectionView.frame = CGRect(
            x: 0,
            y: beautySlider.frame.size.height + beautySlider.frame.origin.y + BeautyViewMargin,
            width: frame.size.width,
            height: BeautyViewSliderHeight * 2 + 2 * BeautyViewMargin)
        optionsCollectionView.autoresizingMask = .flexibleWidth
        addSubview(optionsCollectionView)

        menuCollectionView.frame = CGRect(
            x: 0,
            y: optionsCollectionView.frame.size.height + optionsCollectionView.frame.origin.y,
            width: frame.size.width,
            height: BeautyViewCollectionHeight)
        menuCollectionView.autoresizingMask = .flexibleWidth
        addSubview(menuCollectionView)
    }

    // MARK: layout
    func changeFunction(_ index: PanelMenuIndex) {
        beautyLabel.isHidden = index != .beauty
        beautySlider.isHidden = beautyLabel.isHidden

        filterLabel.isHidden = index != .filter
        filterSlider.isHidden = filterLabel.isHidden

        assert(index.rawValue < optionsContainer.count, "index out of range")
        menuCollectionView.cellForItem(at: IndexPath(item: currentMenuIndex.rawValue, section: 0))?.isSelected = false
        currentMenuIndex = index
        optionsCollectionView.reloadData()
    }

    private func applyBeautySettings() {
        delegate?.onSetBeautyStyle(
            beautyStyle.rawValue,
            beautyLevel: beautyLevel,
            whitenessLevel: whiteLevel,
            ruddinessLevel: ruddyLevel)
    }

    // MARK: value changed
    @objc private func onValueChanged(_ sender: Any) {
        guard let slider = sender as? UISlider else {
            Logger.error("onValueChanged sender is not slider")
            return
        }
        let value = slider.value
        if slider == filterSlider {
            let value = filterSlider.value
            filterLabel.text = String(format: "%.0f", value)
            let filterIndex = selectedIndexPathForMenu(.filter).item
            filterMap[filterIndex] = value
            delegate?.onSetMixLevel(value)
        } else {
            // Determine which secondary menu is selected
            let beautyIndex = selectedIndexPathForMenu(.beauty).item

            beautyValueMap[beautyIndex] = beautySlider.value
            beautyLabel.text = "\(Int(beautySlider.value))"

            if beautyIndex <= BeautyMenuItem.lastBeautyValueItem {
                if beautyIndex <= BeautyMenuItem.lastBeautyTypeItem {
                    beautyLevel = slider.value
                } else if beautyIndex == BeautyMenuItem.white.rawValue {
                    whiteLevel = value
                } else if beautyIndex == BeautyMenuItem.red.rawValue {
                    ruddyLevel = value
                }
                applyBeautySettings()
            }

            if beautyIndex == BeautyMenuItem.eye.rawValue {
                delegate?.onSetEyeScaleLevel(value)
            } else if beautyIndex == BeautyMenuItem.faceScale.rawValue {
                delegate?.onSetFaceScaleLevel(value)
            } else if beautyIndex == BeautyMenuItem.vFace.rawValue {
                delegate?.onSetFaceVLevel(value)
            } else if beautyIndex == BeautyMenuItem.chin.rawValue {
                delegate?.onSetChinLevel(value)
            } else if beautyIndex == BeautyMenuItem.shortFace.rawValue {
                delegate?.onSetFaceShortLevel(value)
            } else if beautyIndex == BeautyMenuItem.nose.rawValue {
                delegate?.onSetNoseSlimLevel(value)
            }
        }
    }

    private func onSetEffectWithIndex(_ index: Int) {
        if let delegate = delegate {
            let image = filterImageByIndex(index)
            delegate.onSetFilter(image)
        }
    }

    private func onSetGreenWithIndex(_ index: Int) {
        if let delegate = delegate {
            if index == 0 {
                delegate.onSetGreenScreenFile(nil)
            }
            if index == 1 {
                delegate.onSetGreenScreenFile(Bundle.main.url(forResource: "goodluck", withExtension: "mp4"))
            }
        }
    }

    private func onSetMotionWithIndex(_ index: Int) {
        if let delegate = delegate {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0]
            let docURL = URL(string: documentsDirectory)!
            let localPackageDir = docURL.appendingPathComponent("packages").absoluteString
            if !FileManager.default.fileExists(atPath: localPackageDir) {
                try! FileManager.default.createDirectory(atPath: localPackageDir, withIntermediateDirectories: false, attributes: nil)
            }
            if index == 0 {
                delegate.onSelectMotionTmpl(nil, inDir: localPackageDir)
            } else {
                let motionAray = optionsContainer[PanelMenuIndex.motion.rawValue]
                let tmp = motionAray[index]
                let pituPath = "\(localPackageDir)/\(tmp)"
                if FileManager.default.fileExists(atPath: pituPath) {
                    delegate.onSelectMotionTmpl(tmp, inDir: localPackageDir)
                } else {
                    startLoadPitu(localPackageDir, pituName: tmp, packageURL: URL(string: motionAddressDic[tmp]!)!)
                }
            }
        }
    }

    private func onSetKoubeiWithIndex(_ index: Int) {
        if let delegate = delegate {
            let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
            let documentsDirectory = paths[0]
            let docURL = URL(string: documentsDirectory)!
            let localPackageDir = docURL.appendingPathComponent("packages").absoluteString
            if !FileManager.default.fileExists(atPath: localPackageDir) {
                try! FileManager.default.createDirectory(atPath: localPackageDir, withIntermediateDirectories: false, attributes: nil)
            }
            if index == 0 {
                delegate.onSelectMotionTmpl(nil, inDir: localPackageDir)
            } else {
                let koubeiArray = optionsContainer[PanelMenuIndex.koubei.rawValue]
                let tmp = koubeiArray[index]
                let pituPath = "\(localPackageDir)/\(tmp)"
                if FileManager.default.fileExists(atPath: pituPath) {
                    delegate.onSelectMotionTmpl(tmp, inDir: localPackageDir)
                } else {
                    startLoadPitu(localPackageDir, pituName: tmp, packageURL: URL(string: koubeiAddressDic[tmp]!)!)
                }
            }
        }
    }

    private func startLoadPitu(_ pituDir: String, pituName: String, packageURL: URL) {
        if let operation = operation {
            if operation.state != .running {
                operation.resume()
            }
        }
        let targetPath = "\(pituDir)/\(pituName).zip"
        if FileManager.default.fileExists(atPath: targetPath) {
            try? FileManager.default.removeItem(atPath: targetPath)
        }

        weak var weakSelf = self
        let downloadReq = URLRequest(url: packageURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
        let manager = AFHTTPSessionManager()
        weak var weakManager = manager
        pituDelegate?.onLoadPituStart()
        operation = manager.downloadTask(with: downloadReq, progress: { (downloadProgress: Progress) in
            if let pituDelegate = weakSelf?.pituDelegate {
                let progress = CGFloat(downloadProgress.completedUnitCount) / CGFloat(downloadProgress.totalUnitCount)
                pituDelegate.onLoadPituProgress(progress)
            }
        }, destination: { (targetPath_: URL, response: URLResponse) -> URL in
            return URL(fileURLWithPath: targetPath)
        }, completionHandler: { (response: URLResponse, filePath: URL?, error: Error?) in
            weakManager?.invalidateSessionCancelingTasks(true)
            guard error == nil else {
                weakSelf?.pituDelegate?.onLoadPituFailed()
                return
            }

            // Decompression
            var unzipSuccess = false
            let zipArchive = ZipArchive()
            if zipArchive.unzipOpenFile(targetPath) {
                unzipSuccess = zipArchive.unzipFile(to: pituDir, overWrite: true)
                zipArchive.unzipCloseFile()

                // Delete zip file
                try? FileManager.default.removeItem(atPath: targetPath)
            }
            if unzipSuccess {
                weakSelf?.pituDelegate?.onLoadPituFinished()
                weakSelf?.delegate?.onSelectMotionTmpl(pituName, inDir: pituDir)
            } else {
                weakSelf?.pituDelegate?.onLoadPituFailed()
            }
        })
        operation?.resume()
    }

    // MARK: height
    static var height: Int {
        return Int(BeautyViewMargin * 4 + 3 * BeautyViewSliderHeight + BeautyViewCollectionHeight)
    }

    // MARK: Translator
    // Get the secondary menu display name
    private func textAtIndex(_ index: Int, inMenu menuIndex: PanelMenuIndex) -> String {
        var text = optionsContainer[menuIndex.rawValue][index]
        if menuIndex == .motion || menuIndex == .koubei {
            text = getMotionName(text)
        }
        return text
    }

    // Dynamic display name
    private func getMotionName(_ motion: String) -> String {
        if motionNameMap == nil {
            motionNameMap = [
                "video_boom": L("Boom"),
                "video_nihongshu": L("霓虹鼠"),
                "video_3DFace_dogglasses2": L("眼镜狗"),
                "video_fengkuangdacall": L("疯狂打call"),
                "video_Qxingzuo_iOS": L("Q星座"),
                "video_caidai_iOS": L("彩色丝带"),
                "video_liuhaifadai": L("刘海发带"),
                "video_rainbow": L("彩虹云"),
                "video_purplecat": L("紫色小猫"),
                "video_huaxianzi": L("花仙子"),
                "video_baby_agetest": L("小公举"),
                "video_xiaofu": L("AI抠背")
            ]
        }
        return motionNameMap[motion] ?? motion
    }

    func filterImageByIndex(_ index: Int) -> UIImage? {
        let lookupFileName: String
        guard let filterType = FilterType(rawValue: index) else {
            return nil
        }
        switch filterType {
        case .normal:
            lookupFileName = "normal.png"
        case .yinghong:
            lookupFileName = "yinghong.png"
        case .yunshang:
            lookupFileName = "yunshang.png"
        case .chunzhen:
            lookupFileName = "chunzhen.png"
        case .bailan:
            lookupFileName = "bailan.png"
        case .yuanqi:
            lookupFileName = "yuanqi.png"
        case .chaotuo:
            lookupFileName = "chaotuo.png"
        case .xiangfen:
            lookupFileName = "xiangfen.png"
        case .white:
            lookupFileName = "white.png"
        case .langman:
            lookupFileName = "langman.png"
        case .qingxin:
            lookupFileName = "qingxin.png"
        case .weimei:
            lookupFileName = "weimei.png"
        case .fennen:
            lookupFileName = "fennen.png"
        case .huaijiu:
            lookupFileName = "huaijiu.png"
        case .landiao:
            lookupFileName = "landiao.png"
        case .qingliang:
            lookupFileName = "qingliang.png"
        case .rixi:
            lookupFileName = "rixi.png"
        default:
            return nil
        }

        let path = Bundle.main.path(forResource: "FilterResource", ofType: "bundle")
        if let path = path, index != FilterType.none.rawValue {
            let path = URL(fileURLWithPath: path).appendingPathComponent(lookupFileName).path
            let image = UIImage(contentsOfFile: path)
            return image
        }
        return nil
    }

    func filterMixLevelByIndex(_ index: Int) -> Float {
        var newIndex: Int = index
        if index < 0 {
            newIndex = filterMap.count - 1
        }
        if index >= filterMap.count {
            newIndex = index
        }
        return filterMap[newIndex]!
    }

    // Secondary menu
    private lazy var optionsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        view.showsHorizontalScrollIndicator = false
        view.delegate = self
        view.dataSource = self
        view.register(TextCell.self, forCellWithReuseIdentifier: TextCell.reuseIdentifier)
        return view
    }()

    // A menu
    private lazy var menuCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let view = UICollectionView(frame: CGRect.zero, collectionViewLayout: layout)
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
        view.showsHorizontalScrollIndicator = false
        view.delegate = self
        view.dataSource = self
        view.register(TextCell.self, forCellWithReuseIdentifier: TextCell.reuseIdentifier)
        return view
    }()

    // Beauty slider
    private lazy var beautySlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 10
        slider.addTarget(self, action: #selector(self.onValueChanged(_:)), for: .valueChanged)
        return slider
    }()

    // Slider value display
    private lazy var beautyLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .white
        label.textAlignment = .center
        label.text = "0"
        label.textColor = UIColor(red: 10/255.0, green: 204/255.0, blue: 172/255.0, alpha: 1.0)
        return label
    }()

    // Filter slider
    private lazy var filterSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 10
        slider.addTarget(self, action: #selector(self.onValueChanged(_:)), for: .valueChanged)
        return slider
    }()

    // Filter slider value display
    private lazy var filterLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .white
        label.textAlignment = .center
        label.text = "0"
        label.textColor = UIColor(red: 10/255.0, green: 204/255.0, blue: 172/255.0, alpha: 1.0)
        return label
    }()

    // Reset to default
    func resetValues() {
        beautyValueMap.removeAll()
        beautyValueMap[BeautyMenuItem.smooth.rawValue] = 3  // Beauty default (smooth)
        beautyValueMap[BeautyMenuItem.nature.rawValue] = 6  // Beauty default (natural)
        beautyValueMap[BeautyMenuItem.piTu.rawValue] = 5    // Beauty default (everyday PITU)
        beautyValueMap[BeautyMenuItem.white.rawValue] = 1   // Whitening default
        beautyValueMap[BeautyMenuItem.red.rawValue] = 0     // Ruddy default

        whiteLevel = 1
        beautyLevel = 6
        ruddyLevel = 0

        beautySlider.minimumValue = 0
        beautySlider.maximumValue = 10

        let defaultBeautyStyle = BeautyMenuItem.nature
        beautyStyle = .nature
        let beautyValue = Int(beautyValueMap![defaultBeautyStyle.rawValue]!)
        beautySlider.value = Float(beautyValue)
        beautyLabel.text = "\(beautyValue)"
        setSelectedIndexPath(IndexPath(item: defaultBeautyStyle.rawValue, section: 0))

        // Reset filter
        let defaultFilterValue: [Int: Float] = [
            FilterType.none.rawValue: 0,
            FilterType.normal.rawValue: 5,
            FilterType.yinghong.rawValue: 8,
            FilterType.yunshang.rawValue: 8,
            FilterType.chunzhen.rawValue: 7,
            FilterType.bailan.rawValue: 10,
            FilterType.yuanqi.rawValue: 8,
            FilterType.chaotuo.rawValue: 10,
            FilterType.xiangfen.rawValue: 5,
            FilterType.white.rawValue: 3,
            FilterType.langman.rawValue: 3,
            FilterType.qingxin.rawValue: 3,
            FilterType.weimei.rawValue: 3,
            FilterType.fennen.rawValue: 3,
            FilterType.huaijiu.rawValue: 3,
            FilterType.landiao.rawValue: 3,
            FilterType.qingliang.rawValue: 3,
            FilterType.rixi.rawValue: 3
        ]
        filterMap = defaultFilterValue
        let defaultFilter = FilterType.normal
        setSelectedIndexPath(IndexPath(item: defaultFilter.rawValue, section: 0), forMenu: .filter)
        filterSlider.value = Float(Int(defaultFilterValue[defaultFilter.rawValue]!))
        onSetEffectWithIndex(defaultFilter.rawValue)

        currentMenuIndex = .beauty
        menuCollectionView.reloadData()
        optionsCollectionView.reloadData()
        onValueChanged(beautySlider)
        onValueChanged(filterSlider)
    }

    func trigglerValues() {
        onValueChanged(beautySlider)
        onValueChanged(filterSlider)
    }

    private func filterOptions() -> [String] {
        return optionsContainer[PanelMenuIndex.filter.rawValue]
    }

    var currentFilterIndex: Int {
        get {
            return selectedIndexPathForMenu(.filter).item
        }
        set {
            if newValue < 0 {
                self.currentFilterIndex = filterOptions().count - 1
            }
            if newValue >= filterOptions().count {
                self.currentFilterIndex = 0
            }
            setSelectedIndexPath(IndexPath(item: currentFilterIndex, section: 0), forMenu: .filter)
            if currentMenuIndex == .filter {
                optionsCollectionView.reloadData()
            }
        }
    }

    var currentFilterName: String? {
        let index = currentFilterIndex
        let filters = filterOptions()
        if index < filters.count {
            return filters[index]
        }
        return nil
    }
}

extension BeautySettingPanel: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == menuCollectionView {
            return menuArray.count
        }
        return optionsContainer[currentMenuIndex.rawValue].count
    }

    private func selectedIndexPath() -> IndexPath {
        return selectedIndexPathForMenu(currentMenuIndex)
    }

    private func selectedIndexPathForMenu(_ index: PanelMenuIndex) -> IndexPath {
        return selectedIndexMap[index] ?? IndexPath(item: 0, section: 0)
    }

    private func setSelectedIndexPath(_ indexPath: IndexPath) {
        setSelectedIndexPath(indexPath, forMenu: currentMenuIndex)
    }

    private func setSelectedIndexPath(_ indexPath: IndexPath, forMenu menuIndex: PanelMenuIndex) {
        selectedIndexMap[menuIndex] = indexPath
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == menuCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextCell.reuseIdentifier, for: indexPath) as! TextCell
            cell.label.font = UIFont.systemFont(ofSize: UIFont.buttonFontSize)
            cell.label.text = menuArray[indexPath.row]
            cell.isSelected = indexPath.row == currentMenuIndex.rawValue
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextCell.reuseIdentifier, for: indexPath) as! TextCell
            cell.label.font = UIFont.systemFont(ofSize: UIFont.buttonFontSize)
            let text = textAtIndex(indexPath.row, inMenu: currentMenuIndex)
            cell.label.text = text
            cell.isSelected = indexPath == selectedIndexPath()
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == menuCollectionView {
            if indexPath.row != currentMenuIndex.rawValue {
                changeFunction(PanelMenuIndex(rawValue: indexPath.row)!)
            }
        } else {
            // select options
            let prevSelectedIndexPath = selectedIndexPath()
            collectionView.cellForItem(at: prevSelectedIndexPath)?.isSelected = false

            if indexPath == prevSelectedIndexPath {
                // Same as last time selected
                return
            }
            setSelectedIndexPath(indexPath)
            switch currentMenuIndex {
            case .beauty:
                let value = beautyValueMap[indexPath.row] ?? 0

                if indexPath.row < 3 {
                    beautyStyle = PanelBeautyStyle(rawValue: indexPath.item)!
                    beautyLevel = value
                }

                if indexPath.row == 8 {
                    // chin
                    beautySlider.minimumValue = -10
                    beautySlider.maximumValue = 10
                } else {
                    beautySlider.minimumValue = 0
                    beautySlider.maximumValue = 10
                }
                beautyLabel.text = "\(Int(value))"
                beautySlider.setValue(value, animated: false)
                applyBeautySettings()
            case .filter:
                let value = filterMixLevelByIndex(selectedIndexPathForMenu(.filter).item)
                filterSlider.value = value
                filterLabel.text = "\(value)"
                onSetEffectWithIndex(indexPath.row)
                onValueChanged(filterSlider)
            case .motion:
                onSetMotionWithIndex(indexPath.row)
            case .koubei:
                onSetKoubeiWithIndex(indexPath.row)
            case .green:
                onSetGreenWithIndex(indexPath.row)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let text: String
        if collectionView == menuCollectionView {
            text = menuArray[indexPath.row]
        } else {
            text = textAtIndex(indexPath.row, inMenu: currentMenuIndex)
        }

        let font = UIFont.systemFont(ofSize: UIFont.buttonFontSize)
        let size = text.size(withAttributes: [.font: font])
        return CGSize(width: size.width + 2 * BeautyViewMargin, height: collectionView.frame.size.height)
    }
}
