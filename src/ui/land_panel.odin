package ui

import "core:math/linalg/glsl"

import "../tools"
import "../tools/terrain_tool"
import "../game"

LAND_ICON_TEXTURES :: []cstring {
	"resources/icons/land_brush_size.png",
	"resources/icons/land_brush_strength.png",
	"resources/icons/land_raise.png",
	"resources/icons/land_lower.png",
	"resources/icons/land_level.png",
	"resources/icons/land_trim.png",
	"resources/icons/land_slope.png",
	"resources/icons/land_smooth.png",
}

Land_Icon_Texture :: enum {
	Brush_Size,
	Brush_Strength,
	Raise,
	Lower,
	Level,
	Trim,
	Slope,
	Smooth,
}

land_panel_texture_array: u32

init_land_panel :: proc() -> (ok: bool = true) {
	init_icon_texture_array(
		&land_panel_texture_array,
		LAND_ICON_TEXTURES,
	) or_return

	return
}

LAND_PANEL_TILE_SIZE :: 47
LAND_PANEL_BRUSH_TILE_SIZE :: 23

land_panel_body :: proc(using ctx: ^Context, pos: glsl.vec2, size: glsl.vec2) {
	if icon_button(
		   ctx,
		   pos = {pos.x + 4, pos.y + 4},
		   size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
		   color = terrain_tool.mode == .Raise ? DARK_BLUE : ROYAL_BLUE,
		   texture_array = land_panel_texture_array,
		   texture = int(Land_Icon_Texture.Raise),
	   ) {
		terrain_tool.mode = .Raise
	}

	if icon_button(
		   ctx,
		   pos = {pos.x + 4, pos.y + size.y - LAND_PANEL_TILE_SIZE - 4},
		   size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
		   color = terrain_tool.mode == .Lower ? DARK_BLUE : ROYAL_BLUE,
		   texture_array = land_panel_texture_array,
		   texture = int(Land_Icon_Texture.Lower),
	   ) {
		terrain_tool.mode = .Lower
	}

	if icon_button(
		   ctx,
		   pos = {pos.x + LAND_PANEL_TILE_SIZE + 4 + 2, pos.y + 4},
		   size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
		   color = terrain_tool.mode == .Level ? DARK_BLUE : ROYAL_BLUE,
		   texture_array = land_panel_texture_array,
		   texture = int(Land_Icon_Texture.Level),
	   ) {
		terrain_tool.mode = .Level
	}

	if icon_button(
		   ctx,
		   pos =  {
			   pos.x + LAND_PANEL_TILE_SIZE + 4 + 2,
			   pos.y + size.y - LAND_PANEL_TILE_SIZE - 4,
		   },
		   size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
		   color = terrain_tool.mode == .Trim ? DARK_BLUE : ROYAL_BLUE,
		   texture_array = land_panel_texture_array,
		   texture = int(Land_Icon_Texture.Trim),
	   ) {
		terrain_tool.mode = .Trim
	}

	if icon_button(
		   ctx,
		   pos = {pos.x + (LAND_PANEL_TILE_SIZE + 2) * 2 + 4, pos.y + 4},
		   size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
		   color = terrain_tool.mode == .Slope ? DARK_BLUE : ROYAL_BLUE,
		   texture_array = land_panel_texture_array,
		   texture = int(Land_Icon_Texture.Slope),
	   ) {
		terrain_tool.mode = .Slope
	}

	if icon_button(
		   ctx,
		   pos =  {
			   pos.x + (LAND_PANEL_TILE_SIZE + 2) * 2 + 4,
			   pos.y + size.y - LAND_PANEL_TILE_SIZE - 4,
		   },
		   size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
		   color = terrain_tool.mode == .Smooth ? DARK_BLUE : ROYAL_BLUE,
		   texture_array = land_panel_texture_array,
		   texture = int(Land_Icon_Texture.Smooth),
	   ) {
		terrain_tool.mode = .Smooth
	}
}

land_panel_brush_body :: proc(
	using ctx: ^Context,
	pos: glsl.vec2,
	size: glsl.vec2,
) {
	if button(
		   ctx,
		   {pos.x + 2, pos.y + 4},
		   {LAND_PANEL_BRUSH_TILE_SIZE, LAND_PANEL_BRUSH_TILE_SIZE},
		   "+",
		   txt_size = 32,
		   padding_top = 4,
	   ) {
		terrain_tool.increase_brush_size()
	} else if button(
		   ctx,
		   {pos.x + 2, pos.y + LAND_PANEL_BRUSH_TILE_SIZE + 4},
		   {LAND_PANEL_BRUSH_TILE_SIZE, LAND_PANEL_BRUSH_TILE_SIZE},
		   "-",
		   txt_size = 32,
		   padding_top = 1,
	   ) {
		terrain_tool.decrease_brush_size()
	}

	icon(
		ctx,
		 {
			pos = {pos.x + 2 + LAND_PANEL_BRUSH_TILE_SIZE + 2, pos.y + 4},
			size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
			color = ROYAL_BLUE,
			texture_array = land_panel_texture_array,
			texture = int(Land_Icon_Texture.Brush_Size),
			left_border_width = BORDER_WIDTH,
			right_border_width = BORDER_WIDTH,
			top_border_width = BORDER_WIDTH,
			bottom_border_width = BORDER_WIDTH,
		},
	)

	if button(
		   ctx,
		   {pos.x + 2, pos.y + size.y - LAND_PANEL_TILE_SIZE - 4},
		   {LAND_PANEL_BRUSH_TILE_SIZE, LAND_PANEL_BRUSH_TILE_SIZE},
		   "+",
		   txt_size = 32,
		   padding_top = 4,
	   ) {
		terrain_tool.increase_brush_strength()
	} else if button(
		   ctx,
		   {pos.x + 2, pos.y + size.y - LAND_PANEL_BRUSH_TILE_SIZE - 4},
		   {LAND_PANEL_BRUSH_TILE_SIZE, LAND_PANEL_BRUSH_TILE_SIZE},
		   "-",
		   txt_size = 32,
		   padding_top = 1,
	   ) {
		terrain_tool.decrease_brush_strength()
	}

	icon(
		ctx,
		 {
			pos =  {
				pos.x + 2 + LAND_PANEL_BRUSH_TILE_SIZE + 2,
				pos.y + size.y - LAND_PANEL_TILE_SIZE - 4,
			},
			size = {LAND_PANEL_TILE_SIZE, LAND_PANEL_TILE_SIZE},
			color = ROYAL_BLUE,
			texture_array = land_panel_texture_array,
			texture = int(Land_Icon_Texture.Brush_Strength),
			left_border_width = BORDER_WIDTH,
			right_border_width = BORDER_WIDTH,
			top_border_width = BORDER_WIDTH,
			bottom_border_width = BORDER_WIDTH,
		},
	)
}

land_panel :: proc(using ctx: ^Context) {
	if tools.active_tool == .Terrain {
		container(
			ctx,
			pos = {0, game.window().size.y - 31 - PANEL_HEIGHT},
			size =  {
				LAND_PANEL_BRUSH_TILE_SIZE + LAND_PANEL_TILE_SIZE + 8,
				PANEL_HEIGHT,
			},
			left_border_width = 0,
			body = land_panel_brush_body,
		)

		container(
			ctx,
			pos =  {
				LAND_PANEL_BRUSH_TILE_SIZE + LAND_PANEL_TILE_SIZE + 8,
				game.window().size.y - 31 - PANEL_HEIGHT,
			},
			size = {(LAND_PANEL_TILE_SIZE + 2) * 3 + 6, PANEL_HEIGHT},
			body = land_panel_body,
		)
	}
}
