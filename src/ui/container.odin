package ui

import "core:log"
import "core:math/linalg/glsl"

import "../game"
import "../mouse"

Container :: struct {
	pos:  glsl.vec2,
	size: glsl.vec2,
}

container_noop :: proc(ctx: ^Context, pos: glsl.vec2, size: glsl.vec2) {}

container :: proc(
	using ctx: ^Context,
	pos: glsl.vec2 = {},
	size: glsl.vec2 = {},
	color: glsl.vec4 = BACKGROUND_BLUE,
	left_border_width: f32 = BORDER_WIDTH,
	right_border_width: f32 = BORDER_WIDTH,
	top_border_width: f32 = BORDER_WIDTH,
	bottom_border_width: f32 = BORDER_WIDTH,
	body: proc(
		ctx: ^Context,
		pos: glsl.vec2,
		size: glsl.vec2,
	) = container_noop,
) {
	rect(
		ctx,
		 {
			x = pos.x,
			y = pos.y,
			w = size.x,
			h = size.y,
			color = color,
			left_border_width = left_border_width,
			right_border_width = right_border_width,
			top_border_width = top_border_width,
			bottom_border_width = bottom_border_width,
		},
	)
	body(ctx, pos, size)

	if cursor_in(pos, size) {
		if mouse.is_button_press(.Left) || mouse.is_button_up(.Left) {
			focus = true
		}
		if focus {
			mouse.capture_all()
		}
	}
}

cursor_in :: proc(pos: glsl.vec2, size: glsl.vec2) -> bool {
    cursor := game.get_cursor_context()
	return(
		cursor.pos.x >= pos.x &&
		cursor.pos.x < pos.x + size.x &&
		cursor.pos.y >= pos.y &&
		cursor.pos.y < pos.y + size.y \
	)
}
