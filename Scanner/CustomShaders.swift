/*
 This file is part of the Structure SDK.
 Copyright © 2015 Occipital, Inc. All rights reserved.
 http://structure.io
 */
// Helper functions.
//var loadOpenGLProgramFromString: GLuint

class CustomShader {
    
    enum Attrib : GLuint {
        case ATTRIB_VERTEX = 0
        case ATTRIB_NORMAL
        case ATTRIB_COLOR
        case ATTRIB_TEXCOORD
    }
    
    
    init() {
        loaded = false
    }
    func load() {
        
    }
    
    func enable() {
        if !loaded {
            load()
        }
        glUseProgram(glProgram)
    }
    
    var vertexShaderSource: String = ""
    
    let fragmentShaderSource: String = ""
    
    var glProgram: GLuint = 0
    
    var loaded: Bool = false
    
}

class LightedGrayShader: CustomShader {
    
    var projectionLocation: GLint = 0
    
    var modelviewLocation: GLint = 0
    
    func prepareRendering(projection: UnsafePointer<Float>, modelView: UnsafePointer<Float>)
    {
        glUniformMatrix4fv(modelviewLocation, 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv(projectionLocation, 1, GLboolean(GL_FALSE), projection)
        glDisable(GLenum(GL_BLEND))
    }
    override func load()
    {
        let NUM_ATTRIBS: Int = 2
        //        var attributeIds: [GLuint] = [.ATTRIB_VERTEX, .ATTRIB_NORMAL]
        let attributeIds: [GLuint] = [Attrib.ATTRIB_VERTEX.rawValue, Attrib.ATTRIB_NORMAL.rawValue]
        let attributeNames: [String] = ["a_position", "a_normal"]
        self.glProgram = loadOpenGLProgramFromString(vertexShaderSource, fragment_shader_src: fragmentShaderSource, num_attributes: NUM_ATTRIBS, attribute_ids: attributeIds, attribute_names: attributeNames)
        self.projectionLocation = glGetUniformLocation(glProgram, "u_perspective_projection")
        self.modelviewLocation = glGetUniformLocation(glProgram, "u_modelview")
        glUseProgram(0)
        self.loaded = true
    }
    
    
    override init() {
        super.init()
        
        vertexShaderSource = "" +
            "attribute vec4 a_position; \n" +
            "attribute vec3 a_normal; \n" +
            
            "uniform mat4 u_perspective_projection; \n" +
            "uniform mat4 u_modelview; \n" +
            
            "varying float v_luminance; \n" +
            
            "void main() \n" +
            "{ \n" +
            "gl_Position = u_perspective_projection*u_modelview*a_position; \n" +
            
            //mat3 scaledRotation = mat3(u_modelview);
            
            // Directional lighting that moves with the camera
            "vec3 vec = mat3(u_modelview)*a_normal; \n" +
            
            // Slightly reducing the effect of the lighting
            "v_luminance = 0.5*abs(vec.z) + 0.5; \n" +
        "} \n"
    }
}

class PerVertexColorShader: CustomShader {
    
    var projectionLocation: GLuint = 0
    
    var modelviewLocation: GLuint = 0
    
    override func load()
    {
        let NUM_ATTRIBS: Int = 3
        let attributeIds: [GLuint] = [Attrib.ATTRIB_VERTEX.rawValue, Attrib.ATTRIB_NORMAL.rawValue, Attrib.ATTRIB_COLOR.rawValue]
        let attributeNames: [String] = ["a_position", "a_normal", "a_color"]
        self.glProgram = loadOpenGLProgramFromString(vertexShaderSource, fragment_shader_src: fragmentShaderSource, num_attributes: NUM_ATTRIBS, attribute_ids: attributeIds, attribute_names: attributeNames)
        self.projectionLocation = GLuint(glGetUniformLocation(glProgram, "u_perspective_projection"))
        self.modelviewLocation = GLuint(glGetUniformLocation(glProgram, "u_modelview"))
        glUseProgram(0)
        self.loaded = true
    }
    func prepareRendering(projection: UnsafePointer<Float>, modelView: UnsafePointer<Float>)
    {
        glUniformMatrix4fv(GLint(modelviewLocation), 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv(GLint(projectionLocation), 1, GLboolean(GL_FALSE), projection)
        glDisable(GLenum(GL_BLEND))
    }
}

class XrayShader : CustomShader {
    
    var projectionLocation: GLuint = 0
    
    var modelviewLocation: GLuint = 0
    
    override func load()
    {
        let NUM_ATTRIBS: Int = 2
        let attributeIds: [GLuint] = [Attrib.ATTRIB_VERTEX.rawValue, Attrib.ATTRIB_NORMAL.rawValue]
        let attributeNames: [String] = ["a_position", "a_normal"]
        self.glProgram = loadOpenGLProgramFromString(vertexShaderSource, fragment_shader_src: fragmentShaderSource, num_attributes: NUM_ATTRIBS, attribute_ids: attributeIds, attribute_names: attributeNames)
        self.projectionLocation = GLuint(glGetUniformLocation(glProgram, "u_perspective_projection"))
        self.modelviewLocation = GLuint(glGetUniformLocation(glProgram, "u_modelview"))
        glUseProgram(0)
        self.loaded = true
    }
    func prepareRendering(projection: UnsafePointer<Float>, modelView: UnsafePointer<Float>)
    {
        glUniformMatrix4fv(GLint(modelviewLocation), 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv(GLint(projectionLocation), 1, GLboolean(GL_FALSE), projection)
        glDisable(GLenum(GL_BLEND))
    }
}


class YCbCrTextureShader : CustomShader {
    
    var projectionLocation: GLuint = 0
    var modelviewLocation: GLuint = 0
    var ySamplerLocation: GLuint = 0
    var cbcrSamplerLocation: GLuint = 0
    
    override func load()
    {
        let attributeIds: [GLuint] = [Attrib.ATTRIB_VERTEX.rawValue, Attrib.ATTRIB_TEXCOORD.rawValue]
        let attributeNames: [String] = ["a_position", "a_texCoord"]
        self.glProgram = loadOpenGLProgramFromString(vertexShaderSource as String, fragment_shader_src: fragmentShaderSource as String, num_attributes: 2, attribute_ids: attributeIds, attribute_names: attributeNames)
        self.projectionLocation = GLuint(glGetUniformLocation(glProgram, "u_perspective_projection"))
        self.modelviewLocation = GLuint(glGetUniformLocation(glProgram, "u_modelview"))
        self.ySamplerLocation = GLuint(glGetUniformLocation(glProgram, "s_texture_y"))
        self.cbcrSamplerLocation = GLuint(glGetUniformLocation(glProgram, "s_texture_cbcr"))
        glUseProgram(0)
        self.loaded = true
    }
    func prepareRendering(projection: UnsafePointer<Float>, modelView: UnsafePointer<Float>, textureUnit: GLint)
    {
        glUniformMatrix4fv(GLint(modelviewLocation), 1, GLboolean(GL_FALSE), modelView)
        glUniformMatrix4fv(GLint(projectionLocation), 1, GLboolean(GL_FALSE), projection)
        glUniform1i(GLint(ySamplerLocation), textureUnit - GL_TEXTURE0)
        glUniform1i(GLint(cbcrSamplerLocation), textureUnit + 1 - GL_TEXTURE0)
    }
    
}

func loadOpenGLShaderFromString(type: GLenum, shaderSrc : String) -> GLuint {
    var shader: GLuint
    var compiled: GLint = GL_FALSE // Program Link Status
    // Create the shader object
    shader = glCreateShader(type)
    if shader == 0 {
        return 0
    }
    // Load the shader source
    
    var shaderSrcUTF8 = NSString(string: shaderSrc).UTF8String
    
    glShaderSource(shader, 1, &shaderSrcUTF8, nil)
    // Compile the shader
    glCompileShader(shader)
    // Check the compile status
    glGetShaderiv(shader, GLenum(GL_COMPILE_STATUS), &compiled)
    if compiled == GL_FALSE {
        var infoLen: GLint = 0
        glGetShaderiv(shader, GLenum(GL_INFO_LOG_LENGTH), &infoLen)
        if infoLen > 1 {
            let infoLog = UnsafeMutablePointer<GLchar>.alloc(Int(infoLen))
            glGetShaderInfoLog(shader, infoLen, nil, infoLog)
            print("Error compiling shader:\n%s\n", infoLog)
            print("Code: %s\n", shaderSrc)
            //free(infoLog)
        }
        glDeleteShader(shader)
        return 0
    }
    return shader
}

func loadOpenGLProgramFromString(vertex_shader_src : String, fragment_shader_src : String, num_attributes : Int, attribute_ids: [GLuint],attribute_names : [String]) -> GLuint {
    var vertex_shader: GLuint
    var fragment_shader: GLuint
    var program_object: GLuint
    // Load the vertex/fragment shaders
    vertex_shader = loadOpenGLShaderFromString(GLenum(GL_VERTEX_SHADER), shaderSrc: vertex_shader_src)
    if vertex_shader == 0 {
        return 0
    }
    fragment_shader = loadOpenGLShaderFromString(GLenum(GL_FRAGMENT_SHADER), shaderSrc: fragment_shader_src)
    if fragment_shader == 0 {
        glDeleteShader(vertex_shader)
        return 0
    }
    // Create the program object
    program_object = glCreateProgram()
    if program_object == 0 {
        return 0
    }
    glAttachShader(program_object, vertex_shader)
    glAttachShader(program_object, fragment_shader)
    // Bind attributes before linking
    for i in 0...num_attributes {
        glBindAttribLocation(program_object, attribute_ids[i], attribute_names[i])
    }
    var linked: GLint = 0
    // Link the program
    glLinkProgram(program_object)
    // Check the link status
    glGetProgramiv(program_object, GLenum(GL_LINK_STATUS), &linked)
    if linked == GL_FALSE {
        var infoLen: GLint = 0
        glGetProgramiv(program_object, GLenum(GL_INFO_LOG_LENGTH), &infoLen)
        if infoLen > 1 {
            //var infoLog: UnsafeMutablePointer<GLchar> = UnsafeMutablePointer<GLchar>(malloc(sizeof(&infoLen)))
            let infoLog = UnsafeMutablePointer<GLchar>.alloc(Int(infoLen))

            glGetProgramInfoLog(program_object, infoLen, nil, infoLog)
            print("Error linking program:\n%s\n", infoLog)
            //free(infoLog)
        }
        glDeleteProgram(program_object)
        return 0
    }
    // Free up no longer needed shader resources
    glDeleteShader(vertex_shader)
    glDeleteShader(fragment_shader)
    return program_object
    
}