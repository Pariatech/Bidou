package game

import "base:runtime"
import "core:math/linalg/glsl"

import "vendor:glfw"
import stbi "vendor:stb/image"

import "../window"

MOUSE_CURSOR_PATHS :: [Mouse_Cursor]cstring {
	.Arrow       = "resources/cursors/arrow.png",
	.Hand        = "resources/cursors/hand.png",
	.Hand_Closed = "resources/cursors/hand-closed.png",
	.Rotate      = "resources/cursors/rotate.png",
	.Cross       = "resources/cursors/cross.png",
}

MOUSE_CURSOR_HOTSPOTS :: [Mouse_Cursor]glsl.ivec2 {
	.Arrow = {1, 1},
	.Hand = {24, 24},
	.Hand_Closed = {24, 24},
	.Rotate = {24, 24},
	.Cross = {24, 24},
}

Mouse_Button_State :: enum {
	Up,
	Press,
	Repeat,
	Release,
	Down,
}

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
	Four,
	Five,
	Six,
	Seven,
	Eight,
}

Mouse_Cursor :: enum {
	Arrow,
	Hand,
	Hand_Closed,
	Rotate,
	Cross,
}

Mouse :: struct {
	buttons:          [Mouse_Button]Mouse_Button_State,
	buttons_captured: [Mouse_Button]bool,
	scroll:           glsl.dvec2,
	cursors:          [Mouse_Cursor]glfw.CursorHandle,
}

mouse :: proc() -> ^Mouse {
	return &game().mouse
}

mouse_get_scroll :: proc() -> glsl.dvec2 {
	return mouse().scroll
}

mouse_vertical_scroll :: proc() -> f64 {
	return mouse().scroll.y
}

mouse_capture_vertical_scroll :: proc() {
	mouse().scroll.y = 0
}

mouse_capture_scroll :: proc() {
	mouse().scroll = {}
}

mouse_scroll_callback :: proc "c" (
	window: glfw.WindowHandle,
	xoffset, yoffset: f64,
) {
	context = runtime.default_context()
    context.user_ptr = glfw.GetWindowUserPointer(window)
	mouse().scroll.x = xoffset
	mouse().scroll.y = yoffset
}

mouse_on_button :: proc "c" (
	window: glfw.WindowHandle,
	button: i32,
	action: i32,
	mods: i32,
) {
	context = runtime.default_context()
	context.user_ptr = glfw.GetWindowUserPointer(window)
	switch action {
	case glfw.RELEASE:
		mouse().buttons[Mouse_Button(button)] = .Release
	case glfw.PRESS:
		mouse().buttons[Mouse_Button(button)] = .Press
	case glfw.REPEAT:
		mouse().buttons[Mouse_Button(button)] = .Repeat
	}
}

mouse_init :: proc() {
	glfw.SetMouseButtonCallback(window.handle, mouse_on_button)
	glfw.SetScrollCallback(window.handle, mouse_scroll_callback)

	cursor_paths := MOUSE_CURSOR_PATHS
	cursor_hotspots := MOUSE_CURSOR_HOTSPOTS
	for path, i in cursor_paths {
		width, height, channels: i32
		pixels := stbi.load(path, &width, &height, &channels, 4)
		defer stbi.image_free(pixels)

		image := glfw.Image {
			width  = width,
			height = height,
			pixels = pixels,
		}

		hotspot := cursor_hotspots[i]

		mouse().cursors[i] = glfw.CreateCursor(&image, hotspot.x, hotspot.y)
	}
	glfw.SetCursor(window.handle, mouse().cursors[.Arrow])
}

mouse_deinit :: proc() {
	for cursor, i in mouse().cursors {
		glfw.DestroyCursor(cursor)
	}
}

mouse_set_cursor :: proc(cursor: Mouse_Cursor) {
	glfw.SetCursor(window.handle, mouse().cursors[cursor])
}

mouse_update :: proc() {
	mouse().scroll = {0, 0}

	for &capture in mouse().buttons_captured {
		capture = false
	}

	for &state in mouse().buttons {
		switch state {
		case .Press, .Repeat, .Down:
			state = .Down
		case .Release, .Up:
			state = .Up
		}
	}
}

mouse_is_button_press :: proc(button: Mouse_Button) -> bool {
	return(
		!mouse().buttons_captured[button] &&
		mouse().buttons[button] == .Press \
	)
}

mouse_is_button_down :: proc(button: Mouse_Button) -> bool {
	return(
		!mouse().buttons_captured[button] &&
		(mouse().buttons[button] == .Press ||
				mouse().buttons[button] == .Down ||
				mouse().buttons[button] == .Repeat) \
	)
}

mouse_is_button_release :: proc(button: Mouse_Button) -> bool {
	return(
		!mouse().buttons_captured[button] &&
		mouse().buttons[button] == .Release \
	)
}

mouse_is_button_up :: proc(button: Mouse_Button) -> bool {
	return mouse().buttons[button] == .Up
}


mouse_capture :: proc(button: Mouse_Button) {
	mouse().buttons_captured[button] = true
	// buttons[button] = .Up
}

mouse_capture_all :: proc() {
	for &capture in mouse().buttons_captured {
		capture = true
	}

	mouse_capture_scroll()
}
