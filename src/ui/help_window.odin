package ui

import "core:log"
import "core:math/linalg/glsl"

import "../camera"
import "../cursor"
import "../mouse"

HELP_TEXT :: `---- Camera ----
W,A,S,D:      Move camera
Q,E:          Rotate camera
Mouse Scroll: Zoom

---- Land Tool [T] ----
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

---- Wall Tool [G] ----
Left Click & Drag:              Place Wall
Shift Left Click & Drag:        Place Wall Rectangle
Ctrl Left Click & Drag:         Remove Wall
Ctrl Shift Left Click & Drag:   Remove Wall Rectangle

---- Floor Tool [F] ----
Left Click & Drag:          Place
Ctrl Left Click & Drag:     Remove
Shift Left Click:           Fill Place
Ctrl Shift Left Click:      Fill Remove

---- Triangle Floor Tool [Ctrl F] ----
Left Click: Place
`

HELP_WINDOW_WIDTH :: 516

Help_Window :: struct {
	opened:              bool,
	scroll_bar_percent:  f32,
	scroll_bar_offset:   f32,
	scroll_bar_dragging: bool,
}

help_window_header :: proc(using ctx: ^Context) {
	using help_window_ctx
	text(ctx, {175 + HELP_WINDOW_WIDTH / 2, 180}, "Help", .CENTER, .TOP, 16)

	if button(
		   ctx,
		   {175 + HELP_WINDOW_WIDTH - 22, 179},
		   {18, 18},
		   "x",
		   {0.255, 0.412, 0.882, 1},
		   txt_size = 26,
	   ) {
		opened = false
	}
}

help_window_body :: proc(using ctx: ^Context) {
	using help_window_ctx

	min, max := text_bounds(
		ctx,
		{185, 210},
		HELP_TEXT,
		ah = .LEFT,
		av = .TOP,
		size = 18,
	)

	// log.info("min:", min, "max:", max)

	pos := glsl.vec2{175, 200}
	size := glsl.vec2{500, 400}
	scroll_bar_percent = 400 / (max.y - min.y)
	if cursor.pos.x >= pos.x &&
	   cursor.pos.x < pos.x + size.x &&
	   cursor.pos.y >= pos.y &&
	   cursor.pos.y < pos.y + size.y {
		scroll_bar_offset -= (mouse.vertical_scroll() / scroll_bar_percent) * 4
		scroll_bar_offset = clamp(
			scroll_bar_offset,
			0,
			size.y * (1 - scroll_bar_percent),
		)
		mouse.capture_vertical_scroll()
	}

	text(
		ctx,
		{185, 210 - scroll_bar_offset},
		HELP_TEXT,
		ah = .LEFT,
		av = .TOP,
		size = 18,
		clip_start = {185, 210},
		clip_end = {175 + 500 - 10, 200 + 400 - 10},
	)
}

help_window :: proc(using ctx: ^Context) {
	using help_window_ctx
	container(
		ctx,
		pos = {175, 175},
		size = {HELP_WINDOW_WIDTH, 26},
		color = {0.0, 0.251, 0.502, 1},
		body = help_window_header,
	)

	container(
		ctx,
		pos = {175, 200},
		size = {500, 400},
		body = help_window_body,
	)

	scroll_bar(
		ctx,
		{675, 200},
		{16, 400},
		scroll_bar_percent,
		&scroll_bar_offset,
		&scroll_bar_dragging,
	)
}
