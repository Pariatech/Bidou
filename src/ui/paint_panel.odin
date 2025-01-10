package ui

import "core:math/linalg/glsl"

import "../tools"
import "../tools/paint_tool"
import "../game"
import "../window"

init_paint_panel :: proc() -> (ok: bool = true) {
	return
}

PAINT_PANEL_TILE_WIDTH :: 32
PAINT_PANEL_TILE_HEIGHT :: 96

paint_panel_body :: proc(
	using ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
) {
	i: int = 0
	for tex in game.Wall_Texture {
		if tex == .Wall_Top || tex == .Frame || tex == .Drywall {
			continue
		}

		border_width := f32(BORDER_WIDTH)
		if paint_tool.texture == tex {
			border_width *= 2
		}

		if icon_button(
			   ctx,
			    {
				   pos.x + 2 + f32(i) * (PAINT_PANEL_TILE_WIDTH + 2),
                   pos.y + FLOOR_PANEL_PADDING,
			   },
			   {PAINT_PANEL_TILE_WIDTH, PAINT_PANEL_TILE_HEIGHT},
			   game.get_walls_context().texture_array,
			   int(tex),
			   left_border_width = border_width,
			   right_border_width = border_width,
			   top_border_width = border_width,
			   bottom_border_width = border_width,
		   ) {
			paint_tool.set_texture(tex)
		}

		i += 1
	}
}

paint_panel :: proc(using ctx: ^Context) {
	if tools.active_tool == .Paint {
		container(
			ctx,
			pos = {0, window.size.y - 31 - PANEL_HEIGHT},
			size = {window.size.x, PANEL_HEIGHT},
			left_border_width = 0,
			body = paint_panel_body,
		)
	}
}
