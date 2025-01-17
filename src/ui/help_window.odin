package ui

import "core:log"
import "core:math/linalg/glsl"

import "../game"

HELP_TEXT :: `---- Camera ----
W,A,S,D:      Move camera
Q,E:          Rotate camera
Mouse Scroll: Zoom

---- Land Tool [1] ----
Only work on grass tiles

Left Click:              Raise land
Right Click:             Lower land
+:                       Increase brush size
-:                       Reduce brush size
Shift +:                 Increase brush strength
Shift -:                 Reduce brush strength
Ctrl Click:              Smooth land
Shift Click & Drag:      Level land
Ctrl Shift Click & Drag: Flatten land

---- Wall Tool [2] ----
Left Click & Drag:              Place Wall
Shift Left Click & Drag:        Place Wall Rectangle
Ctrl Left Click & Drag:         Remove Wall
Ctrl Shift Left Click & Drag:   Remove Wall Rectangle

---- Floor Tool [3] ----
Left Click & Drag:          Place
Ctrl Left Click & Drag:     Remove
Shift Left Click:           Fill Place
Ctrl Shift Left Click:      Fill Remove

---- Triangle Floor Tool [Ctrl F] ----
Left Click:         Place
Ctrl Left Click:    Remove

---- Paint Tool [4] ----
Left Click:             Paint Wall
Ctrl Left Click:        Remove Paint
Shift Left Click:       Paint Fill
Ctrl Shift Left Click:  Fill Remove

---- Furniture Tool ----
Left Click:         Pick/Place
Ctrl Left Click:    Remove
R:                  Rotate

Have fun!
 
 
`

HELP_WINDOW_BODY_WIDTH :: 500
HELP_WINDOW_BODY_HEIGHT :: 400
HELP_WINDOW_PADDING :: 10
HELP_WINDOW_SCROLL_BAR_WIDTH :: 16
HELP_WINDOW_WIDTH :: HELP_WINDOW_BODY_WIDTH + HELP_WINDOW_SCROLL_BAR_WIDTH

Help_Window :: struct {
	opened:              bool,
	scroll_bar_percent:  f32,
	scroll_bar_offset:   f32,
	scroll_bar_dragging: bool,
}

help_window_header :: proc(
	using ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
) {
	using help_window_ctx
	text(
		ctx,
		{pos.x + HELP_WINDOW_WIDTH / 2, pos.y + 5},
		"Help",
		.CENTER,
		.TOP,
		16,
	)

	// if button(
	// 	   ctx,
	// 	   {pos.x + HELP_WINDOW_WIDTH - 26, pos.y},
	// 	   {26, 26},
	// 	   "x",
	// 	   {0.255, 0.412, 0.882, 1},
	// 	   txt_size = 32,
	//    ) {
	// 	opened = false
	// }
}

help_window_body :: proc(
	using ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
) {
	using help_window_ctx

	min, max := text_bounds(
		ctx,
		pos + HELP_WINDOW_PADDING,
		HELP_TEXT,
		ah = .LEFT,
		av = .TOP,
		size = 18,
	)

	scroll_bar_percent = HELP_WINDOW_BODY_HEIGHT / (max.y - min.y)
	height := max.y - min.y
    cursor := game.get_cursor_context()
	if cursor.pos.x >= pos.x &&
	   cursor.pos.x < pos.x + size.x + HELP_WINDOW_SCROLL_BAR_WIDTH &&
	   cursor.pos.y >= pos.y &&
	   cursor.pos.y < pos.y + size.y {
		scroll_bar_offset -= (f32(game.mouse_vertical_scroll()) * scroll_bar_percent / 8)
		scroll_bar_offset = clamp(
			scroll_bar_offset,
			0,
			(1 - scroll_bar_percent),
		)
		game.mouse_capture_vertical_scroll()
	}

	text_offset: f32 = height * scroll_bar_offset
	text(
		ctx,
		 {
			pos.x + HELP_WINDOW_PADDING,
			pos.y + HELP_WINDOW_PADDING - text_offset,
		},
		HELP_TEXT,
		ah = .LEFT,
		av = .TOP,
		size = 18,
		clip_start = pos + HELP_WINDOW_PADDING,
		clip_end =  {
			pos.x + HELP_WINDOW_WIDTH - HELP_WINDOW_PADDING,
			pos.y + HELP_WINDOW_BODY_HEIGHT - HELP_WINDOW_PADDING,
		},
	)

	scroll_bar(
		ctx,
		{pos.x + HELP_WINDOW_BODY_WIDTH, 25},
		{HELP_WINDOW_SCROLL_BAR_WIDTH, 400},
		scroll_bar_percent,
		&scroll_bar_offset,
		&scroll_bar_dragging,
	)
}

help_window :: proc(using ctx: ^Context) {
	using help_window_ctx
	x := game.window().size.x - HELP_WINDOW_WIDTH
	container(
		ctx,
		pos = {x, 0},
		size = {HELP_WINDOW_WIDTH, 26},
		color = {0.0, 0.251, 0.502, 1},
		body = help_window_header,
	)

	container(
		ctx,
		pos = {x, 25},
		size = {HELP_WINDOW_BODY_WIDTH, 400},
		body = help_window_body,
	)
}
