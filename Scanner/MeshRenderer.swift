/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
import GLKit
import CoreVideo
import OpenGLES

extension GLKMatrix4 {
    var array: [Float] {
        return (0..<16).map { i in
            self[i]
        }
    }
}

class MeshRenderer {
    
    enum RenderingMode {
        case RenderingModeXRay
        case RenderingModePerVertexColor
        case RenderingModeTextured
        case RenderingModeLightedGray
        case RenderingModeNumModes
    }
    
    //    void initializeGL(GLenum)
    //    defaultTextureUnit = GL_TEXTURE3)
    //    var releaseGLBuffers
    //    // release the data uploaded to the GPU.
    //    var releaseGLTextures
    //    // release the data uploaded to the GPU.
    //    var setRenderingMode
    //    var clear
    //    var uploadMesh
    //    let projectionMatrix: GLKMatrix4&
    //    let GLKMatrix4: GLKMatrix4&
    //    modelViewMatrix)
    //    var meshIndex): Int
    //    var enableVertexBuffer
    //    var disableVertexBuffer
    //    var enableNormalBuffer
    //    var disableNormalBuffer
    //    var enableVertexColorBuffer
    //    var disableVertexColorBuffer
    //    var enableVertexTexcoordsBuffer
    //    var disableVertexTexcoordBuffer
    //    var enableLinesElementBuffer
    //    var enableTrianglesElementBuffer
    //    var uploadTexture
    //    var PrivateData: class
    //    var d: PrivateData
    
    struct PrivateData {
        var lightedGrayShader: LightedGrayShader
        var perVertexColorShader: PerVertexColorShader
        var xRayShader: XrayShader
        var yCbCrTextureShader: YCbCrTextureShader
        var numUploadedMeshes: Int = 0
        var numTriangleIndices: [Int]
        var numLinesIndices: [Int]
        var hasPerVertexColor: Bool = false
        var hasPerVertexNormals: Bool = false
        var hasPerVertexUV: Bool = false
        var hasTexture: Bool = false
        // Vertex buffer objects.
        var vertexVbo: [GLuint]
        var normalsVbo: [GLuint]
        var colorsVbo: [GLuint]
        var texcoordsVbo: [GLuint]
        var facesVbo: [GLuint]
        var linesVbo: [GLuint]
        // OpenGL Texture reference for y and chroma images.
        var lumaTexture: CVOpenGLESTextureRef? = nil
        var chromaTexture: CVOpenGLESTextureRef? = nil //= nil
        // OpenGL Texture cache for the color texture.
        var textureCache: CVOpenGLESTextureCacheRef? = nil
        // Texture unit to use for texture binding/rendering.
        var textureUnit: GLenum = GLenum(GL_TEXTURE3)
        // Current render mode.
        var currentRenderingMode: RenderingMode = .RenderingModeLightedGray
    }
    var d: PrivateData!
    
    // GL_RED_EXT
    
    let MAX_MESHES = Int32(30)
    // Local functions
    
    
    init() {
        
    }
    //
    //    func d() {
    //    }
    
    func initializeGL(defaultTextureUnit : GLenum) {
        d.textureUnit = defaultTextureUnit
        glGenBuffers(MAX_MESHES, &d.vertexVbo)
        glGenBuffers(MAX_MESHES, &d.normalsVbo)
        glGenBuffers(MAX_MESHES, &d.colorsVbo)
        glGenBuffers(MAX_MESHES, &d.texcoordsVbo)
        glGenBuffers(MAX_MESHES, &d.facesVbo)
        glGenBuffers(MAX_MESHES, &d.linesVbo)
    }
    
    func releaseGLTextures() {
        if (d.lumaTexture != nil) {
            //CFRelease(d.lumaTexture) //Commented out because Core Foundation objects are automatically memory managed
            d.lumaTexture = nil
        }
        if (d.chromaTexture != nil) {
            //CFRelease(d.chromaTexture)
            d.chromaTexture = nil
        }
        if (d.textureCache != nil) {
            //CFRelease(d.textureCache)
            d.textureCache = nil
        }
    }
    
    func releaseGLBuffers() {
        for meshIndex in 0 ..< d.numUploadedMeshes {
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.vertexVbo[meshIndex])
            glBufferData(GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.normalsVbo[meshIndex])
            glBufferData(GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.colorsVbo[meshIndex])
            glBufferData(GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.texcoordsVbo[meshIndex])
            glBufferData(GLenum(GL_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), d.facesVbo[meshIndex])
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), d.linesVbo[meshIndex])
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0, nil, GLenum(GL_STATIC_DRAW))
        }
    }
    
    //    func MeshRenderer() {
    //        if d.vertexVbo[0] {
    //            glDeleteBuffers(MAX_MESHES, d.vertexVbo)
    //        }
    //        if d.normalsVbo[0] {
    //            glDeleteBuffers(MAX_MESHES, d.normalsVbo)
    //        }
    //        if d.colorsVbo[0] {
    //            glDeleteBuffers(MAX_MESHES, d.colorsVbo)
    //        }
    //        if d.texcoordsVbo[0] {
    //            glDeleteBuffers(MAX_MESHES, d.texcoordsVbo)
    //        }
    //        if d.facesVbo[0] {
    //            glDeleteBuffers(MAX_MESHES, d.facesVbo)
    //        }
    //        if d.linesVbo[0] {
    //            glDeleteBuffers(MAX_MESHES, d.linesVbo)
    //        }
    //        releaseGLTextures()
    //        var d: delete
    //    }
    
    func clear() {
        if d.currentRenderingMode == RenderingMode.RenderingModePerVertexColor || d.currentRenderingMode == RenderingMode.RenderingModeTextured {
            glClearColor(0.9, 0.9, 0.9, 1.0)
        }
        else {
            glClearColor(0.1, 0.1, 0.1, 1.0)
        }
        glClearDepthf(1.0)
        glClear(GLenum(GL_COLOR_BUFFER_BIT) | GLenum(GL_DEPTH_BUFFER_BIT))
    }
    
    func setRenderingMode(mode: RenderingMode) {
        d.currentRenderingMode = mode
    }
    
    func getRenderingMode() -> RenderingMode {
        return d.currentRenderingMode
    }
    
    func uploadMesh(mesh: STMesh) {
        let numUploads: Int = min(Int(mesh.numberOfMeshes()), Int(MAX_MESHES))
        d.numUploadedMeshes = min(Int(mesh.numberOfMeshes()), Int(MAX_MESHES))
        d.hasPerVertexColor = mesh.hasPerVertexColors()
        d.hasPerVertexNormals = mesh.hasPerVertexNormals()
        d.hasPerVertexUV = mesh.hasPerVertexUVTextureCoords()
        d.hasTexture = (mesh.meshYCbCrTexture() != nil)
        if d.hasTexture {
            uploadTexture(mesh.meshYCbCrTexture().takeRetainedValue() as CVPixelBufferRef)
        }
        for meshIndex in 0 ..< numUploads {
            let numVertices: Int = Int(mesh.numberOfMeshVertices(Int32(meshIndex)))
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.vertexVbo[meshIndex])
            glBufferData(GLenum(GL_ARRAY_BUFFER), numVertices * sizeof(GLKVector3), mesh.meshVertices(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            if d.hasPerVertexNormals {
                glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.normalsVbo[meshIndex])
                glBufferData(GLenum(GL_ARRAY_BUFFER), numVertices * sizeof(GLKVector3), mesh.meshPerVertexNormals(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            }
            if d.hasPerVertexColor {
                glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.colorsVbo[meshIndex])
                glBufferData(GLenum(GL_ARRAY_BUFFER), numVertices * sizeof(GLKVector3), mesh.meshPerVertexColors(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            }
            if d.hasPerVertexUV {
                glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.texcoordsVbo[meshIndex])
                glBufferData(GLenum(GL_ARRAY_BUFFER), numVertices * sizeof(GLKVector2), mesh.meshPerVertexUVTextureCoords(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            }
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), d.facesVbo[meshIndex])
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), Int(mesh.numberOfMeshFaces(Int32(meshIndex))) * sizeof(UInt16) * 3, mesh.meshFaces(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), d.linesVbo[meshIndex])
            glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), Int(mesh.numberOfMeshLines(Int32(meshIndex))) * sizeof(UInt16) * 2, mesh.meshLines(Int32(meshIndex)), GLenum(GL_STATIC_DRAW))
            glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
            d.numTriangleIndices[meshIndex] = Int(mesh.numberOfMeshFaces(Int32(meshIndex)) * 3)
            d.numLinesIndices[meshIndex] = Int(mesh.numberOfMeshLines(Int32(meshIndex)) * 2)
        }
    }
    
    func uploadTexture(pixelBuffer: CVImageBufferRef) {
        let width: Int = Int(CVPixelBufferGetWidth(pixelBuffer))
        let height: Int = Int(CVPixelBufferGetHeight(pixelBuffer))
        let context: EAGLContext? = EAGLContext.currentContext()
        assert(context != nil) // What is this line doing?
        releaseGLTextures()
        if d.textureCache == nil {
            let texError: CVReturn? = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, context!, nil, &d.textureCache)
            if texError != nil {
                print("Error at CVOpenGLESTextureCacheCreate %d", texError)
            }
        }
        // Allow the texture cache to do internal cleanup.
        CVOpenGLESTextureCacheFlush(d.textureCache!, 0)
        let pixelFormat: OSType = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        // Activate the default texture unit.
        glActiveTexture(d.textureUnit)
        // Create a new Y texture from the video texture cache.
        var err: CVReturn? = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, d.textureCache!, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RED_EXT, GLsizei(width), GLsizei(height), GLenum(GL_RED_EXT), GLenum(GL_UNSIGNED_BYTE), 0, &d.lumaTexture)
        if err != nil {
            print("Error with CVOpenGLESTextureCacheCreateTextureFromImage: %d", err)
            return
        }
        // Set rendering properties for the new texture.
        glBindTexture(CVOpenGLESTextureGetTarget(d.lumaTexture!), CVOpenGLESTextureGetName(d.lumaTexture!))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        // Activate the next texture unit for CbCr.
        glActiveTexture(d.textureUnit + 1)
        // Create a new CbCr texture from the video texture cache.
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, d.textureCache!, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_RG_EXT, Int32(width) / 2, Int32(height) / 2, GLenum(GL_RED_EXT), GLenum(GL_UNSIGNED_BYTE), 1, &d.chromaTexture)
        if err != nil {
            print("Error with CVOpenGLESTextureCacheCreateTextureFromImage: %d", err)
            return
        }
        glBindTexture(CVOpenGLESTextureGetTarget(d.chromaTexture!), CVOpenGLESTextureGetName(d.chromaTexture!))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
        glBindTexture(GLenum(GL_TEXTURE_2D), 0)
    }
    
    func enableVertexBuffer(meshIndex : Int) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.vertexVbo[meshIndex])
        //CustomShader.
        glEnableVertexAttribArray(CustomShader.Attrib.ATTRIB_VERTEX.rawValue)
        //.ATTRIB_VERTEX, 3, GL_FLOAT, GL_FALSE, 0, 0)
        glVertexAttribPointer(CustomShader.Attrib.ATTRIB_VERTEX.rawValue, 3, GLenum(GL_FALSE), GLboolean(0), 0, nil)
    }
    
    func disableVertexBuffer(meshIndex : Int) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.vertexVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.ATTRIB_VERTEX.rawValue)
    }
    
    func enableNormalBuffer (meshIndex : Int) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.normalsVbo[meshIndex])
        glEnableVertexAttribArray(CustomShader.Attrib.ATTRIB_NORMAL.rawValue)
        glVertexAttribPointer(CustomShader.Attrib.ATTRIB_NORMAL.rawValue, 3, GLenum(GL_FLOAT), GLboolean(0), 0, nil)
        //int meshIndex([glBindBuffer(GL_ARRAY_BUFFER, d.normalsVbo[meshIndex])])
        //.ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, 0, 0)
    }
    
    func disableNormalBuffer(meshIndex : Int) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.normalsVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.ATTRIB_NORMAL.rawValue)
        //int meshIndex([glBindBuffer(GL_ARRAY_BUFFER, d.colorsVbo[meshIndex])])
    }
    
    func enableVertexColorBuffer (meshIndex : Int) {
        //.ATTRIB_COLOR, 3, GL_FLOAT, GL_FALSE, 0, 0)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.colorsVbo[meshIndex])
        glEnableVertexAttribArray(CustomShader.Attrib.ATTRIB_COLOR.rawValue)
        glVertexAttribPointer(CustomShader.Attrib.ATTRIB_COLOR.rawValue, 3, GLenum(GL_FLOAT), GLboolean(0), 0, nil)
    }
    
    func disableVertexColorBuffer(meshIndex : Int) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.colorsVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.ATTRIB_TEXCOORD.rawValue)
    }
    
    func enableVertexTexcoordsBuffer (meshIndex : Int) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.texcoordsVbo[meshIndex])
        glEnableVertexAttribArray(CustomShader.Attrib.ATTRIB_TEXCOORD.rawValue)
        glVertexAttribPointer(CustomShader.Attrib.ATTRIB_TEXCOORD.rawValue, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
        //    .ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 0, 0)
    }
    
    func disableVertexTexcoordBuffer(meshIndex: Int) {
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), d.texcoordsVbo[meshIndex])
        glDisableVertexAttribArray(CustomShader.Attrib.ATTRIB_TEXCOORD.rawValue)
    }
    
    func enableLinesElementBuffer (meshIndex: Int) {
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), d.linesVbo[meshIndex])
        glLineWidth(1.0)
    }
    
    func enableTrianglesElementBuffer (meshIndex: Int)
    {
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), d.facesVbo[meshIndex])
    }
    func renderPartialMesh (meshIndex: Int)
    {
        if d.numTriangleIndices[meshIndex] <= 0 {
            // nothing uploaded.
            return
        }
        switch d.currentRenderingMode {
        case RenderingMode.RenderingModeXRay:
            enableLinesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableNormalBuffer(meshIndex)
            glDrawElements(GLenum(GL_LINES), GLsizei(d.numLinesIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableNormalBuffer(meshIndex)
            disableVertexBuffer(meshIndex)
            
        case RenderingMode.RenderingModeLightedGray:
            enableTrianglesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableNormalBuffer(meshIndex)
            glDrawElements(GLenum(GL_TRIANGLES), GLsizei(d.numLinesIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableNormalBuffer(meshIndex)
            disableVertexBuffer(meshIndex)
            
        case RenderingMode.RenderingModePerVertexColor:
            enableTrianglesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableNormalBuffer(meshIndex)
            enableVertexColorBuffer(meshIndex)
            glDrawElements(GLenum(GL_TRIANGLES), GLsizei(d.numLinesIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableVertexColorBuffer(meshIndex)
            disableNormalBuffer(meshIndex)
            disableVertexBuffer(meshIndex)
            
        case RenderingMode.RenderingModeTextured:
            enableTrianglesElementBuffer(meshIndex)
            enableVertexBuffer(meshIndex)
            enableVertexTexcoordsBuffer(meshIndex)
            glDrawElements(GLenum(GL_TRIANGLES), GLsizei(d.numLinesIndices[meshIndex]), GLenum(GL_UNSIGNED_SHORT), nil)
            disableVertexTexcoordBuffer(meshIndex)
            disableVertexBuffer(meshIndex)
            
        default:
            NSLog("Unknown rendering mode.")
        }
        
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), 0)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
    }
    
    func render(projectionMatrix: UnsafePointer<GLKMatrix4>, modelViewMatrix: UnsafePointer<GLKMatrix4>) {
        
        if d.currentRenderingMode == RenderingMode.RenderingModePerVertexColor && !d.hasPerVertexColor && d.hasTexture && d.hasPerVertexUV {
            NSLog("Warning: The mesh has no per-vertex colors, but a texture, switching the rendering mode to RenderingModeTextured")
            d.currentRenderingMode = RenderingMode.RenderingModeTextured
        }
        else if d.currentRenderingMode == RenderingMode.RenderingModeTextured && (!d.hasTexture || !d.hasPerVertexUV) && d.hasPerVertexColor {
            NSLog("Warning: The mesh has no texture, but per-vertex colors, switching the rendering mode to RenderingModePerVertexColor")
            d.currentRenderingMode = RenderingMode.RenderingModePerVertexColor
        }
        
        
        
        switch d.currentRenderingMode {
        case RenderingMode.RenderingModeXRay:
            d.xRayShader.enable()
            d.xRayShader.prepareRendering(projectionMatrix.memory.array, modelView: modelViewMatrix.memory.array)
        case RenderingMode.RenderingModeLightedGray:
            d.lightedGrayShader.enable()
            d.lightedGrayShader.prepareRendering(projectionMatrix.memory.array, modelView: modelViewMatrix.memory.array)
        case RenderingMode.RenderingModePerVertexColor:
            if !d.hasPerVertexColor {
                NSLog("Warning: the mesh has no colors, skipping rendering.")
                return
            }
            d.perVertexColorShader.enable()
            d.perVertexColorShader.prepareRendering(projectionMatrix.memory.array, modelView: modelViewMatrix.memory.array)
        case RenderingMode.RenderingModeTextured:
            if !d.hasTexture || d.lumaTexture == nil || d.chromaTexture == nil {
                NSLog("Warning: null textures, skipping rendering.")
                return
            }
            glActiveTexture(d.textureUnit)
            glBindTexture(CVOpenGLESTextureGetTarget(d.lumaTexture!), CVOpenGLESTextureGetName(d.lumaTexture!))
            glActiveTexture(d.textureUnit + 1)
            glBindTexture(CVOpenGLESTextureGetTarget(d.chromaTexture!), CVOpenGLESTextureGetName(d.chromaTexture!))
            d.yCbCrTextureShader.enable()
            d.yCbCrTextureShader.prepareRendering(projectionMatrix.memory.array, modelView: modelViewMatrix.memory.array, textureUnit: GLint(d.textureUnit))
        default:
            NSLog("Unknown rendering mode.")
            return
        }
        
        // Keep previous GL_DEPTH_TEST state
        let wasDepthTestEnabled: GLboolean = glIsEnabled(GLenum(GL_DEPTH_TEST))
        glEnable(GLenum(GL_DEPTH_TEST))
        for i in 0 ..< d.numUploadedMeshes {
            renderPartialMesh(i)
        }
        if wasDepthTestEnabled == 0 { // if wasDepthTestEnabled == false
            glDisable(GLenum(GL_DEPTH_TEST))
        }
        
    }
}