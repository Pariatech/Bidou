package ui

import "core:math/linalg/glsl"

import "../game"
import "../tools/floor_tool"
import "../window"

Floor_Panel :: struct {
	opened: bool,
}

FLOOR_PANEL_TILE_SIZE :: 47
FLOOR_PANEL_PADDING :: 4

floor_panel_body :: proc(
	using ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
) {
	i: int = 0
	for tex in game.Tile_Triangle_Texture {
		if tex == .Floor_Marker || tex == .Grass_004 {
			continue
		}

		border_width := f32(BORDER_WIDTH)
		if floor_tool.active_texture == tex {
			border_width *= 2
		}


		if icon_button(
			   ctx,
			    {
				   2 + f32(i / 2) * (FLOOR_PANEL_TILE_SIZE + 2),
				   pos.y +
				   FLOOR_PANEL_PADDING +
				   f32(i % 2) * (FLOOR_PANEL_TILE_SIZE + 2),
			   },
			   {FLOOR_PANEL_TILE_SIZE, FLOOR_PANEL_TILE_SIZE},
			   game.get_tile_triangles_context().texture_array,
			   int(tex),
			   left_border_width = border_width,
			   right_border_width = border_width,
			   top_border_width = border_width,
			   bottom_border_width = border_width,
		   ) {
			floor_tool.active_texture = tex
		}

		i += 1
	}
}

floor_panel :: proc(using ctx: ^Context) {
	container(
		ctx,
		pos = {0, window.size.y - 31 - PANEL_HEIGHT},
		size = {window.size.x, PANEL_HEIGHT},
		left_border_width = 0,
		body = floor_panel_body,
	)
}
