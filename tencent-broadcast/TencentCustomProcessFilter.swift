//
//  TencentCustomProcessFilter.swift
//  tencent-broadcast
//
//  Created by 松澤 友弘 on 2019/10/04.
//  Copyright © 2019 CyberAgent. All rights reserved.
//

import UIKit
import OpenGLES
import GPUImage
import VideoCast

private let kCustomProcessVertexShaderString = """
attribute vec4 position;
attribute vec4 inputTextureCoordinate;

varying vec2 textureCoordinate;

void main()
{
    gl_Position = position;
    textureCoordinate = inputTextureCoordinate.xy;
}
"""

private let kCustomProcessFragmentShaderString = """
varying highp vec2 textureCoordinate;

uniform sampler2D inputImageTexture;

void main()
{
    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);

    gl_FragColor = vec4(textureColor.rgb, textureColor.w);
}
"""

class TencentCustomProcessFilter {
    private let imageVertices: [GLfloat] = [
        -1.0, -1.0,
        1.0, -1.0,
        -1.0, 1.0,
        1.0, 1.0
    ]
    private let noRotationTextureCoordinates: [GLfloat] = [
        0.0, 0.0,
        1.0, 0.0,
        0.0, 1.0,
        1.0, 1.0
    ]

    private var size: CGSize = .init()
    private var pixelBuffer = [CVPixelBuffer?](repeating: nil, count: 2)
    private var textureCache: CVOpenGLESTextureCache?
    private var texture = [CVOpenGLESTexture?](repeating: nil, count: 2)
    private var textureOptions: GPUTextureOptions = .init()

    private var fbo = [GLuint](repeating: 0, count: 2)
    private var currentFb = 0

    private let filterProgram: GLProgram
    private var filterPositionAttribute: GLint = 0
    private var filterTextureCoordinateAttribute: GLint = 0
    private var filterInputTextureUniform: GLint = 0

    init() {
        filterProgram = GLProgram(
            vertexShaderString: kCustomProcessVertexShaderString,
            fragmentShaderString: kCustomProcessFragmentShaderString)
        if !filterProgram.initialized {
            self.initializeAttributes()

            if !filterProgram.link() {
                let progLog = filterProgram.programLog
                Logger.info("Program link log: \(String(describing: progLog))")
                let fragLog = filterProgram.fragmentShaderLog
                Logger.info("Fragment shader compile log: \(String(describing: fragLog))")
                let vertLog = filterProgram.vertexShaderLog
                Logger.info("Vertex shader compile log: \(String(describing: vertLog))")
                assertionFailure("Filter shader link failed")
            }
        }

        filterPositionAttribute = GLint(filterProgram.attributeIndex("position"))
        filterTextureCoordinateAttribute = GLint(filterProgram.attributeIndex("inputTextureCoordinate"))
        // This does assume a name of "inputImageTexture" for the fragment shader
        filterInputTextureUniform = GLint(filterProgram.uniformIndex("inputImageTexture"))

        filterProgram.use()

        glEnableVertexAttribArray(GLuint(filterPositionAttribute))
        glEnableVertexAttribArray(GLuint(filterTextureCoordinateAttribute))

        let defaultTextureOptions = GPUTextureOptions(
            minFilter: GLenum(GL_LINEAR),
            magFilter: GLenum(GL_LINEAR),
            wrapS: GLenum(GL_CLAMP_TO_EDGE),
            wrapT: GLenum(GL_CLAMP_TO_EDGE),
            internalFormat: GLenum(GL_RGBA),
            format: GLenum(GL_BGRA),
            type: GLenum(GL_UNSIGNED_BYTE))
        textureOptions = defaultTextureOptions
    }

    func initializeAttributes() {
        filterProgram.addAttribute("position")
        filterProgram.addAttribute("inputTextureCoordinate")

        // Override this, calling back to this super method, in order to add new attributes to your vertex shader
    }

    private func createDataFBO() {
        if pixelBuffer[0] != nil {
            destroyFramebuffer()
        }

        let pixelBufferOptions: [String: Any] = [
                   kCVPixelBufferIOSurfacePropertiesKey as String: [:]
               ]

        glGenFramebuffers(2, &fbo)
        for i in (0 ... 1) {
            CVPixelBufferCreate(
                kCFAllocatorDefault, Int(size.width), Int(size.height),
                kCVPixelFormatType_32BGRA, pixelBufferOptions as NSDictionary?, &pixelBuffer[i])

            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo[i])

            guard let context = EAGLContext.current() else {
                Logger.error("EAGLContext.current is nil")
                return
            }
            if textureCache == nil {
                CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context, nil, &textureCache)
            }
            guard let textureCache = textureCache else {
                Logger.error("textureCache is nil")
                return
            }
            guard let pixelBuffer = pixelBuffer[i] else {
                Logger.error("pixelBuffer is nil")
                return
            }

            CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer,
                                                                nil, // texture attributes
                GLenum(GL_TEXTURE_2D),
                GLint(textureOptions.internalFormat), // opengl format
                GLsizei(size.width),
                GLsizei(size.height),
                                                                textureOptions.format, // native iOS format
                                                                textureOptions.type,
                                                                0,
                                                                &texture[i])

            guard let texture = texture[i] else {
                Logger.error("texture is nil")
                return
            }

            glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(textureOptions.wrapS))
            glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(textureOptions.wrapT))

            glFramebufferTexture2D(
                GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0),
                GLenum(GL_TEXTURE_2D), CVOpenGLESTextureGetName(texture), 0)

            #if !NS_BLOCK_ASSERTIONS
            let status = glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
            assert(status == GL_FRAMEBUFFER_COMPLETE, "Incomplete filter FBO: \(status)")
            #endif

            glBindTexture(GLenum(GL_TEXTURE_2D), 0)
        }
    }

    private func setFilterFBO(_ i: Int, size: CGSize) {
        if self.size != size {
            self.size = size
            createDataFBO()
        }

        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo[i])

        glViewport(0, 0, GLsizei(size.width), GLsizei(size.height))
    }

    func destroyFramebuffer() {
        glDeleteFramebuffers(2, &fbo)
        fbo[0] = 0
        fbo[1] = 0

        pixelBuffer[0] = nil
        pixelBuffer[1] = nil

        texture[0] = nil
        texture[1] = nil

        textureCache = nil
    }

    func render(_ sourceTexture: GLuint, width: Int, height: Int) -> CVPixelBuffer? {
        filterProgram.use()
        setFilterFBO(currentFb, size: CGSize(width: width, height: height))

        //setUniformsForProgramAt(0)

        glClearColor(0, 0, 0, 0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        glActiveTexture(GLenum(GL_TEXTURE2))
        glBindTexture(GLenum(GL_TEXTURE_2D), sourceTexture)

        glUniform1i(filterInputTextureUniform, 2)

        glVertexAttribPointer(GLuint(filterPositionAttribute), 2, GLenum(GL_FLOAT), 0, 0, imageVertices)
        glVertexAttribPointer(GLuint(filterTextureCoordinateAttribute), 2,
                              GLenum(GL_FLOAT), 0, 0, noRotationTextureCoordinates)

        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)

        guard let buffer = pixelBuffer[currentFb] else {
            Logger.error("pixelBuffer is nil")
            return nil
        }
        return buffer
    }
}
