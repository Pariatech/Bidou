package game

import "base:runtime"
import "core:log"
import "core:fmt"
import "core:math/linalg/glsl"

import gl "vendor:OpenGL"
import "vendor:glfw"

WINDOW_WIDTH :: 1280
WINDOW_HEIGHT :: 720

Window :: struct {
	handle: glfw.WindowHandle,
	size:   glsl.vec2,
	scale:  glsl.vec2,
    dpi: glsl.vec2,
}

window :: proc() -> ^Window {
	return &game().window
}

window_init :: proc(title: cstring) -> (ok: bool = true) {
	window().size = {WINDOW_WIDTH, WINDOW_HEIGHT}
	if !bool(glfw.Init()) {
		log.fatal("GLFW has failed to load.")
		return false
	}

	glfw.WindowHint(glfw.SAMPLES, 4)

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 2)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, gl.TRUE)

	window().handle = glfw.CreateWindow(
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		title,
		nil,
		nil,
	)

	glfw.SetWindowUserPointer(window().handle, context.user_ptr)
	glfw.SetWindowSizeCallback(window().handle, window_size_callback)

	window().scale.x, window().scale.y = glfw.GetWindowContentScale(
		window().handle,
	)
	// window().scale = {2, 2} // There's a bug with this
	window().dpi.x, window().dpi.y = glfw.GetMonitorContentScale(glfw.GetPrimaryMonitor())
	log.debug("Window scale:", window().scale)
	log.debug("Screen scale:", window().dpi)


	// glfw.GetFramebufferSize()

	return
}

window_update :: proc() {
	window().scale.x, window().scale.y = glfw.GetWindowContentScale(window().handle)
	window().dpi.x, window().dpi.y = glfw.GetMonitorContentScale(glfw.GetPrimaryMonitor())
}

window_deinit :: proc() {
	defer glfw.DestroyWindow(window().handle)
	defer glfw.Terminate()
}

window_size_callback :: proc "c" (
	handle: glfw.WindowHandle,
	width, height: i32,
) {
	context = runtime.default_context()
	context.user_ptr = glfw.GetWindowUserPointer(handle)

	window().size.x = f32(width)
	window().size.y = f32(height)
	gl.Viewport(0, 0, width, height)

    // renderer().framebuffer_resized = true
}

window_get_scaled_size :: proc() -> glsl.vec2 {
    return window().size / window().scale
}
