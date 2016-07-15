/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
import UIKit
import GLKit
import MessageUI
import ImageIO
import QuartzCore
import CoreGraphics

protocol MeshViewDelegate: class {
    func meshViewWillDismiss()
    
    func meshViewDidDismiss()
    
    func meshViewDidRequestColorizing(mesh: STMesh, previewCompletionHandler: () -> Void, enhancedCompletionHandler: () -> Void) -> Bool
}
class MeshViewController: UIViewController, UIGestureRecognizerDelegate, MFMailComposeViewControllerDelegate {
    weak var delegate: MeshViewDelegate?
    var needsDisplay: Bool = false
    // force the view to redraw.
    var colorEnabled: Bool = false
    var mesh: STMesh?
    
    var displayLink: CADisplayLink?
    var renderer: MeshRenderer?
    var viewpointController: ViewpointController!
    var _glViewport: [GLfloat]!
    var modelViewMatrixBeforeUserInteractions: GLKMatrix4?
    var projectionMatrixBeforeUserInteractions: GLKMatrix4?
    
    
    var mailViewController: MFMailComposeViewController?
    
    
    @IBOutlet weak var displayControl: UISegmentedControl!
    @IBOutlet weak var meshViewerMessageLabel: UILabel!
    
    override init(nibName nibNameOrNil: String!, bundle nibBundleOrNil: NSBundle!) {

        
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        //var backButton: UIBarButtonItem = UIBarButtonItem(title: "Back", style: .Plain, target: self, action: "dismissView")
        let backButton: UIBarButtonItem = UIBarButtonItem(title: "Back", style: .Plain, target: self, action: #selector(MeshViewController.dismissView))
        self.navigationItem.leftBarButtonItem = backButton
        //var emailButton: UIBarButtonItem = UIBarButtonItem(title: "Email", style: .Plain, target: self, action: "emailMesh")
        let emailButton: UIBarButtonItem = UIBarButtonItem(title: "Email", style: .Plain, target: self, action: #selector(MeshViewController.emailMesh))
        self.navigationItem.rightBarButtonItem = emailButton

        //if self != nil {
            // Custom initialization
            self.title = "Structure Sensor Scanner"
        //}
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupGestureRecognizer() {
        let pinchScaleGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(MeshViewController.pinchScaleGesture(_:)))
        pinchScaleGesture.delegate = self
        self.view!.addGestureRecognizer(pinchScaleGesture)
        // We'll use one finger pan for rotation.
        let oneFingerPanGesture: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MeshViewController.oneFingerPanGesture(_:)))
        oneFingerPanGesture.delegate = self
        oneFingerPanGesture.maximumNumberOfTouches = 1
        self.view!.addGestureRecognizer(oneFingerPanGesture)
        // We'll use two fingers pan for in-plane translation.
        let twoFingersPanGesture: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MeshViewController.twoFingersPanGesture(_:)))
        twoFingersPanGesture.delegate = self
        twoFingersPanGesture.maximumNumberOfTouches = 2
        twoFingersPanGesture.minimumNumberOfTouches = 2
        self.view!.addGestureRecognizer(twoFingersPanGesture)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.meshViewerMessageLabel.alpha = 0.0
        self.meshViewerMessageLabel.hidden = true
        self.meshViewerMessageLabel.applyCustomStyleWithBackgroundColor(blackLabelColorWithLightAlpha)
        self.renderer = MeshRenderer()
        self.viewpointController = ViewpointController(screenSizeX: Float(self.view.frame.size.width), screenSizeY: Float(self.view.frame.size.height))
        let font: UIFont = UIFont.boldSystemFontOfSize(14.0)
        let attributes: [NSObject : AnyObject] = [
            NSFontAttributeName : font
        ]
        
        self.displayControl.setTitleTextAttributes(attributes, forState: .Normal)
        self.setupGestureRecognizer()
    }
    
    func setLabel(label: UILabel, enabled: Bool) {
        let whiteLightAlpha: UIColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        if enabled {
            label.textColor = UIColor.whiteColor()
        }
        else {
            label.textColor = whiteLightAlpha
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if displayLink != nil {
            displayLink!.invalidate()
            self.displayLink = nil
        }
        //self.displayLink = CADisplayLink.displayLinkWithTarget(self, selector: "draw")
        //self.displayLink = CADisplayLink.displayLinkWithTarget(self, selector: #selector(MeshViewController.draw))
        
        self.displayLink = CADisplayLink(target: self, selector: #selector(MeshViewController.draw))
        
        
        displayLink!.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
        viewpointController.reset()
        if !self.colorEnabled {
            self.displayControl.removeSegmentAtIndex(2, animated: false)
        }
        self.displayControl.selectedSegmentIndex = 1
    }


    
    // Local Helper Functions
    
    func saveJpegFromRGBABuffer(filename: String, src_buffer: UnsafeMutablePointer<Void>, width: Int, height: Int)
    {
        let file: UnsafeMutablePointer<FILE> = fopen(filename, "w")
        if file == nil {
            return
        }
        var colorSpace: CGColorSpaceRef?
        var alphaInfo: CGImageAlphaInfo
        var context: CGContextRef
        colorSpace = CGColorSpaceCreateDeviceRGB()
        alphaInfo = .NoneSkipLast
        //context = CGBitmapContextCreate(src_buffer, width, height, 8, width * 4, colorSpace, alphaInfo)
        context = CGBitmapContextCreate(src_buffer, width, height, 8, width * 4, colorSpace, alphaInfo.rawValue)!
        let rgbImage: CGImageRef? = CGBitmapContextCreateImage(context)
        //CGContextRelease(context)
        //CGColorSpaceRelease(colorSpace)

        let jpgData: CFMutableDataRef = CFDataCreateMutable(nil, 0)
        let imageDest: CGImageDestinationRef? = CGImageDestinationCreateWithData(jpgData, "public.jpeg", 1, nil)
        
        //var options: CFDictionaryRef = CFDictionaryCreate(kCFAllocatorDefault,             // Our empty IOSurface properties dictionary
        //    nil, nil, 0, kCFTypeDictionaryKeyCallBacks, kCFTypeDictionaryValueCallBacks)
        
        let options: CFDictionaryRef = CFDictionaryCreate(kCFAllocatorDefault,             // Our empty IOSurface properties dictionary
            nil, nil, 0, nil, nil)
        
        CGImageDestinationAddImage(imageDest!, rgbImage!, (options ))
        CGImageDestinationFinalize(imageDest!)
        //CFRelease(imageDest)
        //CFRelease(options)
        //CGImageRelease(rgbImage)
        fwrite(CFDataGetBytePtr(jpgData), 1, CFDataGetLength(jpgData), file)
        fclose(file)
        //CFRelease(jpgData)
    }
    
    
    override func didReceiveMemoryWarning () {
        
    }
    
    func setupGL (context: EAGLContext) {

        //HACK I disabled this because it doesn't seem there's any way to cast self.view to EAGLView
        //(self.view as EAGLView).context = context
        
        //EAGLContext.currentContext = context
        EAGLContext.setCurrentContext(context)
        renderer!.initializeGL(GLenum(GL_TEXTURE0)) //HACK not sure what parameter to use - in the Obj C code nothing is passed in but it works
        (self.view as! EAGLView).setFramebuffer()
        let framebufferSize: CGSize = (self.view as! EAGLView).getFramebufferSize()
        var imageAspectRatio: CGFloat = 1.0
        // The iPad's diplay conveniently has a 4:3 aspect ratio just like our video feed.
        // Some iOS devices need to render to only a portion of the screen so that we don't distort
        // our RGB image. Alternatively, you could enlarge the viewport (losing visual information),
        // but fill the whole screen.
        if abs(framebufferSize.width / framebufferSize.height - 640.0 / 480.0) > 1e-3 {
            imageAspectRatio = 480.0 / 640.0
        }
        
        self._glViewport[0] = Float(framebufferSize.width - framebufferSize.width * imageAspectRatio) / 2
        self._glViewport[1] = 0
        self._glViewport[2] = Float(framebufferSize.width * imageAspectRatio)
        self._glViewport[3] = Float(framebufferSize.height)
    }
    
    func dismissView () {
        
//        if self.delegate.respondsToSelector("meshViewWillDismiss") {
            self.delegate?.meshViewWillDismiss()
//        }
        renderer!.releaseGLBuffers()
        renderer!.releaseGLTextures()
        displayLink!.invalidate()
        self.displayLink = nil
        self.mesh = nil
        //(self.view as! EAGLView).context = nil
        EAGLContext.setCurrentContext(nil)
        self.dismissViewControllerAnimated(true, completion: {() -> Void in
            //if self.delegate?.respondsToSelector("meshViewDidDismiss") {
                self.delegate?.meshViewDidDismiss()
            //}
        })
        
        
    }
    
    func setCameraProjectionMatrix (projection: GLKMatrix4) {
        viewpointController.setCameraProjection(projection)
        self.projectionMatrixBeforeUserInteractions = projection
    }
    
    func resetMeshCenter (center: GLKVector3) {
        viewpointController.reset()
        viewpointController.setMeshCenter(center)
        self.modelViewMatrixBeforeUserInteractions = viewpointController.currentGLModelViewMatrix()
    }
    
    //HACK had to rename this function because Method setMesh with Objective-C selector setMesh: conflicts with setter for mesh with the same Objective-C selector
    func setDisplayMesh (meshRef: STMesh?) {
        self.mesh = meshRef
        if meshRef != nil {
            renderer!.uploadMesh(meshRef!)
            self.trySwitchToColorRenderingMode()
            self.needsDisplay = true
        }
    }
    
    //MARK: Email Mesh OBJ File
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        self.mailViewController?.dismissViewControllerAnimated(true, completion: { _ in })
    }
    
    
    struct RgbaPixel {
//        var rgba: [uint8_t4]
        var rgba: [UInt8]
    }
    
//    func convertToBytes(i: UInt32) -> [UInt8]{
//        
//        
//    }
    
    func prepareScreenShot (screenshotPath: String) {
        let width: Int32 = 320
        let height: Int32 = 240
        //var currentFrameBuffer: GLint
        let currentFrameBuffer: UnsafeMutablePointer<GLint> = nil
        glGetIntegerv(UInt32(GL_FRAMEBUFFER_BINDING), currentFrameBuffer)
        // Create temp texture, framebuffer, renderbuffer
        
        glViewport(0, 0, width, height)
        
        
        let outputTexture: UnsafeMutablePointer<GLuint> = nil
        glActiveTexture(UInt32(GL_TEXTURE0))
        glGenTextures(1, outputTexture)
        glBindTexture(UInt32(GL_TEXTURE_2D), outputTexture.memory)
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(UInt32(GL_TEXTURE_2D), UInt32(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        glTexImage2D(UInt32(GL_TEXTURE_2D), 0, GL_RGBA, width, height, 0, UInt32(GL_RGBA), UInt32(GL_UNSIGNED_BYTE), nil)
        let colorFrameBuffer: UnsafeMutablePointer<GLuint> = nil
        let depthRenderBuffer: UnsafeMutablePointer<GLuint> = nil
        glGenFramebuffers(1, colorFrameBuffer)
        glBindFramebuffer(UInt32(GL_FRAMEBUFFER), colorFrameBuffer.memory)
        glGenRenderbuffers(1, depthRenderBuffer)
        glBindRenderbuffer(UInt32(GL_RENDERBUFFER), depthRenderBuffer.memory)
        glRenderbufferStorage(UInt32(GL_RENDERBUFFER), UInt32(GL_DEPTH_COMPONENT16), width, height)
        glFramebufferRenderbuffer(UInt32(GL_FRAMEBUFFER), UInt32(GL_DEPTH_ATTACHMENT), UInt32(GL_RENDERBUFFER), depthRenderBuffer.memory)
        glFramebufferTexture2D(UInt32(GL_FRAMEBUFFER), UInt32(GL_COLOR_ATTACHMENT0), UInt32(GL_TEXTURE_2D), outputTexture.memory, 0)
        
        // Keep the current render mode
        
        let previousRenderingMode: MeshRenderer.RenderingMode = renderer!.getRenderingMode()
        let meshToRender: STMesh = mesh!
        
        // Screenshot rendering mode, always use colors if possible.

        if meshToRender.hasPerVertexUVTextureCoords() && meshToRender.meshYCbCrTexture() != nil {
            renderer!.setRenderingMode(MeshRenderer.RenderingMode.RenderingModeTextured)
        } else if meshToRender.hasPerVertexColors() {
        
        } else {
            // meshToRender can be nil if there is no available color mesh.
        }
        
        // Render from the initial viewpoint for the screenshot.
        renderer!.clear()
        // Added address of operators because render requires UnsafePointer parameters
        renderer!.render(&projectionMatrixBeforeUserInteractions!, modelViewMatrix: &modelViewMatrixBeforeUserInteractions!)
        // Back to current render mode
        renderer!.setRenderingMode(previousRenderingMode)
        
        
        
        //vector < RgbaPixel > screenShotRgbaBuffer(width * height)
        
        //I hope this is set up properly, glReadPixels wants a MutablePointer as its last parameter
        var screenShotRgbaBuffer : RgbaPixel = RgbaPixel(rgba: [UInt8]())
        glReadPixels(0, 0, width, height, UInt32(GL_RGBA), UInt32(GL_UNSIGNED_BYTE), &screenShotRgbaBuffer)
        
        // We need to flip the axis, because OpenGL reads out the buffer from the bottom.
        //    std::vector<RgbaPixel> rowBuffer (width);
        
        //HACK disabled this section due to challenges figuring out type conversions
        
//        var rowBuffer = RgbaPixel(rgba: width)
//        for var h = 0; h < height / 2; ++h {
//            var screenShotDataTopRow: RgbaPixel = screenShotRgbaBuffer.data() + h * width
//            var screenShotDataBottomRow: RgbaPixel = screenShotRgbaBuffer.data() + (height - h - 1) * width
//            // Swap the top and bottom rows, using rowBuffer as a temporary placeholder.
//            memcpy(rowBuffer.data(), screenShotDataTopRow, width * sizeof())
//            memcpy(&screenShotDataTopRow, screenShotDataBottomRow, width * sizeof())
//            memcpy(screenShotDataBottomRow, rowBuffer.data(), width * sizeof())
//        }
        
        
        
        //screenshotPath().UTF8String(), reinterpret_cast < uint8_t * (screenShotRgbaBuffer.data()), width, height)
        //        saveJpegFromRGBABuffer(screenshotPath: String, screenshotr
        // Back to the original frame buffer
        glBindFramebuffer(UInt32(GL_FRAMEBUFFER), UInt32(currentFrameBuffer.memory))
        glViewport(GLint(_glViewport[0]), GLint(_glViewport[1]), GLint(_glViewport[2]), GLint(_glViewport[3]))
        // Free the data
        glDeleteTextures(1, outputTexture)
        glDeleteFramebuffers(1, colorFrameBuffer)
        glDeleteRenderbuffers(1, depthRenderBuffer)
    }
    
    //HACK temporarily disabled in order to progress to other problems
    func emailMesh() {
        
//        self.mailViewController = MFMailComposeViewController()
//        if self.mailViewController != nil {
//            var alert: UIAlertController = UIAlertController(title: "The email could not be sent.", message: "Please make sure an email account is properly setup on this device.", preferredStyle: .Alert)
//            var defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: .Default, handler: {(action: UIAlertAction) -> Void in
//            })
//            alert.addAction(defaultAction)
//            self.presentViewController(alert, animated: true, completion: { _ in })
//            return
//        }
//        self.mailViewController!.mailComposeDelegate = self
//        if UI_USER_INTERFACE_IDIOM() == .Pad {
//            self.mailViewController!.modalPresentationStyle = UIModalPresentationStyle.FormSheet
//        }
//        var cacheDirectory: String = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0]
//        var zipFilename: String = "Model.zip"
//        var screenshotFilename: String = "Preview.jpg"
//        var zipPath: String = cacheDirectory.stringByAppendingPathComponent(zipFilename)
//        var screenshotPath: String = cacheDirectory.stringByAppendingPathComponent(screenshotFilename)
//        self.prepareScreenShot(screenshotPath)
//        self.mailViewController?.setSubject("3D Model")
//        var messageBody: String = "This model was captured with the open source Scanner sample app in the Structure SDK.\n\nCheck it out!\n\nMore info about the Structure SDK: http://structure.io/developers"
//        self.mailViewController.setMessageBody(messageBody, isHTML: false)
//        var options: [NSObject : AnyObject] = [kSTMeshWriteOptionFileFormatKey: .ObjFileZip]
//        var error: NSError
//        var meshToSend: STMesh = mesh
//        var success: Bool = meshToSend.writeToFile(zipPath, options: options, error: error)
//        if !success {
//            self.mailViewController = nil
//            var alert: UIAlertController = UIAlertController.alertControllerWithTitle("The email could not be sent.", message: "Exporting failed: \(error.localizedDescription).", preferredStyle: .Alert)
//            var defaultAction: UIAlertAction = UIAlertAction.actionWithTitle("OK", style: .Default, handler: {(action: UIAlertAction) -> Void in
//            })
//            alert.addAction(defaultAction)
//            self.presentViewController(alert, animated: true, completion: { _ in })
//            return
//        }
//        self.mailViewController.addAttachmentData(NSData.dataWithContentsOfFile(screenshotPath), mimeType: "image/jpeg", fileName: screenshotFilename)
//        self.mailViewController.addAttachmentData(NSData.dataWithContentsOfFile(zipPath), mimeType: "application/zip", fileName: zipFilename)
//        self.presentViewController(self.mailViewController, animated: true, completion: {() -> Void in
//        })
    }
    //MARK: Rendering
    func draw () {
        
        (self.view as! EAGLView).setFramebuffer()
        glViewport(GLint(_glViewport[0]), GLint(_glViewport[1]), GLint(_glViewport[2]), GLint(_glViewport[3]))
        
        let viewpointChanged: Bool = viewpointController.update()
        // If nothing changed, do not waste time and resources rendering.
        if !needsDisplay && !viewpointChanged {
            return
        }
        var currentModelView: GLKMatrix4 = viewpointController.currentGLModelViewMatrix()
        var currentProjection: GLKMatrix4 = viewpointController.currentGLProjectionMatrix()
        renderer!.clear()
        renderer!.render(&currentProjection, modelViewMatrix: &currentModelView)
        self.needsDisplay = false
        (self.view as! EAGLView).presentFramebuffer()
    }
    
    
    //MARK: Touch & Gesture Control
    func pinchScaleGesture(gestureRecognizer: UIPinchGestureRecognizer) {
        // Forward to the ViewpointController.
        if gestureRecognizer.state == .Began {
            viewpointController.onPinchGestureBegan(Float(gestureRecognizer.scale))
        }
        else if gestureRecognizer.state == .Changed {
            viewpointController.onPinchGestureChanged(Float(gestureRecognizer.scale))
        }
    }
    
    func oneFingerPanGesture(gestureRecognizer: UIPanGestureRecognizer) {
        let touchPos: CGPoint = gestureRecognizer.locationInView(self.view!)
        let touchVel: CGPoint = gestureRecognizer.velocityInView(self.view!)
        let touchPosVec: GLKVector2 = GLKVector2Make(Float(touchPos.x), Float(touchPos.y))
        let touchVelVec: GLKVector2 = GLKVector2Make(Float(touchVel.x), Float(touchVel.y))
        if gestureRecognizer.state == .Began {
            viewpointController.onOneFingerPanBegan(touchPosVec)
        }
        else if gestureRecognizer.state == .Changed {
            viewpointController.onOneFingerPanChanged(touchPosVec)
        }
        else if gestureRecognizer.state == .Ended {
            viewpointController.onOneFingerPanEnded(touchVelVec)
        }
        
    }
    
    func twoFingersPanGesture(gestureRecognizer: UIPanGestureRecognizer) {
        if gestureRecognizer.numberOfTouches() != 2 {
            return
        }
        let touchPos: CGPoint = gestureRecognizer.locationInView(self.view!)
        let touchVel: CGPoint = gestureRecognizer.velocityInView(self.view!)
        let touchPosVec: GLKVector2 = GLKVector2Make(Float(touchPos.x), Float(touchPos.y))
        let touchVelVec: GLKVector2 = GLKVector2Make(Float(touchVel.x), Float(touchVel.y))
        if gestureRecognizer.state == .Began {
            viewpointController.onTwoFingersPanBegan(touchPosVec)
        }
        else if gestureRecognizer.state == .Changed {
            viewpointController.onTwoFingersPanChanged(touchPosVec)
        }
        else if gestureRecognizer.state == .Ended {
            viewpointController.onTwoFingersPanEnded(touchVelVec)
        }
        
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        viewpointController.onTouchBegan()
    }
    
    //MARK: UI Control
    
    func trySwitchToColorRenderingMode() {
        // Choose the best available color render mode, falling back to LightedGray
        // This method may be called when colorize operations complete, and will
        // switch the render mode to color, as long as the user has not changed
        // the selector.
        if self.displayControl.selectedSegmentIndex == 2 {
            if mesh!.hasPerVertexUVTextureCoords() {
                
            } else if mesh!.hasPerVertexColors() {
                //renderer.setRenderingMode(MeshRenderer::RenderingModePerVertexColor)
            }
        }
    }
    
    @IBAction func displayControlChanged(sender: AnyObject) {
        switch self.displayControl.selectedSegmentIndex {
        case 0: // x-ray
            
            break;
        case 1: // lighted-gray
            
            break;
        case 2: // color
            self.trySwitchToColorRenderingMode()
            let meshIsColorized: Bool = mesh!.hasPerVertexColors() || mesh!.hasPerVertexUVTextureCoords()
            if !meshIsColorized {
                self.colorizeMesh()
                
            }
            break;
        default:
            break;
        }
        needsDisplay = true
    }
    
    func colorizeMesh() {
        self.delegate?.meshViewDidRequestColorizing(mesh!, previewCompletionHandler: {() -> Void in
            }, enhancedCompletionHandler: {() -> Void in
                // Hide progress bar.
                self.hideMeshViewerMessage()
        })
    }
    
    func hideMeshViewerMessage() {
        UIView.animateWithDuration(0.5, animations: {() -> Void in
            self.meshViewerMessageLabel.alpha = 0.0
            }, completion: {(finished: Bool) -> Void in
                self.meshViewerMessageLabel.hidden = true
        })
    }
    
    func showMeshViewerMessage(msg: String) {
        self.meshViewerMessageLabel.text = msg
        if self.meshViewerMessageLabel.hidden == true {
            self.meshViewerMessageLabel.hidden = false
            self.meshViewerMessageLabel.alpha = 0.0
            UIView.animateWithDuration(0.5, animations: {() -> Void in
                self.meshViewerMessageLabel.alpha = 1.0
            })
        }
    }
}