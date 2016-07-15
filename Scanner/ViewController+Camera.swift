/*
  This file is part of the Structure SDK.
  Copyright © 2015 Occipital, Inc. All rights reserved.
  http://structure.io
*/
import UIKit
import AVFoundation
//#define HAS_LIBCXX
//import Structure

extension ViewController  {
    func startColorCamera() {
        if self.avCaptureSession != nil && self.avCaptureSession!.running {
            return
        }
        // Re-setup so focus is lock even when back from background
        if self.avCaptureSession == nil {
            self.setupColorCamera()
        }
        // Start streaming color images.
        self.avCaptureSession!.startRunning()
    }

    func stopColorCamera() {
        if self.avCaptureSession != nil && self.avCaptureSession!.running {
            return
        }
        
        if self.avCaptureSession!.running{
            // Stop the session
            self.avCaptureSession!.stopRunning()
        }
        self.avCaptureSession = nil
        self.videoDevice = nil
    }

    func setColorCameraParametersForInit() {
        //var error: NSError
        do {
            try self.videoDevice?.lockForConfiguration()
            
        } catch {
            
        }
        // Auto-exposure
        if self.videoDevice != nil && (self.videoDevice?.isExposureModeSupported(.ContinuousAutoExposure))! {
            self.videoDevice?.exposureMode = .ContinuousAutoExposure
        }
        // Auto-white balance.
        if ((self.videoDevice?.isWhiteBalanceModeSupported(.ContinuousAutoWhiteBalance)) != nil) {
            self.videoDevice?.whiteBalanceMode = .ContinuousAutoWhiteBalance
        }
        self.videoDevice!.unlockForConfiguration()
    }

    func setColorCameraParametersForScanning() {
        //var error: NSError
        do {
            try self.videoDevice!.lockForConfiguration()
        
        } catch {
            
        }
        // Exposure locked to its current value.
        if self.videoDevice!.isExposureModeSupported(.Locked) {
            self.videoDevice!.exposureMode = .Locked
        }
        // White balance locked to its current value.
        if self.videoDevice!.isWhiteBalanceModeSupported(.Locked) {
            self.videoDevice!.whiteBalanceMode = .Locked
        }
        self.videoDevice!.unlockForConfiguration()
    }

    func setLensPositionWithValue(value: Float, lockVideoDevice: Bool) {
        if self.videoDevice == nil {
            return
        }
        // Abort if there's no videoDevice yet.
        if lockVideoDevice {
            do {
                try self.videoDevice!.lockForConfiguration()
            } catch _ {
                return
                // Abort early if we cannot lock and are asked to.
            }
        }
        self.videoDevice!.setFocusModeLockedWithLensPosition(value, completionHandler: nil)
        if lockVideoDevice {
            self.videoDevice!.unlockForConfiguration()
        }
    }

    func queryCameraAuthorizationStatusAndNotifyUserIfNotGranted() -> Bool {
        let numCameras: Int = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count
        if 0 == numCameras {
            return false
        }
            // This can happen even on devices that include a camera, when camera access is restricted globally.
        let authStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
        if authStatus != .Authorized {
            NSLog("Not authorized to use the camera!")
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: {(granted: Bool) -> Void in
                // This block fires on a separate thread, so we need to ensure any actions here
                // are sent to the right place.
                // If the request is granted, let's try again to start an AVFoundation session.
                // Otherwise, alert the user that things won't go well.
                if granted {
                    dispatch_async(dispatch_get_main_queue(), {() -> Void in
                        self.startColorCamera()
                        self.appStatus.colorCameraIsAuthorized = true
                        self.updateAppStatusMessage()
                    })
                }
            })
            return false
        }
        return true
    }

    func selectCaptureFormat(demandFormat: NSDictionary) {
        var selectedFormat: AVCaptureDeviceFormat? = nil
        //HACK not sure what formats should be or if I can actually cast it this way
        for format: AVCaptureDeviceFormat in self.videoDevice!.formats as! [AVCaptureDeviceFormat] {
            //var formatMaxFps: Double = ((format.videoSupportedFrameRateRanges[0] as! AVFrameRateRange)).maxFrameRate
            let formatDesc: CMFormatDescriptionRef = format.formatDescription
            let fourCharCode: FourCharCode = CMFormatDescriptionGetMediaSubType(formatDesc)
            let videoFormatDesc: CMVideoFormatDescriptionRef = formatDesc
            let formatDims: CMVideoDimensions = CMVideoFormatDescriptionGetDimensions(videoFormatDesc)
            let widthNeeded: Int32 = demandFormat["width"] as! Int32
            let heightNeeded: Int32 = demandFormat["height"] as! Int32
            if widthNeeded != formatDims.width {

            }
            if heightNeeded != formatDims.height {

            }
            // we only support full range YCbCr for now
            if fourCharCode != (FourCharCode("420f")) {
                continue
            }
            selectedFormat = format
        }
        self.videoDevice!.activeFormat = selectedFormat!
    }

    func setupColorCamera() {
        // If already setup, skip it
        if (self.avCaptureSession != nil) {
            return
        }
        let cameraAccessAuthorized: Bool = self.queryCameraAuthorizationStatusAndNotifyUserIfNotGranted()
        if !cameraAccessAuthorized {
            self.appStatus.colorCameraIsAuthorized = false
            self.updateAppStatusMessage()
            return
        }
        // Set up Capture Session.
        self.avCaptureSession = AVCaptureSession()
        self.avCaptureSession!.beginConfiguration()
        // InputPriority allows us to select a more precise format (below)
        self.avCaptureSession!.sessionPreset = AVCaptureSessionPresetInputPriority
        // Create a video device and input from that Device.  Add the input to the capture session.
        self.videoDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        if self.videoDevice == nil {
            assert(false) //assert(0)
        }
        // Configure Focus, Exposure, and White Balance
        
        do {
            try self.videoDevice!.lockForConfiguration()
                
            var imageWidth: Int = -1
            var imageHeight: Int = -1
            if self.enableHighResolutionColorSwitch.on {
                // High-resolution uses 2592x1936, which is close to a 4:3 aspect ratio.
                // Other aspect ratios such as 720p or 1080p are not yet supported.
                imageWidth = 2592
                imageHeight = 1936
            }
            else {
                // Low resolution uses VGA.
                imageWidth = 640
                imageHeight = 480
            }
            // Select capture format
            self.selectCaptureFormat(["width": imageWidth, "height": imageHeight])
            // Allow exposure to initially change
            if self.videoDevice!.isExposureModeSupported(.ContinuousAutoExposure) {
                self.videoDevice!.exposureMode = .ContinuousAutoExposure
            }
            // Allow white balance to initially change
            if self.videoDevice!.isWhiteBalanceModeSupported(.ContinuousAutoWhiteBalance) {
                self.videoDevice!.whiteBalanceMode = .ContinuousAutoWhiteBalance
            }
            // Apply to specified focus position.
            self.setLensPositionWithValue(Float(options.lensPosition), lockVideoDevice: false)
            self.videoDevice!.unlockForConfiguration()
            
        } catch {
            
        }
        //  Add the device to the session.
        let input: AVCaptureDeviceInput? = nil
        do {
            var input: AVCaptureDeviceInput = try AVCaptureDeviceInput(device: self.videoDevice)
        } catch {
            NSLog("Cannot initialize AVCaptureDeviceInput")
            assert(false)
        }
        
        //var input: AVCaptureDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(self.videoDevice, error: error)

//        if error != nil {
//            NSLog("Cannot initialize AVCaptureDeviceInput")
//            assert(false)
//        }
        self.avCaptureSession!.addInput(input)
            // After this point, captureSession captureOptions are filled.
            //  Create the output for the capture session.
        let dataOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        // We don't want to process late frames.
        dataOutput.alwaysDiscardsLateVideoFrames = true
        // Use YCbCr pixel format.
        dataOutput.videoSettings = [
            (kCVPixelBufferPixelFormatTypeKey as AnyObject) as! NSObject : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]

        // Set dispatch to be on the main thread so OpenGL can do things with the data
        //dataOutput.setSampleBufferDelegate(self, queue: dispatch_get_main_queue())
        dataOutput.setSampleBufferDelegate(self, queue: dispatch_get_main_queue())
        self.avCaptureSession!.addOutput(dataOutput)
        // Force the framerate to 30 FPS, to be in sync with Structure Sensor.
        
        do {
            try self.videoDevice!.lockForConfiguration()
            var targetFrameDuration: CMTime = CMTimeMake(1, 30)
            // >0 if min duration > desired duration, in which case we need to increase our duration to the minimum
            // or else the camera will throw an exception.
            if CMTimeCompare(self.videoDevice!.activeVideoMinFrameDuration, targetFrameDuration) > 0 {
                // In firmware <= 1.1, we can only support frame sync with 30 fps or 15 fps.
                targetFrameDuration = CMTimeMake(1, 15)
            }
            self.videoDevice!.activeVideoMaxFrameDuration = targetFrameDuration
            self.videoDevice!.activeVideoMinFrameDuration = targetFrameDuration
            self.videoDevice!.unlockForConfiguration()
        } catch {

        }
        
        self.avCaptureSession!.commitConfiguration()
    }

    func captureOutput(captureOutput: AVCaptureOutput, didOutputSampleBuffer sampleBuffer: CMSampleBufferRef, fromConnection connection: AVCaptureConnection) {
        // Pass color buffers directly to the driver, which will then produce synchronized depth/color pairs.
        sensorController.frameSyncNewColorBuffer(sampleBuffer)
    }
}
