/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
import UIKit
import AVFoundation
//#define HAS_LIBCXX

extension ViewController: STSensorControllerDelegate {
    func connectToStructureSensorAndStartStreaming() -> STSensorControllerInitStatus {
        // Try connecting to a Structure Sensor.
        let result: STSensorControllerInitStatus = sensorController.initializeSensorConnection()
        if result == STSensorControllerInitStatus.Success || result == STSensorControllerInitStatus.AlreadyInitialized {
            // Even though _useColorCamera was set in viewDidLoad by asking if an approximate calibration is guaranteed,
            // it's still possible that the Structure Sensor that has just been plugged in has a custom or approximate calibration
            // that we couldn't have known about in advance.
            let calibrationType: STCalibrationType = sensorController.calibrationType()
            if calibrationType == .Approximate || calibrationType == .DeviceSpecific {
                self.useColorCamera = true
            }
            else {
                self.useColorCamera = false
            }
            if useColorCamera {
                // the new Tracker use both depth and color frames. We will enable the new tracker option here.
                self.enableNewTrackerSwitch.enabled = true
                self.enableNewTrackerView.hidden = false
                if !slamState.initialized {
                    // If we already did a scan, keep the current setting.
                    self.enableNewTrackerSwitch.on = true
                }
            }
            else {
                // the new Tracker use both depth and color frames. We will disable the new tracker option when there is no color camera input.
                self.enableNewTrackerSwitch.on = false
                self.enableNewTrackerSwitch.enabled = false
                self.enableNewTrackerView.hidden = true
            }
            // If we can't use the color camera, then don't try to use registered depth.
            if !useColorCamera {
                self.options.useHardwareRegisteredDepth = false
            }
            // The tracker switch state may have changed if _useColorColor got updated.
            self.enableNewTrackerSwitchChanged(self.enableNewTrackerSwitch)
            self.appStatus.sensorStatus = AppStatus.SensorStatus.Ok
            self.updateAppStatusMessage()
            // Start streaming depth data.
            self.startStructureSensorStreaming()
        }
        else {
            switch result {
            case .SensorNotFound:
                print("[Structure] No sensor found")
            case .OpenFailed:
                print("[Structure] Error: Open failed.")
            case .SensorIsWakingUp:
                print("[Structure] Error: Sensor still waking up.")
            default:
                break
            }
            //HACK
            //self.appStatus.sensorStatus = AppStatus::
            //self.appStatus.
            self.updateAppStatusMessage()
        }
        self.updateIdleTimer()
        return result
    }
    
    func setupStructureSensor() {
        // Get the sensor controller singleton
        self.sensorController = STSensorController.sharedController()
        // Set ourself as the delegate to receive sensor data.
        self.sensorController.delegate = self
    }
    
    func isStructureConnectedAndCharged() -> Bool {
        return sensorController.isConnected() && !sensorController.isLowPower()
    }
    
    func sensorDidConnect() {
        NSLog("[Structure] Sensor connected!")
        if self.currentStateNeedsSensor() {
            self.connectToStructureSensorAndStartStreaming()
        }
    }
    
    func sensorDidLeaveLowPowerMode() {
        //HACK
        //self.appStatus.sensorStatus = AppStatus::
        self.updateAppStatusMessage()
    }
    
    func sensorBatteryNeedsCharging() {
        // Notify the user that the sensor needs to be charged.
        //HACK
        //self.appStatus.sensorStatus = AppStatus::
        self.updateAppStatusMessage()
    }
    
    func sensorDidStopStreaming(reason: STSensorControllerDidStopStreamingReason) {
        if reason == .AppWillResignActive {
            self.stopColorCamera()
            NSLog("[Structure] Stopped streaming because the app will resign its active state.")
        }
        else {
            NSLog("[Structure] Stopped streaming for an unknown reason.")
        }
    }
    
    func sensorDidDisconnect() {
        // If we receive the message while in background, do nothing. We'll check the status when we
        // become active again.
        if UIApplication.sharedApplication().applicationState != .Active {
            return
        }
        NSLog("[Structure] Sensor disconnected!")
        // Reset the scan on disconnect, since we won't be able to recover afterwards.
        if slamState.scannerState == .Scanning {
            self.resetButtonPressed(self)
        }
        if useColorCamera {
            self.stopColorCamera()
        }
        // We only show the app status when we need sensor
        if self.currentStateNeedsSensor() {
            //HACK
            //self.appStatus.sensorStatus = AppStatus::
            self.updateAppStatusMessage()
        }
        if calibrationOverlay != nil {
            self.calibrationOverlay!.hidden = true
        }
        self.updateIdleTimer()
    }
    
    func startStructureSensorStreaming() {
        if !self.isStructureConnectedAndCharged() {
            return
        }
        // Tell the driver to start streaming.
        let error: NSError? = nil
        var optionsAreValid: Bool = false
        
        
        if useColorCamera {
            // We can use either registered or unregistered depth.
            self.structureStreamConfig = options.useHardwareRegisteredDepth ? .RegisteredDepth320x240 : .Depth320x240
            if options.useHardwareRegisteredDepth {
                // We are using the color camera, so let's make sure the depth gets synchronized with it.
                // If we use registered depth, we also need to specify a fixed lens position value for the color camera.
                do
                {
                    try sensorController.startStreamingWithOptions([kSTStreamConfigKey: STStreamConfig.Depth320x240.rawValue, kSTFrameSyncConfigKey: STFrameSyncConfig.DepthAndRgb.rawValue, kSTColorCameraFixedLensPositionKey: options.lensPosition])
                } catch {
                    
                }
            }
            else {
                // We are using the color camera, so let's make sure the depth gets synchronized with it.
                do {
                    try sensorController.startStreamingWithOptions([kSTStreamConfigKey: structureStreamConfig as! AnyObject, kSTFrameSyncConfigKey: STFrameSyncConfig.DepthAndRgb as! AnyObject])
                    optionsAreValid = true
                } catch {
                    
                }
            }
            self.startColorCamera()
        }
        else {
            self.structureStreamConfig = .Depth320x240
            do {
                try sensorController.startStreamingWithOptions([kSTStreamConfigKey: structureStreamConfig as! AnyObject, kSTFrameSyncConfigKey: STFrameSyncConfig.Off as! AnyObject])
                optionsAreValid = true
            } catch {
                
            }
        }
        if !optionsAreValid {
            print("Error during streaming start: %s", error!.localizedDescription) //HACK not using UTF8String as no UTF8String()
            return
        }
        NSLog("[Structure] Streaming started.")
        // Notify and initialize streaming dependent objects.
        self.onStructureSensorStartedStreaming()
    }
    
    func onStructureSensorStartedStreaming() {
        let calibrationType: STCalibrationType = sensorController.calibrationType()
        // The Calibrator app will be updated to support future iPads, and additional attachment brackets will be released as well.
        let deviceIsLikelySupportedByCalibratorApp: Bool = (UI_USER_INTERFACE_IDIOM() == .Pad)
        // Only present the option to switch over to the Calibrator app if the sensor doesn't already have a device specific
        // calibration and the app knows how to calibrate this iOS device.
        if calibrationType != .DeviceSpecific && deviceIsLikelySupportedByCalibratorApp {
            if (calibrationOverlay == nil) {
                self.calibrationOverlay = CalibrationOverlay.calibrationOverlaySubviewOf(self.view!, atOrigin: CGPointMake(8, 8))
            }
            else {
                self.calibrationOverlay!.hidden = false
            }
        }
        else {
            if calibrationOverlay != nil {
                self.calibrationOverlay!.hidden = true
            }
        }
        if !slamState.initialized {
            self.setupSLAM()
        }
    }
    
    func sensorDidOutputDeviceMotion(motion: CMDeviceMotion) {
        //let error: NSError = NSError() //HACK I just created this to have something to pass in to processDeviceMotion, not sure
        self.processDeviceMotion(motion) //HACK instead just removed the withError parameter because it didn't seem to be in use
    }
    
    func sensorDidOutputSynchronizedDepthFrame(depthFrame: STDepthFrame, andColorFrame colorFrame: STColorFrame) {
        if slamState.initialized {
            self.processDepthFrame(depthFrame, colorFrameOrNil: colorFrame)
            // Scene rendering is triggered by new frames to avoid rendering the same view several times.
            self.renderSceneForDepthFrame(depthFrame, colorFrameOrNil: colorFrame)
        }
    }
    
    func sensorDidOutputDepthFrame(depthFrame: STDepthFrame) {
        if slamState.initialized {
            self.processDepthFrame(depthFrame, colorFrameOrNil: nil)

            // Scene rendering is triggered by new frames to avoid rendering the same view several times.
            self.renderSceneForDepthFrame(depthFrame, colorFrameOrNil: nil)        }
    }
}
