/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
import UIKit
import AVFoundation
//#define HAS_LIBCXX

extension ViewController {
    func setupSLAM() {
        if slamState.initialized {
            return
        }
        
        // Initialize the scene.
        self.slamState.scene = STScene(context: display!.context, freeGLTextureUnit: GLenum(GL_TEXTURE2))
        // Initialize the camera pose tracker.
        var trackerOptions: [NSObject : AnyObject] = [kSTTrackerTypeKey: self.enableNewTrackerSwitch.on ? STTrackerType.DepthAndColorBased as! AnyObject : STTrackerType.DepthBased as! AnyObject, kSTTrackerTrackAgainstModelKey: true, kSTTrackerQualityKey: STTrackerQuality.Accurate as! AnyObject, kSTTrackerBackgroundProcessingEnabledKey: true]
        var trackerInitError: NSError? = nil
        // Initialize the camera pose tracker.
        
        do {
            self.slamState.tracker = try STTracker(scene: slamState.scene!, options: trackerOptions)
        } catch {
            print("Error during STTracker initialization: `%@'.", trackerInitError!.localizedDescription)
        }
        //        if trackerInitError != nil {
        //            print("Error during STTracker initialization: `%@'.", trackerInitError!.localizedDescription)
        //        }
        assert(slamState.tracker != nil, "Could not create a tracker.")
        // Initialize the mapper.
        var mapperOptions = [kSTMapperVolumeResolutionKey: [round(options.initialVolumeSizeInMeters.x / Float(options.initialVolumeResolutionInMeters)), round(options.initialVolumeSizeInMeters.y / Float(options.initialVolumeResolutionInMeters)), round(options.initialVolumeSizeInMeters.z / Float(options.initialVolumeResolutionInMeters))]]
        self.slamState.mapper = STMapper(scene: slamState.scene, options: mapperOptions)
        // We need it for the TrackAgainstModel tracker, and for live rendering.
        self.slamState.mapper!.liveTriangleMeshEnabled = true
        // Default volume size set in options struct
        self.slamState.mapper!.volumeSizeInMeters = options.initialVolumeSizeInMeters
        // Setup the cube placement initializer.
        var cameraPoseInitializerError: NSError? = nil
        do {
            self.slamState.cameraPoseInitializer = try STCameraPoseInitializer(volumeSizeInMeters: slamState.mapper!.volumeSizeInMeters, options: [kSTCameraPoseInitializerStrategyKey: STCameraPoseInitializerStrategy.TableTopCube as! AnyObject])
        } catch {
            
        }
        //assert(cameraPoseInitializerError == nil, "Could not initialize STCameraPoseInitializer: %@", file: cameraPoseInitializerError!.localizedDescription) //HACK just commented this because can't convert string to staticString
        // Set up the cube renderer with the current volume size.
        self.display!.cubeRenderer = STCubeRenderer(context: display!.context)
        // Set up the initial volume size.
        self.adjustVolumeSize(slamState.mapper!.volumeSizeInMeters)
        // Start with cube placement mode
        self.enterCubePlacementState()
        var keyframeManagerOptions: [NSObject : AnyObject] = [kSTKeyFrameManagerMaxSizeKey: options.maxNumKeyFrames, kSTKeyFrameManagerMaxDeltaTranslationKey: options.maxKeyFrameTranslation, kSTKeyFrameManagerMaxDeltaRotationKey: options.maxKeyFrameRotation]
        var keyFrameManagerInitError: NSError? = nil
        
        do {
            self.slamState.keyFrameManager = try STKeyFrameManager(options: keyframeManagerOptions)
        } catch {
            
        }
        //assert(keyFrameManagerInitError == nil, "Could not initialize STKeyFrameManager: %@", file: keyFrameManagerInitError!.localizedDescription) //HACK commented this out to avoid String-staticString expected argument type error
        do {
            self.depthAsRgbaVisualizer = try STDepthToRgba(options: [kSTDepthToRgbaStrategyKey: STDepthToRgbaStrategy.Gray as! AnyObject])
        } catch {
            
        }
        self.slamState.initialized = true
    }
    
    func resetSLAM() {
        self.slamState.prevFrameTimeStamp = -1.0
        slamState.mapper!.reset()
        slamState.tracker!.reset()
        slamState.scene!.clear()
        slamState.keyFrameManager!.clear()
        self.enterCubePlacementState()
    }
    
    func clearSLAM() {
        self.slamState.initialized = false
        self.slamState.scene = nil
        self.slamState.tracker = nil
        self.slamState.mapper = nil
        self.slamState.keyFrameManager = nil
    }
    
    typealias Matrix4Type = (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)
    
    func arrayForTuple(tuple: Matrix4Type) -> [Float] {
        let reflection = Mirror(reflecting: tuple)
        var arr : [Float] = []
        reflection.children.forEach({ (label, value) in
            if let value = value as? Float {
                arr.append(value)
            }
        })
        return arr
    }
    
    func processDepthFrame(depthFrame: STDepthFrame, colorFrameOrNil colorFrame: STColorFrame?) {
        // Upload the new color image for next rendering.
        if useColorCamera && colorFrame != nil {
            self.uploadGLColorTexture(colorFrame!)
        }
        else if !useColorCamera {
            self.uploadGLColorTextureFromDepth(depthFrame)
        }
        
        // Update the projection matrices since we updated the frames.
        
        self.display!.depthCameraGLProjectionMatrix = depthFrame.glProjectionMatrix()
        if colorFrame != nil {
            self.display!.colorCameraGLProjectionMatrix = colorFrame!.glProjectionMatrix()
        }
        
        switch slamState.scannerState {
        case .CubePlacement:
            // Provide the new depth frame to the cube renderer for ROI highlighting.
            // .depthFrame = useColorCamera ? depthFrame.registeredToColorFrame(colorFrame) : depthFrame
            display!.cubeRenderer.setDepthFrame(useColorCamera ? depthFrame.registeredToColorFrame(colorFrame) : depthFrame)
            
            // Estimate the new scanning volume position.
            //var success: Bool = false
            if GLKVector3Length(lastGravity) > 1e-5 {
                do {
                    try slamState.cameraPoseInitializer!.updateCameraPoseWithGravity(lastGravity, depthFrame: depthFrame)
                    
                    //assert(success, "Camera pose initializer error.")
                } catch {
                    
                    print("Camera pose initializer error.")
                }
                
            }
            // Tell the cube renderer whether there is a support plane or not.
            display!.cubeRenderer.setCubeHasSupportPlane((slamState.cameraPoseInitializer?.hasSupportPlane)!) // cubeHasSupportPlane = slamState.cameraPoseInitializer.hasSupportPlane
            // Enable the scan button if the pose initializer could estimate a pose.
            self.scanButton.enabled = slamState.cameraPoseInitializer!.hasValidPose
            
        case .Scanning:
            // First try to estimate the 3D pose of the new frame.
            var trackingError: NSError? = nil
            var depthCameraPoseBeforeTracking: GLKMatrix4 = slamState.tracker!.lastFrameCameraPose()
            
            var trackingOk = false
            
            do {
                try slamState.tracker!.updateCameraPoseWithDepthFrame(depthFrame, colorFrame: colorFrame)
            } catch {
                
            }
            // Integrate it into the current mesh estimate if tracking was successful.
            if trackingOk {
                var depthCameraPoseAfterTracking: GLKMatrix4 = slamState.tracker!.lastFrameCameraPose()
                slamState.mapper!.integrateDepthFrame(depthFrame, cameraPose: depthCameraPoseAfterTracking)
                if (colorFrame != nil) {
                    // Make sure the pose is in color camera coordinates in case we are not using registered depth.
                    var colorCameraPoseInDepthCoordinateSpace: GLKMatrix4 = GLKMatrix4()
                    
                    var m = arrayForTuple(colorCameraPoseInDepthCoordinateSpace.m)
                    
                    depthFrame.colorCameraPoseInDepthCoordinateFrame(&m)
                    var colorCameraPoseAfterTracking: GLKMatrix4 = GLKMatrix4Multiply(depthCameraPoseAfterTracking, colorCameraPoseInDepthCoordinateSpace)
                    var showHoldDeviceStill: Bool = false
                    // Check if the viewpoint has moved enough to add a new keyframe
                    if slamState.keyFrameManager!.wouldBeNewKeyframeWithColorCameraPose(colorCameraPoseAfterTracking) {
                        let isFirstFrame: Bool = (slamState.prevFrameTimeStamp < 0.0)
                        var canAddKeyframe: Bool = false
                        if isFirstFrame {
                            canAddKeyframe = true
                        }
                        else {
                            var deltaAngularSpeedInDegreesPerSecond: Float = FLT_MAX
                            var deltaSeconds: NSTimeInterval = Double(Float(depthFrame.timestamp) - Float(slamState.prevFrameTimeStamp))
                            // If deltaSeconds is 2x longer than the frame duration of the active video device, do not use it either
                            var frameDuration: CMTime = self.videoDevice!.activeVideoMaxFrameDuration
                            if deltaSeconds < Double(frameDuration.value) / Double(frameDuration.timescale) * 2.0 {
                                // Compute angular speed
                                deltaAngularSpeedInDegreesPerSecond = deltaRotationAngleBetweenPosesInDegrees(depthCameraPoseBeforeTracking, newPose: depthCameraPoseAfterTracking) / Float(deltaSeconds)
                            }
                            // If the camera moved too much since the last frame, we will likely end up
                            // with motion blur and rolling shutter, especially in case of rotation. This
                            // checks aims at not grabbing keyframes in that case.
                            if deltaAngularSpeedInDegreesPerSecond < Float(options.maxKeyframeRotationSpeedInDegreesPerSecond) {
                                canAddKeyframe = true
                            }
                        }
                        if canAddKeyframe {
                            slamState.keyFrameManager!.processKeyFrameCandidateWithColorCameraPose(colorCameraPoseAfterTracking, colorFrame: colorFrame, depthFrame: nil)
                        }
                        else {
                            // Moving too fast. Hint the user to slow down to capture a keyframe
                            // without rolling shutter and motion blur.
                            showHoldDeviceStill = true
                        }
                    }
                    if showHoldDeviceStill {
                        self.showTrackingMessage("Please hold still so we can capture a keyframe...")
                    }
                    else {
                        self.hideTrackingErrorMessage()
                    }
                }
                else {
                    self.hideTrackingErrorMessage()
                }
            }
            else if trackingError!.code == STErrorCode.TrackerLostTrack.rawValue {
                self.showTrackingMessage("Tracking Lost! Please Realign or Press Reset.")
            }
            else if trackingError!.code == STErrorCode.TrackerPoorQuality.rawValue {
                switch slamState.tracker!.status() {
                case .DodgyForUnknownReason:
                    NSLog("STTracker Tracker quality is bad, but we don't know why.")
                    // Don't show anything on screen since this can happen often.
                    
                case .FastMotion:
                    NSLog("STTracker Camera moving too fast.")
                    // Don't show anything on screen since this can happen often.
                    
                    
                case .TooClose:
                    NSLog("STTracker Too close to the model.")
                    self.showTrackingMessage("Too close to the scene! Please step back.")
                    
                case .TooFar:
                    NSLog("STTracker Too far from the model.")
                    self.showTrackingMessage("Please get closer to the model.")
                    
                case .Recovering:
                    NSLog("STTracker Recovering.")
                    self.showTrackingMessage("Recovering, please move gently.")
                    
                case .ModelLost:
                    NSLog("STTracker model not in view.")
                    self.showTrackingMessage("Please put the model back in view.")
                    
                default:
                    NSLog("STTracker unknown quality.")
                }
            }
            else {
                NSLog("[Structure] STTracker Error: %@.", trackingError!.localizedDescription)
            }
            
            self.slamState.prevFrameTimeStamp = depthFrame.timestamp
            
        default:
            break
        }
        
    }
    
    // Set up SLAM related objects.
    func deltaRotationAngleBetweenPosesInDegrees(previousPose: GLKMatrix4, newPose: GLKMatrix4) -> Float {
        let deltaPose: GLKMatrix4 = GLKMatrix4Multiply(newPose,             // Transpose is equivalent to inverse since we will only use the rotation part.
            GLKMatrix4Transpose(previousPose))
        // Get the rotation component of the delta pose
        let deltaRotationAsQuaternion: GLKQuaternion = GLKQuaternionMakeWithMatrix4(deltaPose)
        // Get the angle of the rotation
        let angleInDegree: Float = GLKQuaternionAngle(deltaRotationAsQuaternion) / Float(M_PI) * 180
        return angleInDegree
    }
}





