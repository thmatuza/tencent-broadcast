//
//  TencentSessionDelegate.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/04.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import VideoCast

open class TencentSessionDelegate: NSObject {
    open var connectionStatusChanged: ((_ sessionState: VCSessionState) -> Void)?
    open var didAddCameraSource: ((_ session: TencentSession) -> Void)?
    open var detectedThroughput: ((_ throughputInBytesPerSecond: Int, _ videorate: Int, _ oBitrate: Int) -> Void)?
    open var bitrateChanged: ((_ videoBitrate: Int, _ audioBitrate: Int) -> Void)?

    public override init() {
        super.init()
    }
}
