//
//  FisheyeVideoFilter.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/02/13.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

import Foundation
import GLKit

open class FisheyeVideoFilter: BasicVideoFilter {
    open override class var fragmentFunc: String {
        return "fisheye_fragment"
    }

    #if targetEnvironment(simulator) || arch(arm)
    open override var pixelKernel: String? {
        return kernel(language: .GL_ES2_3, target: filterLanguage, kernelstr: """
precision mediump float;
varying vec2      vCoord;
uniform sampler2D uTex0;
void main(void) {
   vec2 uv = vCoord - 0.5;
   float z = sqrt(1.0 - uv.x * uv.x - uv.y * uv.y);
   float a = 1.0 / (z * tan(-5.2)); // FOV
   gl_FragColor = texture2D(uTex0, (uv * a) + 0.5);
}
""")
    }
    #endif
}
