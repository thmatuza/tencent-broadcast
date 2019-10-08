//
//  BeautyLoadPituDelegate.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/08.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import CoreVideo

protocol BeautyLoadPituDelegate: AnyObject {
    func onLoadPituStart()
    func onLoadPituProgress(_ progress: CGFloat)
    func onLoadPituFinished()
    func onLoadPituFailed()
}
