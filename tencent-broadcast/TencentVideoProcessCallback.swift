//
//  TencentVideoProcessCallback.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/04.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import VideoCast
import TXLiteAVSDK_Professional

class TencentVideoProcessCallback: NSObject, TXVideoCustomProcessDelegate {
    weak var source: TencentSource?
    var filter: TencentCustomProcessFilter?

    func onPreProcessTexture(_ texture: GLuint, width: CGFloat, height: CGFloat) -> GLuint {
        //Logger.debug("onPreProcessTexture \(texture), \(width), \(height)")

        if filter == nil {
            filter = TencentCustomProcessFilter()
        }
        if let pixelBuffer = filter?.render(texture, width: Int(width), height: Int(height)) {
            source?.bufferCaptured(pixelBuffer: pixelBuffer)
        }
        return texture
    }

    func onTextureDestoryed() {
        Logger.debug("onTextureDestoryed")
        filter?.destroyFramebuffer()
        filter = nil
    }

    func onDetectFacePoints(_ points: [Any]!) {
        Logger.debug("onDetectFacePoints \(points.count)")
    }

    @objc func orientationChanged(notification: Notification) {
        guard let source = source, !source.orientationLocked else { return }
        DispatchQueue.global().async { [weak self] in
            self?.source?.reorientCamera()
        }
    }
}
