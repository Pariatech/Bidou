package tools

import "core:log"

import "floor_tool"
import "paint_tool"
import "terrain_tool"
import "wall_tool"
import "../game"

TERRAIN_TOOL_KEY :: game.Keyboard_Key_Value.Key_1
WALL_TOOL_KEY :: game.Keyboard_Key_Value.Key_2
FLOOR_TOOL_KEY :: game.Keyboard_Key_Value.Key_3
PAINT_TOOL_KEY :: game.Keyboard_Key_Value.Key_4
FURNITURE_TOOL_KEY :: game.Keyboard_Key_Value.Key_7

active_tool: Tool = .Furniture

Tool :: enum {
	Terrain,
	Wall,
	Floor,
	Paint,
    Furniture,
    Roof,
}

update :: proc(delta_time: f64) {
	if game.keyboard_is_key_press(WALL_TOOL_KEY) {
		open_wall_tool()
	} else if game.keyboard_is_key_press(TERRAIN_TOOL_KEY) {
		open_land_tool()
	} else if game.keyboard_is_key_press(FLOOR_TOOL_KEY) {
		open_floor_tool()
	} else if game.keyboard_is_key_press(PAINT_TOOL_KEY) {
		open_paint_tool()
	} else if game.keyboard_is_key_press(FURNITURE_TOOL_KEY) {
        // open_furniture_tool()
    }

	switch active_tool {
	case .Terrain:
		terrain_tool.update(delta_time)
	case .Wall:
		wall_tool.update()
	case .Floor:
		floor_tool.update()
	case .Paint:
		paint_tool.update()
    case .Furniture:
        game.update_object_tool()
    case .Roof:
        game.update_roof_tool()
	}
}

open_wall_tool :: proc() {
	terrain_tool.deinit()
	floor_tool.deinit()
	paint_tool.deinit()
    game.close_object_tool()
    close_roof_tool()

	wall_tool.init()
	active_tool = .Wall
}

open_land_tool :: proc() {
	wall_tool.deinit()
	floor_tool.deinit()
	paint_tool.deinit()
    game.close_object_tool()
    close_roof_tool()

	terrain_tool.init()
	active_tool = .Terrain
}

open_floor_tool :: proc() {
	wall_tool.deinit()
	terrain_tool.deinit()
	paint_tool.deinit()
    game.close_object_tool()
    close_roof_tool()

	floor_tool.init()
	active_tool = .Floor
}

open_paint_tool :: proc() {
	floor_tool.deinit()
	wall_tool.deinit()
	terrain_tool.deinit()
    game.close_object_tool()
    close_roof_tool()

	paint_tool.init()
	active_tool = .Paint
}

open_furniture_tool :: proc() {
	floor_tool.deinit()
	wall_tool.deinit()
	terrain_tool.deinit()
	paint_tool.deinit()
    close_roof_tool()

	active_tool = .Furniture
}

close_roof_tool :: proc() {
    if active_tool != .Roof {
        return
    }

    game.deinit_roof_tool()
}

open_roof_tool :: proc() {
    if active_tool == .Roof {
        return
    }
	floor_tool.deinit()
	wall_tool.deinit()
	terrain_tool.deinit()
	paint_tool.deinit()
    game.close_object_tool()

    game.init_roof_tool()
	active_tool = .Roof
}

