//
//  MetalUtil.swift
//  VideoCast
//
//  Created by Tomohiro Matsuzawa on 2018/08/24.
//  Copyright © 2018年 CyberAgent, Inc. All rights reserved.
//

#if !targetEnvironment(simulator) && !arch(arm)
import Foundation
import GLKit
import Metal

let s_vertexData = [
    Vertex(position: [-1, -1, 0, 1], texcoords: [0, 0]),   // 0
    Vertex(position: [ 1, -1, 0, 1], texcoords: [1, 0]),   // 1
    Vertex(position: [-1, 1, 0, 1], texcoords: [0, 1]),   // 2

    Vertex(position: [ 1, -1, 0, 1], texcoords: [1, 0]),   // 1
    Vertex(position: [ 1, 1, 0, 1], texcoords: [1, 1]),   // 3
    Vertex(position: [-1, 1, 0, 1], texcoords: [0, 1])    // 2
]

class DeviceManager {
    static var device: MTLDevice = { return DeviceManager.sharedManager.device }()
    static var commandQueue: MTLCommandQueue = { return DeviceManager.sharedManager.commandQueue }()

    static var sharedManager = DeviceManager()

    lazy var device: MTLDevice = { return MTLCreateSystemDefaultDevice()! }()
    lazy var commandQueue: MTLCommandQueue = { return device.makeCommandQueue()! }()
}
#endif
