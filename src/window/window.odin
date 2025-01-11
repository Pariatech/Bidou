package window

import "base:runtime"
import "core:log"
import "core:math/linalg/glsl"

import "vendor:glfw"
import gl "vendor:OpenGL"

WIDTH :: 1280
HEIGHT :: 720

handle: glfw.WindowHandle
size := glsl.vec2{WIDTH, HEIGHT}
scale: glsl.vec2

init :: proc(title: cstring) -> (ok: bool = true) {
	if !bool(glfw.Init()) {
		log.fatal("GLFW has failed to load.")
		return false
	}

	glfw.WindowHint(glfw.SAMPLES, 4)

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3);
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 2);
    glfw.WindowHint(glfw.OPENGL_PROFILE,glfw.OPENGL_CORE_PROFILE)
    glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, gl.TRUE)

	handle = glfw.CreateWindow(WIDTH, HEIGHT, title, nil, nil)

    glfw.SetWindowSizeCallback(handle, window_size_callback)

	scale.x, scale.y = glfw.GetWindowContentScale(handle)
	// scale = {1.5, 1.5} // There's a bug with this
	dpi: glsl.vec2
	dpi.x, dpi.y = glfw.GetMonitorContentScale(glfw.GetPrimaryMonitor())
	log.debug("Window scale:", scale)
	log.debug("Screen scale:", dpi)

    glfw.SetWindowUserPointer(handle, context.user_ptr)

    // glfw.GetFramebufferSize()

	return
}

deinit :: proc() {
	defer glfw.DestroyWindow(handle)
	defer glfw.Terminate()
}

window_size_callback :: proc "c" (
	_: glfw.WindowHandle,
	width, height: i32,
) {
	context = runtime.default_context()

	size.x = f32(width)
	size.y = f32(height)
}
