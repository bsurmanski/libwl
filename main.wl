//XXX it errors if out of order
use "importc"
import(C) "SDL/SDL.h"
import "image.wl"
import "fmt/tga.wl"
import "file.wl"
import "gl.wl"
import "sdl.wl"
import "mesh.wl"
import "fmt/mdl.wl"
import "collision.wl"
import "random.wl"


undecorated int printf(char^ fmt, ...);

bool running = true
GLDrawDevice glDevice

void init() {
    SDLWindow window = new SDLWindow(640, 480, "test")
    Image i = loadTGA(new StringFile(pack "res/test.tga"))
    GLTexture t = new GLTexture(i)
    glDevice = new GLDrawDevice()
}

void input() {
    SDL_PumpEvents()
    uint8^ keystate = SDL_GetKeyState(null)
    if(keystate[SDLK_SPACE]) running = false
}

void draw() {
    glClear(GL_COLOR_BUFFER_BIT)
    glClear(GL_DEPTH_BUFFER_BIT)

    glDevice.drawQuad()

    SDL_GL_SwapBuffers()
}

int main(int argc, char^^ argv) 
{
    init()
    while(running) {
        input()
        draw()
        SDL_Delay(32)
    }

    return 0
}
