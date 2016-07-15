/*
  This file is part of the Structure SDK.
  Copyright © 2015 Occipital, Inc. All rights reserved.
  http://structure.io
*/
import UIKit
import OpenGLES

import QuartzCore
//import mach

// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
// The view content is basically an EAGL surface you render your OpenGL scene into.
// Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
class EAGLView: UIView {
    var context: EAGLContext?

    
    // The pixel dimensions of the CAEAGLLayer.
    var framebufferWidth: GLint = 0
    var framebufferHeight: GLint = 0
    // The OpenGL ES names for the framebuffer and renderbuffer used to render to this view.
    var defaultFramebuffer: GLuint = 0
    var colorRenderbuffer: GLuint = 0
    var depthRenderbuffer: GLuint = 0
    
    func setEAGLContext (newContext: EAGLContext?) {

        if context != newContext {
            self.deleteFramebuffer()
            context = newContext!
            
            EAGLContext.setCurrentContext(nil)
        }
        
    }


    func setFramebuffer() {
        if context != nil {
            EAGLContext.setCurrentContext(context)
            if defaultFramebuffer == 0 {
                self.createFramebuffer()
            }
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), defaultFramebuffer)
            glViewport(0, 0, framebufferWidth, framebufferHeight)
        }
    }

    func presentFramebuffer() -> Bool {
        var success: Bool = false
        // iOS may crash if presentRenderbuffer is called when the application is in background.
        if context != nil && UIApplication.sharedApplication().applicationState != .Background {
            EAGLContext.setCurrentContext(context)
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderbuffer)
            success = context!.presentRenderbuffer(Int(GL_RENDERBUFFER))
        }
        return success
    }

    func getFramebufferSize() -> CGSize {
        return CGSizeMake(CGFloat(framebufferWidth), CGFloat(framebufferHeight))
    }

    // You must implement this method

    override class func layerClass() -> AnyClass {
        return CAEAGLLayer.self
    }
    
    //The EAGL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:.
    required init(coder: NSCoder) {
        super.init(coder: coder)!
        
        let eaglLayer: CAEAGLLayer = (self.layer as! CAEAGLLayer)
        eaglLayer.opaque = true
        eaglLayer.drawableProperties = [
            kEAGLDrawablePropertyRetainedBacking : Int(false),
            kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8
        ]
        
        self.contentScaleFactor = 1.0
    }
// HACK  I don't think we need this any more in Swift
//    func dealloc() {
//        self.deleteFramebuffer()
//    }

    func createFramebuffer() {
        if context != nil && defaultFramebuffer == 0 {
            EAGLContext.setCurrentContext(context)
            // Create default framebuffer object.
            glGenFramebuffers(1, &defaultFramebuffer)
            glBindFramebuffer(GLenum(GL_FRAMEBUFFER), defaultFramebuffer)
            // Create color render buffer and allocate backing store.
            glGenRenderbuffers(1, &colorRenderbuffer)
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderbuffer)
            context!.renderbufferStorage(Int(GL_RENDERBUFFER), fromDrawable: (self.layer as! CAEAGLLayer))
            glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &framebufferWidth)
            glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &framebufferHeight)
            glGenRenderbuffers(1, &depthRenderbuffer)
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), depthRenderbuffer)
            glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT16), framebufferWidth, framebufferHeight)
            glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), depthRenderbuffer)
            glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorRenderbuffer)
            glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), colorRenderbuffer)
            if glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) != GLenum(GL_FRAMEBUFFER_COMPLETE) {
                NSLog("Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)))
            }
        }
    }

    func deleteFramebuffer() {
        if context != nil {
            EAGLContext.setCurrentContext(context)
            if defaultFramebuffer != 0 {
                glDeleteFramebuffers(1, &defaultFramebuffer)
                defaultFramebuffer = 0
            }
            if depthRenderbuffer != 0 {
                glDeleteRenderbuffers(1, &depthRenderbuffer)
                depthRenderbuffer = 0
            }
            if colorRenderbuffer != 0 {
                glDeleteRenderbuffers(1, &colorRenderbuffer)
                colorRenderbuffer = 0
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // CAREFUL!!!! If you have autolayout enabled, you will re-create your framebuffer all the time if
        // your EAGLView has any subviews that are updated. For example, having a UILabel that is updated
        // to display FPS will result in layoutSubviews being called every frame. Two ways around this:
        // 1) don't use autolayout
        // 2) don't add any subviews to the EAGLView. Have the EAGLView be a subview of another "master" view.
        // The framebuffer will be re-created at the beginning of the next setFramebuffer method call.
        self.deleteFramebuffer()
    }


}
