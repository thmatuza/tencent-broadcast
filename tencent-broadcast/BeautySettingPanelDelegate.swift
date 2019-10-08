//
//  BeautySettingPanelDelegate.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/08.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import UIKit

protocol BeautySettingPanelDelegate: AnyObject {
    func onSetBeautyStyle(_ beautyStyle: Int, beautyLevel: Float, whitenessLevel: Float, ruddinessLevel: Float)
    func onSetMixLevel(_ mixLevel: Float)
    func onSetEyeScaleLevel(_ eyeScaleLevel: Float)
    func onSetFaceScaleLevel(_ faceScaleLevel: Float)
    func onSetFaceVLevel(_ vLevel: Float)
    func onSetChinLevel(_ chinLevel: Float)
    func onSetFaceShortLevel(_ shortLevel: Float)
    func onSetNoseSlimLevel(_ slimLevel: Float)
    func onSetFilter(_ filterImage: UIImage?)
    func onSetGreenScreenFile(_ file: URL?)
    func onSelectMotionTmpl(_ tmplName: String?, inDir tmplDir: String?)
}
