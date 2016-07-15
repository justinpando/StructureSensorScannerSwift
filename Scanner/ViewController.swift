/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
import UIKit
import AVFoundation
//#define HAS_LIBCXX

struct Options {
    // The initial scanning volume size will be 0.5 x 0.5 x 0.5 meters
    // (X is left-right, Y is up-down, Z is forward-back)
    var initialVolumeSizeInMeters: GLKVector3 = GLKVector3Make(0.5, 0.5, 0.5)
    // Volume resolution in meters
    var initialVolumeResolutionInMeters: CGFloat = 0.004
    // 4 mm per voxel
    // The maximum number of keyframes saved in keyFrameManager
    var maxNumKeyFrames: Int = 48
    // Colorizer quality
    var colorizerQuality: STColorizerQuality = STColorizerQuality.HighQuality
    // Take a new keyframe in the rotation difference is higher than 20 degrees.
    var maxKeyFrameRotation: CGFloat = CGFloat(20.0 * (M_PI / 180.0))
    // 20 degrees
    // Take a new keyframe if the translation difference is higher than 30 cm.
    var maxKeyFrameTranslation: CGFloat = 0.3
    // 30cm
    // Threshold to consider that the rotation motion was small enough for a frame to be accepted
    // as a keyframe. This avoids capturing keyframes with strong motion blur / rolling shutter.
    var maxKeyframeRotationSpeedInDegreesPerSecond: CGFloat = 1.0
    // Whether we should use depth aligned to the color viewpoint when Structure Sensor was calibrated.
    // This setting may get overwritten to false if no color camera can be used.
    var useHardwareRegisteredDepth: Bool = true
    // Whether the colorizer should try harder to preserve appearance of the first keyframe.
    // Recommended for face scans.
    var prioritizeFirstFrameColor: Bool = true
    // Target number of faces of the final textured mesh.
    var colorizerTargetNumFaces: Int = 50000
    // Focus position for the color camera (between 0 and 1). Must remain fixed one depth streaming
    // has started when using hardware registered depth.
    let lensPosition: CGFloat = 0.75
}

enum ScannerState : Int    // Defining the volume to scan
{
    case CubePlacement = 0
    // Scanning
    case Scanning
    // Visualizing the mesh
    case Viewing
    case NumStates
}

// SLAM-related members.
struct SlamData {
    
    var initialized : Bool
    var showingMemoryWarning : Bool = false
    
    var prevFrameTimeStamp : NSTimeInterval = -1.0
    var scene : STScene?
    var tracker : STTracker?
    var mapper : STMapper?
    var cameraPoseInitializer : STCameraPoseInitializer?
    var keyFrameManager : STKeyFrameManager?
    var scannerState : ScannerState
    
    init(initialized: Bool, scannerState : ScannerState) {
        self.initialized = initialized
        self.scannerState = scannerState
    }
    
    
}

// Utility struct to manage a gesture-based scale.
struct PinchScaleState {
    
    var currentScale: CGFloat
    var initialPinchScale: CGFloat
    
    init(currentScale : CGFloat, initialPinchScale : CGFloat)
    {
        self.currentScale = currentScale
        self.initialPinchScale = initialPinchScale
    }
    
}

struct AppStatus {
    let pleaseConnectSensorMessage: String = "Please connect Structure Sensor."
    let pleaseChargeSensorMessage: String = "Please charge Structure Sensor."
    let needColorCameraAccessMessage: String = "This app requires camera access to capture color.\nAllow access by going to Settings → Privacy → Camera."
    enum SensorStatus : Int {
        case Ok
        case NeedsUserToConnect
        case NeedsUserToCharge
    }
    // Structure Sensor status.
    var sensorStatus: SensorStatus = SensorStatus.Ok
    // Whether iOS camera access was granted by the user.
    var colorCameraIsAuthorized: Bool = true
    // Whether there is currently a message to show.
    var needsDisplayOfStatusMessage: Bool = false
    // Flag to disable entirely status message display.
    var statusMessageDisabled: Bool = false
}

// Display related members.
struct DisplayData {
    init() {
        
    }
    
    // OpenGL context.
    var context : EAGLContext?
    // OpenGL Texture reference for y images.
    var lumaTexture: CVOpenGLESTextureRef?
    // OpenGL Texture reference for color images.
    var chromaTexture: CVOpenGLESTextureRef?
    // OpenGL Texture cache for the color camera.
    var videoTextureCache: CVOpenGLESTextureCacheRef?
    // Shader to render a GL texture as a simple quad.
    var yCbCrTextureShader: STGLTextureShaderYCbCr!
    var rgbaTextureShader: STGLTextureShaderRGBA!
    var depthAsRgbaTexture: GLuint? 
    // Renders the volume boundaries as a cube.
    var cubeRenderer: STCubeRenderer!
    // OpenGL viewport.
    var viewport: [GLfloat]?
    // OpenGL projection matrix for the color camera.
    var colorCameraGLProjectionMatrix: GLKMatrix4? = GLKMatrix4Identity
    // OpenGL projection matrix for the depth camera.
    var depthCameraGLProjectionMatrix: GLKMatrix4? = GLKMatrix4Identity
}

class ViewController: UIViewController, STBackgroundTaskDelegate, MeshViewDelegate, UIPopoverControllerDelegate, UIGestureRecognizerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    // Structure Sensor controller.
    var sensorController: STSensorController!
    var structureStreamConfig: STStreamConfig!
    var slamState: SlamData!
    var options: Options!
    // Manages the app status messages.
    var appStatus: AppStatus!
    var display: DisplayData? = DisplayData()
    // Most recent gravity vector from IMU.
    var lastGravity: GLKVector3!
    // Scale of the scanning volume.
    var volumeScale: PinchScaleState!
    // Mesh viewer controllers.
    var meshViewNavigationController: UINavigationController?
    var meshViewController: MeshViewController!
    // IMU handling.
    var motionManager: CMMotionManager?
    var imuQueue: NSOperationQueue?
    var naiveColorizeTask: STBackgroundTask?
    var enhancedColorizeTask: STBackgroundTask?
    var depthAsRgbaVisualizer: STDepthToRgba?
    var useColorCamera: Bool = true
    var calibrationOverlay: CalibrationOverlay?
    
    var avCaptureSession: AVCaptureSession?
    var videoDevice: AVCaptureDevice?
    @IBOutlet weak var appStatusMessageLabel: UILabel!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var trackingLostLabel: UILabel!
    @IBOutlet weak var enableNewTrackerSwitch: UISwitch!
    @IBOutlet weak var enableHighResolutionColorSwitch: UISwitch!
    @IBOutlet weak var enableNewTrackerView: UIView!
    
    @IBAction func enableNewTrackerSwitchChanged(sender: AnyObject) {
        // Save the volume size.
        var previousVolumeSize: GLKVector3 = options.initialVolumeSizeInMeters
        if slamState.initialized {
            previousVolumeSize = slamState.mapper!.volumeSizeInMeters
        }
        // Simulate a full reset to force a creation of a new tracker.
        self.resetButtonPressed(self.resetButton)
        self.clearSLAM()
        self.setupSLAM()
        // Restore the volume size cleared by the full reset.
        self.slamState.mapper!.volumeSizeInMeters = previousVolumeSize
        self.adjustVolumeSize(slamState.mapper!.volumeSizeInMeters)
    }
    
    @IBAction func enableHighResolutionColorSwitchChanged(sender: AnyObject) {
        if (self.avCaptureSession != nil) {
            self.stopColorCamera()
            if useColorCamera {
                self.startColorCamera()
            }
        }
        // Force a scan reset since we cannot changing the image resolution during the scan is not
        // supported by STColorizer.
        self.resetButtonPressed(self.resetButton)
    }
    
    @IBAction func scanButtonPressed(sender: AnyObject) {
        self.enterScanningState()
    }
    
    @IBAction func resetButtonPressed(sender: AnyObject) {
        self.resetSLAM()
    }
    
    @IBAction func doneButtonPressed(sender: AnyObject) {
        self.enterViewingState()
    }
    
    func enterCubePlacementState() {
        // Switch to the Scan button.
        self.scanButton.hidden = false
        self.doneButton.hidden = true
        self.resetButton.hidden = true
        // We'll enable the button only after we get some initial pose.
        self.scanButton.enabled = false
        // Cannot be lost in cube placement mode.
        self.trackingLostLabel.hidden = true
        self.setColorCameraParametersForInit()
        self.slamState.scannerState = .CubePlacement
        self.updateIdleTimer()
    }
    
    func enterScanningState() {
        // Switch to the Done button.
        self.scanButton.hidden = true
        self.doneButton.hidden = false
        self.resetButton.hidden = false
        // Tell the mapper if we have a support plane so that it can optimize for it.
        slamState.mapper!.setHasSupportPlane(slamState.cameraPoseInitializer!.hasSupportPlane)
        self.slamState.tracker!.initialCameraPose = slamState.cameraPoseInitializer!.cameraPose
        // We will lock exposure during scanning to ensure better coloring.
        self.setColorCameraParametersForScanning()
        self.slamState.scannerState = .Scanning
    }
    
    func enterViewingState() {
        // Cannot be lost in view mode.
        self.hideTrackingErrorMessage()
        self.appStatus.statusMessageDisabled = true
        self.updateAppStatusMessage()
        // Hide the Scan/Done/Reset button.
        self.scanButton.hidden = true
        self.doneButton.hidden = true
        self.resetButton.hidden = true
        sensorController.stopStreaming()
        if useColorCamera {
            self.stopColorCamera()
        }
        slamState.mapper!.finalizeTriangleMeshWithSubsampling(1)
        let mesh: STMesh = slamState.scene!.lockAndGetSceneMesh()
        self.presentMeshViewer(mesh)
        slamState.scene!.unlockSceneMesh()
        self.slamState.scannerState = .Viewing
        self.updateIdleTimer()
    }
    
    func adjustVolumeSize(volumeSize: GLKVector3) {
        // Make sure the volume size remains between 10 centimeters and 10 meters.
        let newVolumeSize = GLKVector3(v:(
            Float(keepInRange(CGFloat(volumeSize.x), minValue: 0.1, maxValue: 10.0)),
            Float(keepInRange(CGFloat(volumeSize.y), minValue: 0.1, maxValue: 10.0)),
            Float(keepInRange(CGFloat(volumeSize.z), minValue: 0.1, maxValue: 10.0)))
        )

//        volumeSize.x = keepInRange(volumeSize.x, minValue: 0.1, maxValue: 10.0)
//        volumeSize.y = keepInRange(volumeSize.y, minValue: 0.1, maxValue: 10.0)
//        volumeSize.z = keepInRange(volumeSize.z, minValue: 0.1, maxValue: 10.0)
        self.slamState.mapper!.volumeSizeInMeters = newVolumeSize
        self.slamState.cameraPoseInitializer!.volumeSizeInMeters = newVolumeSize
        display!.cubeRenderer.adjustCubeSize(slamState.mapper!.volumeSizeInMeters, volumeResolution: slamState.mapper!.volumeResolution)
    }
    
    func updateAppStatusMessage() {
        // Skip everything if we should not show app status messages (e.g. in viewing state).
        if appStatus.statusMessageDisabled {
            self.hideAppStatusMessage()
            return
        }
        // First show sensor issues, if any.
        switch appStatus.sensorStatus {
        case AppStatus.SensorStatus.Ok:
            break
        case AppStatus.SensorStatus.NeedsUserToConnect:
            self.showAppStatusMessage(appStatus.pleaseConnectSensorMessage)
            return
            
        case AppStatus.SensorStatus.NeedsUserToCharge:
            self.showAppStatusMessage(appStatus.pleaseChargeSensorMessage)
            return
            
        }
        
        // Then show color camera permission issues, if any.
        if !appStatus.colorCameraIsAuthorized {
            self.showAppStatusMessage(appStatus.needColorCameraAccessMessage)
            return
        }
        // If we reach this point, no status to show.
        self.hideAppStatusMessage()
    }
    
    func currentStateNeedsSensor() -> Bool {
        switch slamState.scannerState {
        // Initialization and scanning need the sensor.
        case .CubePlacement, .Scanning:
            return true
        // Other states don't need the sensor.
        default:
            return false
        }
        
    }
    
    func updateIdleTimer() {
        if self.isStructureConnectedAndCharged() && self.currentStateNeedsSensor() {
            // Do not let the application sleep if we are currently using the sensor data.
            UIApplication.sharedApplication().idleTimerDisabled = true
        }
        else {
            // Let the application sleep if we are only viewing the mesh or if no sensors are connected.
            UIApplication.sharedApplication().idleTimerDisabled = false
        }
    }
    
    func showTrackingMessage(message: String) {
        self.trackingLostLabel.text = message
        self.trackingLostLabel.hidden = false
    }
    
    func hideTrackingErrorMessage() {
        self.trackingLostLabel.hidden = true
    }
    
    func processDeviceMotion(motion: CMDeviceMotion) { //HACK - removed withError parameter because it doesn't seem to be used
        if slamState.scannerState == .CubePlacement {
            // Update our gravity vector, it will be used by the cube placement initializer.
            self.lastGravity = GLKVector3Make(Float(motion.gravity.x), Float(motion.gravity.y), Float(motion.gravity.z))
        }
        if slamState.scannerState == .CubePlacement || slamState.scannerState == .Scanning {
            // The tracker is more robust to fast moves if we feed it with motion data.
            slamState.tracker!.updateCameraPoseWithMotion(motion)
        }
    }
    
//    func dealloc() {
//        self.avCaptureSession.stopRunning()
//        if EAGLContext.currentContext() == display.context {
//            EAGLContext.currentContext = nil
//        }
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.calibrationOverlay = nil
        self.setupGL()
        self.setupUserInterface()
        self.setupMeshViewController()
        self.setupGestures()
        self.setupIMU()
        self.setupStructureSensor()
        // Later, we’ll set this true if we have a device-specific calibration
        self.useColorCamera = STSensorController.approximateCalibrationGuaranteedForDevice()
        // Make sure we get notified when the app becomes active to start/restore the sensor state if necessary.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.appDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        // The framebuffer will only be really ready with its final size after the view appears.
        (self.view as! EAGLView).setFramebuffer()
        self.setupGLViewport()
        self.updateAppStatusMessage()
        // We will connect to the sensor when we receive appDidBecomeActive.
    }
    
    func appDidBecomeActive() {
        if self.currentStateNeedsSensor() {
            self.connectToStructureSensorAndStartStreaming()
        }
        // Abort the current scan if we were still scanning before going into background since we
        // are not likely to recover well.
        if slamState.scannerState == .Scanning {
            self.resetButtonPressed(self)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.respondToMemoryWarning()
    }
    
    func setupUserInterface() {
        // Make sure the status bar is hidden.
        UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: .Slide)
        // Fully transparent message label, initially.
        self.appStatusMessageLabel.alpha = 0
        // Make sure the label is on top of everything else.
        self.appStatusMessageLabel.layer.zPosition = 100
        // Set the default value for the high resolution switch. If set, will use 2592x1968 as color input.
        self.enableHighResolutionColorSwitch.on = getDefaultHighResolutionSettingForCurrentDevice()
    }
    // Make sure the status bar is disabled (iOS 7+)
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func setupGestures() {
        // Register pinch gesture for volume scale adjustment.
        let pinchGesture: UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(ViewController.pinchGesture(_:)))
        pinchGesture.delegate = self
        self.view!.addGestureRecognizer(pinchGesture)
    }
    
    func setupMeshViewController() {
        // The mesh viewer will be used after scanning.
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            self.meshViewController = MeshViewController(nibName: "MeshView_iPhone", bundle: nil)
        }
        else {
            self.meshViewController = MeshViewController(nibName: "MeshView_iPad", bundle: nil)
        }
        self.meshViewController.delegate = self
        self.meshViewNavigationController = UINavigationController(rootViewController: meshViewController)
    }
    
    func presentMeshViewer(mesh: STMesh) {
        //meshViewController.upGL = display.context
        meshViewController.setupGL(display!.context!)
        self.meshViewController.colorEnabled = useColorCamera
        self.meshViewController.mesh = mesh
        
        //meshViewController.cameraProjectionMatrix = display.depthCameraGLProjectionMatrix
        meshViewController.setCameraProjectionMatrix(display!.depthCameraGLProjectionMatrix!)
        
        let volumeCenter: GLKVector3 = GLKVector3MultiplyScalar(slamState.mapper!.volumeSizeInMeters, 0.5)
        meshViewController.resetMeshCenter(volumeCenter)
        self.presentViewController(meshViewNavigationController!, animated: true, completion: {() -> Void in
        })
    }

    func keepInRange(value: CGFloat, minValue: CGFloat, maxValue: CGFloat) -> CGFloat
    {
        if isnan(value) {
            return minValue
        }
        if value > maxValue {
            return maxValue
        }
        if value < minValue {
            return minValue
        }
        return value
    }
    
    func setupIMU() {
        self.lastGravity = GLKVector3Make(0, 0, 0)
        // 60 FPS is responsive enough for motion events.
        let fps: CGFloat = 60.0
        self.motionManager = CMMotionManager()
        self.motionManager!.accelerometerUpdateInterval = 1.0 / Double(fps)
        self.motionManager!.gyroUpdateInterval = 1.0 / Double(fps)
        // Limiting the concurrent ops to 1 is a simple way to force serial execution
        self.imuQueue = NSOperationQueue()
        imuQueue!.maxConcurrentOperationCount = 1
        weak var weakSelf: ViewController? = self
        
        let dmHandler: CMDeviceMotionHandler = {(motion: CMDeviceMotion?, error: NSError?) -> Void in
            // Could be nil if the self is released before the callback happens.
            if weakSelf != nil {
                weakSelf!.processDeviceMotion(motion!)
            }
        }
        motionManager!.startDeviceMotionUpdatesToQueue(imuQueue!, withHandler: dmHandler)
    }
    
    func handleDeviceMotion(motion: CMDeviceMotion, error: NSError) -> Void {
        
    }
    
    // Manages whether we can let the application sleep.
    func showAppStatusMessage(msg: String) {
        self.appStatus.needsDisplayOfStatusMessage = true
        self.view.layer.removeAllAnimations()
        self.appStatusMessageLabel.text = msg
        self.appStatusMessageLabel.hidden = false
        // Progressively show the message label.
        self.view!.userInteractionEnabled = false
        UIView.animateWithDuration(0.5, animations: {() -> Void in
            self.appStatusMessageLabel.alpha = 1.0
            }, completion: { _ in })
    }
    
    func hideAppStatusMessage() {
        if !appStatus.needsDisplayOfStatusMessage {
            return
        }
        self.appStatus.needsDisplayOfStatusMessage = false
        self.view.layer.removeAllAnimations()
        weak var weakSelf: ViewController? = self
        UIView.animateWithDuration(0.5, animations: {() -> Void in
            weakSelf!.appStatusMessageLabel.alpha = 0.0
            }, completion: {(finished: Bool) -> Void in
                // If nobody called showAppStatusMessage before the end of the animation, do not hide it.
                if !self.appStatus.needsDisplayOfStatusMessage {
                    // Could be nil if the self is released before the callback happens.
                    if weakSelf != nil {
                        weakSelf!.appStatusMessageLabel.hidden = true
                        weakSelf!.view!.userInteractionEnabled = true
                    }
                }
        })
    }
    
    func pinchGesture(gestureRecognizer: UIPinchGestureRecognizer) {
        if gestureRecognizer.state == .Began {
            if slamState.scannerState == .CubePlacement {
                self.volumeScale.initialPinchScale = volumeScale.currentScale / gestureRecognizer.scale
            }
        }
        else if gestureRecognizer.state == .Changed {
            if slamState.scannerState == .CubePlacement {
                // In some special conditions the gesture recognizer can send a zero initial scale.
                if !isnan(volumeScale.initialPinchScale) {
                    self.volumeScale.currentScale = gestureRecognizer.scale * volumeScale.initialPinchScale
                    // Don't let our scale multiplier become absurd
                    
                    self.volumeScale.currentScale = keepInRange(self.volumeScale.currentScale, minValue: 0.01, maxValue: 1000.0)
                    let newVolumeSize: GLKVector3 = GLKVector3MultiplyScalar(options.initialVolumeSizeInMeters, Float(volumeScale.currentScale))
                    self.adjustVolumeSize(newVolumeSize)
                }
            }
        }
        
    }
    
    func meshViewWillDismiss() {
        // If we are running colorize work, we should cancel it.
        if naiveColorizeTask != nil {
            naiveColorizeTask!.cancel()
            self.naiveColorizeTask = nil
        }
        if enhancedColorizeTask != nil {
            enhancedColorizeTask!.cancel()
            self.enhancedColorizeTask = nil
        }
        meshViewController.hideMeshViewerMessage()
    }
    
    func meshViewDidDismiss() {
        self.appStatus.statusMessageDisabled = false
        self.updateAppStatusMessage()
        self.connectToStructureSensorAndStartStreaming()
        self.resetSLAM()
    }
    
    //    USAGE:
    //
    //    A. To run a process in the background with a delay of 3 seconds:
    //
    //    backgroundThread(3.0, background: {
    //    // Your background function here
    //    })
    //    B. To run a process in the background then run a completion in the foreground:
    //
    //    backgroundThread(background: {
    //    // Your function here to run in the background
    //    },
    //    completion: {
    //    // A function to run in the foreground when the background thread is complete
    //    })
    //    C. To delay by 3 seconds - note use of completion parameter without background parameter:
    //
    //    backgroundThread(3.0, completion: {
    //    // Your delayed function here to be run in the foreground
    //    })
    
    func backgroundThread(delay: Double = 0.0, background: (() -> Void)? = nil, completion: (() -> Void)? = nil) {
        dispatch_async(dispatch_get_global_queue(Int(QOS_CLASS_USER_INITIATED.rawValue), 0)) {
            if(background != nil){ background!(); }
            
            let popTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
            dispatch_after(popTime, dispatch_get_main_queue()) {
                if(completion != nil){ completion!(); }
            }
        }
    }
//Original code for background Task, note that dispath_async was lost in the Swiftity translation
//    - (void)backgroundTask:(STBackgroundTask *)sender didUpdateProgress:(double)progress
//    {
//    if (sender == _naiveColorizeTask)
//    {
//    dispatch_async(dispatch_get_main_queue(), ^{
//    [_meshViewController showMeshViewerMessage:[NSString stringWithFormat:@"Processing: % 3d%%", int(progress*20)]];
//    });
//    }
//    else if (sender == _enhancedColorizeTask)
//    {
//    dispatch_async(dispatch_get_main_queue(), ^{
//    [_meshViewController showMeshViewerMessage:[NSString stringWithFormat:@"Processing: % 3d%%", int(progress*80)+20]];
//    });
//    }
//    }
    
    
    //HACK fix this in order to update UI during background task. Maybe do research on a swift specific way to do this rather than the translated code below
    func backgroundTask(sender: STBackgroundTask, didUpdateProgress progress: Double) {
        if sender == naiveColorizeTask {
//            dispatch_get_main_queue()
//            {
//                    var showMeshViewerMessage: _meshViewController
//                    "Processing: % 3d%%"
//                    Int(progress)
//                    20
//            }
        }
        else if sender == enhancedColorizeTask {
//            dispatch_get_main_queue()
//                {
//                    var showMeshViewerMessage: _meshViewController
//                    "Processing: % 3d%%"
//                    Int(progress)
//                    80
//            }
        }
        
    }
    
//    class func; /* Selector parsing error */ {
//    }
    //HACK need to actually fix this
    func meshViewDidRequestColorizing(mesh: STMesh, previewCompletionHandler: () -> Void, enhancedCompletionHandler: () -> Void) -> Bool {
//        if naiveColorizeTask != nil {
//            NSLog("Already one colorizing task running!")
//            return false
//        }
//        self.naiveColorizeTask = STColorizer.newColorizeTaskWithMesh(mesh, scene: slamState.scene, keyframes: slamState.keyFrameManager.getKeyFrames(), completionHandler: { (error: NSError?) -> Void in
//            if error != nil {
//                NSLog("Error during colorizing: %@", error!.localizedDescription())
//            }
//            else {
//                dispatch_async(dispatch_get_main_queue(), {() -> Void in
//                    previewCompletionHandler()
//                    self.meshViewController.mesh = mesh
//                    self.performEnhancedColorize((mesh as! STMesh), enhancedCompletionHandler: enhancedCompletionHandler)
//                })
//                self.naiveColorizeTask = nil
//                
//            }
//            }, options: [kSTColorizerTypeKey: STColorizerType.PerVertex, kSTColorizerPrioritizeFirstFrameColorKey: options.prioritizeFirstFrameColor])
//        if naiveColorizeTask != nil {
//            self.naiveColorizeTask!.delegate = self
//            naiveColorizeTask!.start()
//            return true
//        }
        return false
    }
    
    
    
//    func performEnhancedColorize(mesh: STMesh, enhancedCompletionHandler: () -> Void) {
//        
//        self.enhancedColorizeTask = STColorizer.newColorizeTaskWithMesh(mesh, scene: slamState.scene, keyframes: slamState.keyFrameManager.getKeyFrames(), completionHandler: {(error: NSError?) -> Void in
//            
//            if error != nil {
//                NSLog("Error during colorizing: %@", error!.localizedDescription())
//            }
//            else
//            {
//                dispatch_async(dispatch_get_main_queue(), {() -> Void in
//                    enhancedCompletionHandler()
//                    self.meshViewController.mesh = mesh
//                })
//                self.enhancedColorizeTask = nil
//            }
//             options: [kSTColorizerTypeKey: STColorizerType.TextureMapForObject, kSTColorizerPrioritizeFirstFrameColorKey: options.prioritizeFirstFrameColor, kSTColorizerQualityKey: options.colorizerQuality, kSTColorizerTargetNumberOfFacesKey: options.colorizerTargetNumFaces])
//        if enhancedColorizeTask != nil {
//            // We don't need the keyframes anymore now that the final colorizing task was started.
//            // Clearing it now gives a chance to early release the keyframe memory when the colorizer
//            // stops needing them.
//            slamState.keyFrameManager.clear()
//            self.enhancedColorizeTask!.delegate = self
//            enhancedColorizeTask!.start()
//        }
//    }
    
    func respondToMemoryWarning() {
        switch slamState.scannerState {
        case .Viewing:
            // If we are running a colorizing task, abort it
            if enhancedColorizeTask != nil && !slamState.showingMemoryWarning {
                self.slamState.showingMemoryWarning = true
                // stop the task
                enhancedColorizeTask!.cancel()
                self.enhancedColorizeTask = nil
                // hide progress bar
                meshViewController.hideMeshViewerMessage()
                let alertCtrl: UIAlertController = UIAlertController(title: "Memory Low", message: "Colorizing was canceled.", preferredStyle: .Alert)
                let okAction: UIAlertAction = UIAlertAction(title: "OK", style: .Default, handler: {(action: UIAlertAction) -> Void in
                    self.slamState.showingMemoryWarning = false
                })
                alertCtrl.addAction(okAction)
                // show the alert in the meshViewController
                meshViewController.presentViewController(alertCtrl, animated: true, completion: { _ in })
            }
            
        case .Scanning:
            if !slamState.showingMemoryWarning {
                self.slamState.showingMemoryWarning = true
                let alertCtrl: UIAlertController = UIAlertController(title: "Memory Low", message: "Scanning will be stopped to avoid loss.", preferredStyle: .Alert)
                let okAction: UIAlertAction = UIAlertAction(title: "OK", style: .Default, handler: {(action: UIAlertAction) -> Void in
                    self.slamState.showingMemoryWarning = false
                    self.enterViewingState()
                })
                alertCtrl.addAction(okAction)
                // show the alert
                self.presentViewController(alertCtrl, animated: true, completion: { _ in })
            }
            
        default: break
            // not much we can do here
            
        }
        
    }
    
    func getPlatform() -> String {
        
        let kernelStringName = "hw.machine"
        var deviceModel: String
        //HACK size_t assigned zero in order to initialize it
        var size: size_t = 0
        sysctlbyname(kernelStringName, nil, &size, nil, 0)
        
        var machine = [CChar](count: Int(size), repeatedValue:0)
        sysctlbyname(kernelStringName, &machine, &size, nil, 0)
        // Now, get the string itself
        //deviceModel = String.stringWithUTF8String(stringNullTerminated)
        deviceModel = String(machine)
        
        return deviceModel
        //free(stringNullTerminated)
        
    
    }
    
    // anonymous namespace for local functions.
    func isIpadAir2() -> Bool
    {
        let deviceModel = getPlatform()
        
        if (deviceModel == "iPad5,3") {
            return true
        }
        // Wi-Fi
        if (deviceModel == "iPad5,4") {
            return true
        }
        // Wi-Fi + LTE
        return false
    }
    func getDefaultHighResolutionSettingForCurrentDevice() -> Bool
    {
        // iPad Air 2 can handle 30 FPS high-resolution, so enable it by default.
        if isIpadAir2() {
            return true
        }
        // Older devices can only handle 15 FPS high-resolution, so keep it disabled by default
        // to avoid showing a low framerate.
        return false
    }
}