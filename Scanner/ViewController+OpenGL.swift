/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
import UIKit
import AVFoundation
//#define HAS_LIBCXX

extension ViewController {
    func setupGL() {
        // Create an EAGLContext for our EAGLView.
        self.display?.context = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
        if (display!.context == nil) {
            NSLog("Failed to create ES context")
        }
        EAGLContext.setCurrentContext(display!.context)
        (self.view as! EAGLView).context = display!.context
        (self.view as! EAGLView).setFramebuffer()
        self.display!.yCbCrTextureShader = STGLTextureShaderYCbCr()
        self.display!.rgbaTextureShader = STGLTextureShaderRGBA()
        // Set up texture and textureCache for images output by the color camera.
        let texError: CVReturn = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, display!.context!, nil, &display!.videoTextureCache)
        if texError != 0 { // HACK changed this from nil to 0
            NSLog("Error at CVOpenGLESTextureCacheCreate %d", texError)
        }
        glGenTextures(1, &display!.depthAsRgbaTexture!)
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), display!.depthAsRgbaTexture!)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
    }
    
    func nearlyEqual (a: Float, b: Float) -> Bool {
        //HACK not sure if this is proper
        return abs(a-b) < Float.Stride()
    };
    
    //    func nearlyEqual(a: float, b: float, epsilon: float) -> bool {
    //    final float absA = Math.abs(a);
    //    final float absB = Math.abs(b);
    //    final float diff = Math.abs(a - b);
    //
    //    if (a == b) { // shortcut, handles infinities
    //    return true;
    //    } else if (a == 0 || b == 0 || diff < Float.MIN_NORMAL) {
    //    // a or b is zero or both are extremely close to it
    //    // relative error is less meaningful here
    //    return diff < (epsilon * Float.MIN_NORMAL);
    //    } else { // use relative error
    //    return diff / (absA + absB) < epsilon;
    //    }
    //    }
    
    func setupGLViewport() {
        let vgaAspectRatio: Float = 640.0 / 480.0
        // Helper function to handle float precision issues.
        
        
        
        //        var a: Float
        //        var b): Float
        //        {
        //            return
        //                        abs(a - b) < std::
        //            var epsilon: numeric_limits<Float>
        //        }
        var frameBufferSize: CGSize = (self.view as! EAGLView).getFramebufferSize()
        var imageAspectRatio: Float = 1.0
        var framebufferAspectRatio: Float = Float(frameBufferSize.width) / Float(frameBufferSize.height)
        // The iPad's diplay conveniently has a 4:3 aspect ratio just like our video feed.
        // Some iOS devices need to render to only a portion of the screen so that we don't distort
        // our RGB image. Alternatively, you could enlarge the viewport (losing visual information),
        // but fill the whole screen.
        if !nearlyEqual(framebufferAspectRatio, b: vgaAspectRatio) {
            imageAspectRatio = 480.0 / 640.0
        }
        self.display!.viewport![0] = 0
        self.display!.viewport![1] = 0
        self.display!.viewport![2] = Float(frameBufferSize.width) * imageAspectRatio
        self.display!.viewport![3] = Float(frameBufferSize.height)
    }
    
    func uploadGLColorTexture(colorFrame: STColorFrame) {
        
        var colorFrame = colorFrame
        
        if (display!.videoTextureCache == nil) {
            NSLog("Cannot upload color texture: No texture cache is present.")
            return
        }
        // Clear the previous color texture.
        if (display!.lumaTexture != nil) {
            //CFRelease(display.lumaTexture)
            self.display!.lumaTexture = nil
        }
        // Clear the previous color texture
        if (display!.chromaTexture != nil) {
            //CFRelease(display.chromaTexture)
            self.display!.chromaTexture = nil
        }
        // Displaying image with width over 1280 is an overkill. Downsample it to save bandwidth.
        while colorFrame.width > 2560 {
            colorFrame = colorFrame.halfResolutionColorFrame
        }
        var err: CVReturn
        // Allow the texture cache to do internal cleanup.
        CVOpenGLESTextureCacheFlush(display!.videoTextureCache!, 0)
        var pixelBuffer: CVImageBufferRef = CMSampleBufferGetImageBuffer(colorFrame.sampleBuffer)!
        var width: size_t = CVPixelBufferGetWidth(pixelBuffer)
        var height: size_t = CVPixelBufferGetHeight(pixelBuffer)
        var pixelFormat: OSType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, "YCbCr is expected!")
        // Activate the default texture unit.
        glActiveTexture(GLenum(GL_TEXTURE0))
        // Create an new Y texture from the video texture cache.
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, display!.videoTextureCache!, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GLint(GL_RED_EXT), GLsizei(width), GLsizei(height), GLenum(GL_RED_EXT), GLenum(GL_UNSIGNED_BYTE), 0, &display!.lumaTexture)
        if err != 0 { // HACK changed this to 0 instead of nil
            NSLog("Error with CVOpenGLESTextureCacheCreateTextureFromImage: %d", err)
            return
        }
        // Set good rendering properties for the new texture.
        glBindTexture(CVOpenGLESTextureGetTarget(display!.lumaTexture!), CVOpenGLESTextureGetName(display!.lumaTexture!))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        // Activate the default texture unit.
        glActiveTexture(GLenum(GL_TEXTURE1))
        // Create an new CbCr texture from the video texture cache.
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, display!.videoTextureCache!, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RG_EXT, Int32(width) / 2, Int32(height) / 2, GLenum(GL_RG_EXT), GLenum(GL_UNSIGNED_BYTE), 1, &display!.chromaTexture)
        if err != 0 { // HACK changed this to 0 instead of nil
            NSLog("Error with CVOpenGLESTextureCacheCreateTextureFromImage: %d", err)
            return
        }
        // Set rendering properties for the new texture.
        glBindTexture(CVOpenGLESTextureGetTarget(display!.chromaTexture!), CVOpenGLESTextureGetName(display!.chromaTexture!))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
    }
    
    func uploadGLColorTextureFromDepth(depthFrame: STDepthFrame) {
        depthAsRgbaVisualizer!.convertDepthFrameToRgba(depthFrame)
        glActiveTexture(GLenum(GL_TEXTURE0))
        glBindTexture(GLenum(GL_TEXTURE_2D), display!.depthAsRgbaTexture!)
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, depthAsRgbaVisualizer!.width, depthAsRgbaVisualizer!.height, 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), depthAsRgbaVisualizer!.rgbaBuffer)
    }
    
    func renderSceneForDepthFrame(depthFrame: STDepthFrame, colorFrameOrNil colorFrame: STColorFrame?) {
        // Activate our view framebuffer.
        (self.view as! EAGLView).setFramebuffer()
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        glClear(GLbitfield(GL_DEPTH_BUFFER_BIT))
        glViewport(GLint(display!.viewport![0]), GLint(display!.viewport![1]), GLint(display!.viewport![2]), GLint(display!.viewport![3]))
        switch slamState.scannerState {
        case .CubePlacement:
            // Render the background image from the color camera.
            self.renderCameraImage()
            if slamState.cameraPoseInitializer!.hasValidPose {
                var depthCameraPose: GLKMatrix4 = slamState.cameraPoseInitializer!.cameraPose
                var cameraViewpoint: GLKMatrix4
                var alpha: Float
                if useColorCamera {
                    // Make sure the viewpoint is always to color camera one, even if not using registered depth.
                    var colorCameraPoseInStreamCoordinateSpace: GLKMatrix4 = GLKMatrix4()
                    
                    var m = self.arrayForTuple(colorCameraPoseInStreamCoordinateSpace.m)
                    depthFrame.colorCameraPoseInDepthCoordinateFrame(&m)
                    // colorCameraPoseInWorld
                    cameraViewpoint = GLKMatrix4Multiply(depthCameraPose, colorCameraPoseInStreamCoordinateSpace)
                    alpha = 0.5
                }
                else {
                    cameraViewpoint = depthCameraPose
                    alpha = 1.0
                }
                // Highlighted depth values inside the current volume area.
                display!.cubeRenderer.renderHighlightedDepthWithCameraPose(cameraViewpoint, alpha: alpha)
                // Render the wireframe cube corresponding to the current scanning volume.
                display!.cubeRenderer.renderCubeOutlineWithCameraPose(cameraViewpoint, depthTestEnabled: false, occlusionTestEnabled: true)
            }
            
        case .Scanning:
            // Enable GL blending to show the mesh with some transparency.
            glEnable(GLenum(GL_BLEND))
            // Render the background image from the color camera.
            self.renderCameraImage()
            // Render the current mesh reconstruction using the last estimated camera pose.
            var depthCameraPose: GLKMatrix4 = slamState.tracker!.lastFrameCameraPose()
            var cameraGLProjection: GLKMatrix4
            if useColorCamera {
                cameraGLProjection = colorFrame!.glProjectionMatrix()
            }
            else {
                cameraGLProjection = depthFrame.glProjectionMatrix()
            }
            var cameraViewpoint: GLKMatrix4
            if useColorCamera && !options.useHardwareRegisteredDepth {
                // If we want to use the color camera viewpoint, and are not using registered depth, then
                // we need to deduce the color camera pose from the depth camera pose.
                var colorCameraPoseInDepthCoordinateSpace: GLKMatrix4 = GLKMatrix4()
                
                var m = self.arrayForTuple(colorCameraPoseInDepthCoordinateSpace.m)
                depthFrame.colorCameraPoseInDepthCoordinateFrame(&m)
                // colorCameraPoseInWorld
                cameraViewpoint = GLKMatrix4Multiply(depthCameraPose, colorCameraPoseInDepthCoordinateSpace)
            }
            else {
                cameraViewpoint = depthCameraPose
            }
            slamState.scene!.renderMeshFromViewpoint(cameraViewpoint, cameraGLProjection: cameraGLProjection, alpha: 0.8, highlightOutOfRangeDepth: true, wireframe: false)
            glDisable(GLenum(GL_BLEND))
            // Render the wireframe cube corresponding to the scanning volume.
            // Here we don't enable occlusions to avoid performance hit.
            display!.cubeRenderer.renderCubeOutlineWithCameraPose(cameraViewpoint, depthTestEnabled: true, occlusionTestEnabled: false)
            
        // MeshViewerController handles this.
        default:
            break
        }
        
        // Check for OpenGL errors
        var err: GLenum = glGetError()
        if err != GLenum(GL_NO_ERROR) {
            NSLog("glError = %x", err)
        }
        // Display the rendered framebuffer.
        (self.view as! EAGLView).presentFramebuffer()
    }
    
    func renderCameraImage() {
        if useColorCamera {
            if display!.lumaTexture == nil || display!.chromaTexture == nil {
                return
            }
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(CVOpenGLESTextureGetTarget(display!.lumaTexture!), CVOpenGLESTextureGetName(display!.lumaTexture!))
            glActiveTexture(GLenum(GL_TEXTURE1))
            glBindTexture(CVOpenGLESTextureGetTarget(display!.chromaTexture!), CVOpenGLESTextureGetName(display!.chromaTexture!))
            glDisable(GLenum(GL_BLEND))
            display!.yCbCrTextureShader.useShaderProgram()
            display!.yCbCrTextureShader.renderWithLumaTexture(GL_TEXTURE0, chromaTexture: GL_TEXTURE1)
        }
        else {
            if display!.depthAsRgbaTexture == 0 {
                return
            }
            glActiveTexture(GLenum(GL_TEXTURE0))
            glBindTexture(GLenum(GL_TEXTURE_2D), display!.depthAsRgbaTexture!)
            display!.rgbaTextureShader.useShaderProgram()
            display!.rgbaTextureShader.renderTexture(GL_TEXTURE0)
        }
        glUseProgram(0)
    }
}