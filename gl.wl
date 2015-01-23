use "importc"

import(C) "SDL/SDL.h"
import(C) "GL/gl.h"

import "vec.wl"
import "image.wl"
import "mesh.wl"
import "fmt/mdl.wl"
import "file.wl"
import "vec.wl"

char[] vsrc_deferred = pack "glsl/deferred.vs"
char[] fsrc_deferred = pack "glsl/deferred.fs"


class GLProgram {
    GLuint program
    GLuint vshader
    GLuint fshader

    this(char^ vsrc, char^ fsrc) {
        .program = glCreateProgram()
        .vshader = glCreateShader(GL_VERTEX_SHADER)
        .fshader = glCreateShader(GL_FRAGMENT_SHADER)
        glShaderSource(.vshader, 1, &vsrc, null)
        glShaderSource(.fshader, 1, &fsrc, null)
        glCompileShader(.vshader)
        glCompileShader(.fshader)

        int err
        char[512] buf
        glGetShaderiv(.vshader, GL_COMPILE_STATUS, &err)
        if(err != GL_TRUE) {
            glGetShaderInfoLog(.vshader, 512, null, buf.ptr)
            printf("VS ERR: %s\n", buf.ptr)
        }

        glGetShaderiv(.fshader, GL_COMPILE_STATUS, &err)
        if(err != GL_TRUE) {
            glGetShaderInfoLog(.fshader, 512, null, buf.ptr)
            printf("FS ERR: %s\n", buf.ptr)
        }

        glAttachShader(.program, .vshader)
        glAttachShader(.program, .fshader)
        glLinkProgram(.program)

        glGetProgramiv(.program, GL_LINK_STATUS, &err)
        if(err != GL_TRUE) {
            glGetProgramInfoLog(.program, 512, null, buf.ptr)
            printf("GLProgram Link Error: %s\n", buf.ptr)
        }
    }

    void bind() {
        glUseProgram(.program)
    }
}

class GLTexture {
    GLuint id
    int w
    int h

    this(Image img) {
        glGenTextures(1, &.id)
        glBindTexture(GL_TEXTURE_2D, .id)
        .w = img.width()
        .h = img.height()
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 
        img.width(), img.height(), 0, GL_BGRA, GL_UNSIGNED_BYTE, 
        img.pixels)
    }
}

class GLMesh {
    GLuint vbuffer
    GLuint ibuffer
    uint nelems

    this(Mesh mesh) {
        glGenBuffers(1, &.vbuffer)
        glGenBuffers(1, &.ibuffer)
        glBindBuffer(GL_ARRAY_BUFFER, .vbuffer)

        glBufferData(GL_ARRAY_BUFFER, 
            MeshVertex.sizeof * mesh.verts.size,
            mesh.verts.ptr, 
            GL_STATIC_DRAW)

        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, .ibuffer)

        glBufferData(GL_ELEMENT_ARRAY_BUFFER, 
            MeshFace.sizeof * mesh.faces.size,
            mesh.faces.ptr, 
            GL_STATIC_DRAW)

        .nelems = mesh.faces.size * 3
    }

    void draw() {
        //glBindBuffer(GL_ARRAY_BUFFER, .vbuffer)
        //glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, .ibuffer)
        glDrawElements(GL_TRIANGLES, .nelems, GL_UNSIGNED_SHORT, null)
    }
}

class Model {
    GLMesh mesh
    vec4 position
    vec4 rotation

    this(GLMesh m) {
        .mesh = m
        .position = vec4(0,0,0,1)
    }

    void move(vec4 v) {
        .position = .position.add(v)
    }

    void move(float x, float y, float z) {
        vec4 o = vec4(x, y, z, 0)
        .move(o)
    }

    void draw() {
        GLDrawDevice.getInstance()
    }
}

class GLDrawDevice {

    static GLMesh quad
    static GLProgram drawProgram
    static GLDrawDevice instance

    static GLDrawDevice getInstance() {
        if(!instance) instance = new GLDrawDevice()
        return instance
    }

    this() {
        if(!.quad) {
            Mesh mesh = loadMdl(new StringFile(pack "res/monkey.mdl"))
            .quad = new GLMesh(mesh)
        }

        if(!.drawProgram) {
            .drawProgram = new GLProgram(pack "glsl/simple.vs",
                                         pack "glsl/simple.fs")
            .drawProgram.bind()
        }

        glClearColor(0.0f, 0.0f, 0.0f, 0.0f)
        glEnable(GL_TEXTURE_2D)
        glDisable(GL_BLEND)
        //glEnable(GL_CULL_FACE)
        glEnable(GL_DEPTH_TEST)
        glDisable(GL_SCISSOR_TEST)

        glViewport(0, 0, 640, 480)
        /*
        glMatrixMode(GL_PROJECTION)
        glLoadIdentity()
        glOrtho(0, 320, 240, 0, -1, 1)
        */
    }

    void drawQuad() {
        .drawProgram.bind()

        glBindBuffer(GL_ARRAY_BUFFER, .quad.vbuffer)
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, .quad.ibuffer)

        GLint pos = glGetAttribLocation(.drawProgram.program, "position")
        GLint norm = glGetAttribLocation(.drawProgram.program, "normal")
        GLint uv = glGetAttribLocation(.drawProgram.program, "uv")
        if(pos >= 0) {
            glEnableVertexAttribArray(pos)
            glVertexAttribPointer(pos, 3, GL_FLOAT, GL_FALSE, 32, null)
        }

        if(norm >= 0) {
            glEnableVertexAttribArray(norm)
            glVertexAttribPointer(norm, 3, GL_SHORT, GL_TRUE, 32, void^: 12)
        }

        if(uv >= 0) {
            glEnableVertexAttribArray(uv)
            glVertexAttribPointer(uv, 2, GL_UNSIGNED_SHORT, GL_TRUE, 32, void^: 18)
        }

        glUniform1i(glGetUniformLocation(.drawProgram.program, "tex"), 0)

        static float t = 0.0f
        t+=0.05
        mat4 persp = getFrustumMatrix(-1.0f, 1.0f, -1.0f, 1.0f, 1.0f, 10000)
        mat4 mat = mat4()
        vec4 rot = vec4(0, 1, 0, 0)
        mat = mat.rotate(t, rot)
        vec4 trans = vec4(0, sin(t), -2, 1)
        mat = mat.translate(trans)
        mat = persp.mul(mat)

        glUniformMatrix4fv(glGetUniformLocation(.drawProgram.program, "mvp"), 1, GL_TRUE, mat.ptr())

        .quad.draw()
    }
}
