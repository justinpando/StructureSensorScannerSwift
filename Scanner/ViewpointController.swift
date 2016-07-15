/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
import GLKit
//import mach_time

class ViewpointController {
    var screenSizeX: Float = 0.0
    var screenSizeY: Float = 0.0
    
    // Touch without a gesture will stop the current animations.

    // Current modelView matrix in OpenGL space.
    // Current projection matrix in OpenGL space.
    // Apply one update step. Will apply current velocities and animations.
 
    
    // Helper functions
    
    func nowInSeconds() -> Double
    {
//        var timebase: mach_timebase_info_data_t
//        mach_timebase_info(timebase)
//        var newTime: UInt64 = mach_absolute_time()
//        return (Double(newTime) * timebase.numer) / (Double(timebase.denom) * 1e9)
        
        
        let timebase = mach_timebase_info(numer: 0, denom: 0)
        //mach_timebase_info(timebase)
        let newTime: UInt64 = mach_absolute_time()
        return (Double(newTime) * Double(timebase.numer)) / (Double(timebase.denom) * 1e9)
    }
    
    
    // Anonymous
    
    struct PrivateData {
        // Projection matrix before starting user interaction.
        var referenceProjectionMatrix: GLKMatrix4!
        // Centroid of the mesh.
        var meshCenter: GLKVector3!
        // Scale management
        var scaleWhenPinchGestureBegan: Float!
        var currentScale: Float!
        // ModelView rotation.
        var lastModelViewRotationUpdateTimestamp: Double!
        var oneFingerPanWhenGestureBegan: GLKVector2!
        var modelViewRotationWhenPanGestureBegan: GLKMatrix4!
        var modelViewRotation: GLKMatrix4!
        var modelViewRotationVelocity: GLKVector2!
        // expressed in terms of touch coordinates.
        // Rotation speed will slow down with time.
        var velocitiesDampingRatio: GLKVector2!
        // Translation in screen space.
        var twoFingersPanWhenGestureBegan: GLKVector2!
        var meshCenterOnScreenWhenPanGestureBegan: GLKVector2!
        var meshCenterOnScreen: GLKVector2!
        var screenCenter: GLKVector2!
        var screenSize: GLKVector2!
        var cameraOrProjectionChangedSinceLastUpdate: Bool!
    }
    
    var d : PrivateData!
    
    init(screenSizeX: Float, screenSizeY: Float) {
        d = PrivateData()
        d.screenSize = GLKVector2Make(screenSizeX, screenSizeY)
        reset()
    }

//    func ViewpointController() {
//        //var d: delete
//        //d = 0
//    }
    
    func reset() {
        d.cameraOrProjectionChangedSinceLastUpdate = false
        d.scaleWhenPinchGestureBegan = 1.0
        d.currentScale = 1.0
        d.screenCenter = GLKVector2MultiplyScalar(d.screenSize, 0.5)
        d.meshCenterOnScreen = GLKVector2MultiplyScalar(d.screenSize, 0.5)
        d.modelViewRotationWhenPanGestureBegan = GLKMatrix4Identity
        d.modelViewRotation = GLKMatrix4Identity
        d.velocitiesDampingRatio = GLKVector2Make(0.95, 0.95)
        d.modelViewRotationVelocity = GLKVector2Make(0, 0)
    }
    
    func setCameraProjection(projRt: GLKMatrix4) {
        d.referenceProjectionMatrix = projRt
        d.cameraOrProjectionChangedSinceLastUpdate = true
    }
    
    func setMeshCenter(center: GLKVector3) {
        d.meshCenter = center
        d.cameraOrProjectionChangedSinceLastUpdate = true
    }
    
    // Scale Gesture Control
    
    func onPinchGestureBegan(scale: Float) {
        d.scaleWhenPinchGestureBegan = d.currentScale / scale
    }
    
    func onPinchGestureChanged(scale: Float) {
        d.currentScale = scale * d.scaleWhenPinchGestureBegan
        d.cameraOrProjectionChangedSinceLastUpdate = true
    }
    
    // 3D modelView rotation gesture control.
    
    func onOneFingerPanBegan (touch: GLKVector2) {
        d.modelViewRotationWhenPanGestureBegan = d.modelViewRotation
        d.oneFingerPanWhenGestureBegan = touch
    }
    
    func onOneFingerPanChanged (touch: GLKVector2) {
        let distMoved: GLKVector2 = GLKVector2Subtract(touch, d.oneFingerPanWhenGestureBegan)
        let spinDegree: GLKVector2 = GLKVector2Negate(GLKVector2DivideScalar(distMoved, 300))
        let rotX: GLKMatrix4 = GLKMatrix4MakeYRotation(spinDegree.x)
        let rotY: GLKMatrix4 = GLKMatrix4MakeXRotation(-spinDegree.y)
        d.modelViewRotation = GLKMatrix4Multiply(GLKMatrix4Multiply(rotX, rotY), d.modelViewRotationWhenPanGestureBegan)
        d.cameraOrProjectionChangedSinceLastUpdate = true
    }
    
    func onOneFingerPanEnded(vel: GLKVector2) {
        d.modelViewRotationVelocity = vel
        d.lastModelViewRotationUpdateTimestamp = nowInSeconds()
    }
    
    // Screen-space translation gesture control.
    func onTwoFingersPanBegan (touch: GLKVector2) {
        d.twoFingersPanWhenGestureBegan = touch
        d.meshCenterOnScreenWhenPanGestureBegan = d.meshCenterOnScreen
    }
    
    func onTwoFingersPanChanged (touch: GLKVector2) {
        d.meshCenterOnScreen = GLKVector2Add(GLKVector2Subtract(touch, d.twoFingersPanWhenGestureBegan), d.meshCenterOnScreenWhenPanGestureBegan)
        d.cameraOrProjectionChangedSinceLastUpdate = true
    }
    
    func onTwoFingersPanEnded(vel: GLKVector2) {
    }
    
    func onTouchBegan() {
        // Stop the current animations when the user touches the screen.
        d.modelViewRotationVelocity = GLKVector2Make(0, 0)
    }
    
    // ModelView matrix in OpenGL space.
    
    func currentGLModelViewMatrix() -> GLKMatrix4 {
        let meshCenterToOrigin: GLKMatrix4 = GLKMatrix4MakeTranslation(-d.meshCenter.x, -d.meshCenter.y, -d.meshCenter.z)
        // We'll put the object at some distance.
        let originToVirtualViewpoint: GLKMatrix4 = GLKMatrix4MakeTranslation(0, 0, 4 * d.meshCenter.z)
        var modelView: GLKMatrix4 = originToVirtualViewpoint
        modelView = GLKMatrix4Multiply(modelView, d.modelViewRotation)
        // will apply the rotation around the mesh center.
        modelView = GLKMatrix4Multiply(modelView, meshCenterToOrigin)
        return modelView
    }
    
    // Projection matrix in OpenGL space.
    
    func currentGLProjectionMatrix() -> GLKMatrix4 {
        // The scale is directly applied to the reference projection matrix.
        let scale: GLKMatrix4 = GLKMatrix4MakeScale(d.currentScale, d.currentScale, 1)
        // Since the translation is done in screen space, it's also applied to the projection matrix directly.
        let centerTranslation: GLKMatrix4 = currentProjectionCenterTranslation()
        return GLKMatrix4Multiply(centerTranslation, GLKMatrix4Multiply(scale, d.referenceProjectionMatrix))
    }
    
    // Returns true if the current viewpoint changed.
    func update() -> Bool {
        var viewpointChanged: Bool = d.cameraOrProjectionChangedSinceLastUpdate
        // Modelview rotation animation.
        if GLKVector2Length(d.modelViewRotationVelocity) > 1e-5 {
            let nowSec: Double = nowInSeconds()
            let elapsedSec: Double = nowSec - d.lastModelViewRotationUpdateTimestamp
            d.lastModelViewRotationUpdateTimestamp = nowSec
            let distMoved: GLKVector2 = GLKVector2MultiplyScalar(d.modelViewRotationVelocity, Float(elapsedSec))
            let spinDegree: GLKVector2 = GLKVector2Negate(GLKVector2DivideScalar(distMoved, 300))
            let rotX: GLKMatrix4 = GLKMatrix4MakeYRotation(spinDegree.x)
            let rotY: GLKMatrix4 = GLKMatrix4MakeXRotation(-spinDegree.y)
            d.modelViewRotation = GLKMatrix4Multiply(GLKMatrix4Multiply(rotX, rotY), d.modelViewRotation)
            // Slow down the velocities.
            
            
            //d.modelViewRotationVelocity.x *= d.velocitiesDampingRatio.x
            //d.modelViewRotationVelocity.y *= d.velocitiesDampingRatio.y
            d.modelViewRotationVelocity = GLKVector2Multiply(d.modelViewRotationVelocity, d.velocitiesDampingRatio)
            
            
            // Make sure we stop animating and taking resources when it became too small.
            if abs(d.modelViewRotationVelocity.x) < 1 {
                //d.modelViewRotationVelocity.x = 0
                d.modelViewRotationVelocity = GLKVector2Make(0, d.modelViewRotationVelocity.y)
            }
            
            if abs(d.modelViewRotationVelocity.y) < 1 {
                //d.modelViewRotationVelocity.y = 0
                d.modelViewRotationVelocity = GLKVector2Make(d.modelViewRotationVelocity.x, 0)
            }
            
            viewpointChanged = true
        }
        d.cameraOrProjectionChangedSinceLastUpdate = false
        return viewpointChanged
    }
    
    func currentProjectionCenterTranslation() -> GLKMatrix4 {
        let deltaFromScreenCenter: GLKVector2 = GLKVector2Subtract(d.screenCenter, d.meshCenterOnScreen)
        return GLKMatrix4MakeTranslation(-deltaFromScreenCenter.x / d.screenCenter.x, deltaFromScreenCenter.y / d.screenCenter.y, 0)
    }
}
