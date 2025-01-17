package game

import "base:runtime"
import "core:c"
import "vendor:glfw"

import "../window"

Keyboard :: struct {
	key_map: map[Keyboard_Key_Value]Keyboard_Key_State,
}

Keyboard_Key_State :: enum {
	Press,
	Repeat,
	Release,
	Down,
	Up,
}

Keyboard_Key_Value :: enum {
	/* Named printable keys */
	Key_Space         = 32,
	Key_Apostrophe    = 39, /* ' */
	Key_Comma         = 44, /* , */
	Key_Minus         = 45, /* - */
	Key_Period        = 46, /* . */
	Key_Slash         = 47, /* / */
	Key_Semicolon     = 59, /* ; */
	Key_Equal         = 61, /* = */
	Key_Left_Bracket  = 91, /* [ */
	Key_Backslash     = 92, /* \ */
	Key_Right_Bracket = 93, /* ] */
	Key_Grave_Accent  = 96, /* ` */
	Key_World_1       = 161, /* NON-us #1 */
	Key_World_2       = 162, /* NON-us #2 */

	/* Alphanumeric characters */
	Key_0             = 48,
	Key_1             = 49,
	Key_2             = 50,
	Key_3             = 51,
	Key_4             = 52,
	Key_5             = 53,
	Key_6             = 54,
	Key_7             = 55,
	Key_8             = 56,
	Key_9             = 57,
	Key_A             = 65,
	Key_B             = 66,
	Key_C             = 67,
	Key_D             = 68,
	Key_E             = 69,
	Key_F             = 70,
	Key_G             = 71,
	Key_H             = 72,
	Key_I             = 73,
	Key_J             = 74,
	Key_K             = 75,
	Key_L             = 76,
	Key_M             = 77,
	Key_N             = 78,
	Key_O             = 79,
	Key_P             = 80,
	Key_Q             = 81,
	Key_R             = 82,
	Key_S             = 83,
	Key_T             = 84,
	Key_U             = 85,
	Key_V             = 86,
	Key_W             = 87,
	Key_X             = 88,
	Key_Y             = 89,
	Key_Z             = 90,


	/** Function keys **/

	/* Named non-printable keys */
	Key_Escape        = 256,
	Key_Enter         = 257,
	Key_Tab           = 258,
	Key_Backspace     = 259,
	Key_Insert        = 260,
	Key_Delete        = 261,
	Key_Right         = 262,
	Key_Left          = 263,
	Key_Down          = 264,
	Key_Up            = 265,
	Key_Page_Up       = 266,
	Key_Page_Down     = 267,
	Key_Home          = 268,
	Key_End           = 269,
	Key_Caps_Lock     = 280,
	Key_Scroll_Lock   = 281,
	Key_Num_Lock      = 282,
	Key_Print_Screen  = 283,
	Key_Pause         = 284,

	/* Function keys */
	Key_F1            = 290,
	Key_F2            = 291,
	Key_F3            = 292,
	Key_F4            = 293,
	Key_F5            = 294,
	Key_F6            = 295,
	Key_F7            = 296,
	Key_F8            = 297,
	Key_F9            = 298,
	Key_F10           = 299,
	Key_F11           = 300,
	Key_F12           = 301,
	Key_F13           = 302,
	Key_F14           = 303,
	Key_F15           = 304,
	Key_F16           = 305,
	Key_F17           = 306,
	Key_F18           = 307,
	Key_F19           = 308,
	Key_F20           = 309,
	Key_F21           = 310,
	Key_F22           = 311,
	Key_F23           = 312,
	Key_F24           = 313,
	Key_F25           = 314,

	/* Keypad numbers */
	Key_Kp_0          = 320,
	Key_Kp_1          = 321,
	Key_Kp_2          = 322,
	Key_Kp_3          = 323,
	Key_Kp_4          = 324,
	Key_Kp_5          = 325,
	Key_Kp_6          = 326,
	Key_Kp_7          = 327,
	Key_Kp_8          = 328,
	Key_Kp_9          = 329,

	/* Keypad named function keys */
	Key_Kp_Decimal    = 330,
	Key_Kp_Divide     = 331,
	Key_Kp_Multiply   = 332,
	Key_Kp_Subtract   = 333,
	Key_Kp_Add        = 334,
	Key_Kp_Enter      = 335,
	Key_Kp_Equal      = 336,

	/* Modifier keys */
	Key_Left_Shift    = 340,
	Key_Left_Control  = 341,
	Key_Left_Alt      = 342,
	Key_Left_Super    = 343,
	Key_Right_Shift   = 344,
	Key_Right_Control = 345,
	Key_Right_Alt     = 346,
	Key_Right_Super   = 347,
	Key_Menu          = 348,
}

keyboard :: proc() -> ^Keyboard {
	return &game().keyboard
}

keyboard_is_key_down :: proc(key: Keyboard_Key_Value) -> bool {
	state, ok := keyboard().key_map[key]
	return ok && (state == .Press || state == .Down || state == .Repeat)
}

keyboard_is_key_up :: proc(key: Keyboard_Key_Value) -> bool {
	state, ok := keyboard().key_map[key]
	return !ok || (state == .Release || state == .Up)
}

keyboard_is_key_press :: proc(key: Keyboard_Key_Value) -> bool {
	state, ok := keyboard().key_map[key]
	return ok && state == .Press
}

keyboard_is_key_release :: proc(key: Keyboard_Key_Value) -> bool {
	state, ok := keyboard().key_map[key]
	return ok && state == .Release
}

keyboard_on_key :: proc "c" (
	window: glfw.WindowHandle,
	key: c.int,
	scancode: c.int,
	action: c.int,
	mods: c.int,
) {
	context = runtime.default_context()
	context.user_ptr = glfw.GetWindowUserPointer(window)

	switch action {
	case glfw.RELEASE:
		keyboard().key_map[cast(Keyboard_Key_Value)key] = .Release
	case glfw.PRESS:
		keyboard().key_map[cast(Keyboard_Key_Value)key] = .Press
	case glfw.REPEAT:
		keyboard().key_map[cast(Keyboard_Key_Value)key] = .Repeat
	}
}

keyboard_init :: proc() {
	glfw.SetKeyCallback(window.handle, keyboard_on_key)
	// key_map = make(map[Key_Value]Key_State)
}

keyboard_deinit :: proc() {
	delete(keyboard().key_map)
}

keyboard_update :: proc() {
	for key in keyboard().key_map {
		switch state := &keyboard().key_map[key]; state^ {
		case .Press, .Repeat, .Down:
			state^ = .Down
		case .Release, .Up:
			state^ = .Up
		}
	}
}
