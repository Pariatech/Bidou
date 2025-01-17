package ui

import "core:math/linalg/glsl"
import "core:strings"

import g "../game"
import "../tools"

FURNITURE_PANEL_TILE_SIZE :: 47
FURNITURE_PANEL_PADDING :: 4

Furniture :: struct {
	icon:      cstring,
	model:     string,
	texture:   string,
	placement: g.Object_Placement_Set,
	type:      g.Object_Type,
}

furniture_panel_icon_texture_arrays: []u32

furniture_panel_body :: proc(
	using ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
) {
	game: ^g.Game_Context = cast(^g.Game_Context)context.user_ptr

	for blueprint, i in game.object_blueprints {
		border_width := f32(BORDER_WIDTH)

		if icon_button(
			   ctx,
			    {
				   2 + f32(i / 2) * (FURNITURE_PANEL_TILE_SIZE + 2),
				   pos.y +
				   FURNITURE_PANEL_PADDING +
				   f32(i % 2) * (FURNITURE_PANEL_TILE_SIZE + 2),
			   }, // 2 + f32(i) * (FURNITURE_PANEL_TILE_SIZE + 2),// window.size.y - 31 - PANEL_HEIGHT + FLOOR_PANEL_PADDING,
			   {FURNITURE_PANEL_TILE_SIZE, FURNITURE_PANEL_TILE_SIZE},
			   furniture_panel_icon_texture_arrays[i],
			   int(i),
			   top_padding = 0,
			   bottom_padding = 0,
			   left_padding = 0,
			   right_padding = 0,
			   left_border_width = border_width,
			   right_border_width = border_width,
			   top_border_width = border_width,
			   bottom_border_width = border_width,
			   color = DAY_SKY_BLUE,
		   ) {
			g.set_object_tool_object(
				 {
					model = blueprint.model,
					texture = blueprint.texture,
					type = blueprint.category,
					size = blueprint.size,
					light = {1, 1, 1},
					placement_set = blueprint.placement_set,
                    wall_mask = blueprint.wall_mask,
				},
			)
		}
	}
}

furniture_panel :: proc(using ctx: ^Context) {
	if tools.active_tool == .Furniture {
		container(
			ctx,
			pos = {0, g.window().size.y - 31 - PANEL_HEIGHT},
			size = {g.window().size.x, PANEL_HEIGHT},
			left_border_width = 0,
			body = furniture_panel_body,
		)
	}
}

init_furniture_panel :: proc(
	game: ^g.Game_Context = cast(^g.Game_Context)context.user_ptr,
) -> bool {
	furniture_panel_icon_texture_arrays = make(
		[]u32,
		len(game.object_blueprints),
	)
	for blueprint, i in game.object_blueprints {
		init_icon_texture_array(
			&furniture_panel_icon_texture_arrays[i],
			{strings.unsafe_string_to_cstring(blueprint.icon)},
		) or_return
	}

	return true
}
