package game

import "core:log"

TOOLS_TERRAIN_TOOL_KEY :: Keyboard_Key_Value.Key_1
TOOLS_WALL_TOOL_KEY :: Keyboard_Key_Value.Key_2
TOOLS_FLOOR_TOOL_KEY :: Keyboard_Key_Value.Key_3
TOOLS_PAINT_TOOL_KEY :: Keyboard_Key_Value.Key_4
TOOLS_FURNITURE_TOOL_KEY :: Keyboard_Key_Value.Key_7
TOOLS_MAX_UNDOS :: 10

Tools :: struct {
	active_tool: Tool,
	undos:       [dynamic]Tools_Command,
	redos:       [dynamic]Tools_Command,
}

Tool :: enum {
	Terrain,
	Wall,
	Floor,
	Paint,
	Furniture,
	Roof,
}

Tools_Command :: union {
	Terrain_Tool_Command,
	Floor_Tool_Command,
	Paint_Tool_Command,
}

tools :: proc() -> ^Tools {
	return &game().tools
}

tools_update :: proc(delta_time: f64) {
	if keyboard_is_key_press(TOOLS_WALL_TOOL_KEY) {
		tools_open_wall_tool()
	} else if keyboard_is_key_press(TOOLS_TERRAIN_TOOL_KEY) {
		tools_open_land_tool()
	} else if keyboard_is_key_press(TOOLS_FLOOR_TOOL_KEY) {
		tools_open_floor_tool()
	} else if keyboard_is_key_press(TOOLS_PAINT_TOOL_KEY) {
		tools_open_paint_tool()
	} else if keyboard_is_key_press(TOOLS_FURNITURE_TOOL_KEY) {
		// open_furniture_tool()
	}

	switch tools().active_tool {
	case .Terrain:
		terrain_tool_update(delta_time)
	case .Wall:
		wall_tool_update()
	case .Floor:
		floor_tool_update()
	case .Paint:
		paint_tool_update()
	case .Furniture:
		update_object_tool()
	case .Roof:
		update_roof_tool()
	}
}

tools_open_wall_tool :: proc() {
	terrain_tool_deinit()
	floor_tool_revert_tiles()
	paint_tool_clear_previous_walls()
	close_object_tool()
	tools_close_roof_tool()

	wall_tool_init()
	tools().active_tool = .Wall
}

tools_open_land_tool :: proc() {
	wall_tool_deinit()
	floor_tool_revert_tiles()
	paint_tool_clear_previous_walls()
	close_object_tool()
	tools_close_roof_tool()

	terrain_tool_init()
	tools().active_tool = .Terrain
}

tools_open_floor_tool :: proc() {
	wall_tool_deinit()
	terrain_tool_deinit()
	paint_tool_clear_previous_walls()
	close_object_tool()
	tools_close_roof_tool()

	floor_tool_init()
	tools().active_tool = .Floor
}

tools_open_paint_tool :: proc() {
	floor_tool_revert_tiles()
	wall_tool_deinit()
	terrain_tool_deinit()
	close_object_tool()
	tools_close_roof_tool()

	paint_tool_init()
	tools().active_tool = .Paint
}

tools_open_furniture_tool :: proc() {
	floor_tool_revert_tiles()
	wall_tool_deinit()
	terrain_tool_deinit()
	paint_tool_clear_previous_walls()
	tools_close_roof_tool()

	tools().active_tool = .Furniture
}

tools_close_roof_tool :: proc() {
	if tools().active_tool != .Roof {
		return
	}

	deinit_roof_tool()
}

tools_open_roof_tool :: proc() {
	if tools().active_tool == .Roof {
		return
	}
	floor_tool_revert_tiles()
	wall_tool_deinit()
	terrain_tool_deinit()
	paint_tool_clear_previous_walls()
	close_object_tool()

	init_roof_tool()
	tools().active_tool = .Roof
}

tools_undo :: proc() {
	if len(tools().undos) == 0 {
		log.debug("Nothing to undo!")
		return
	}

	command := pop(&tools().undos)
	append(&tools().redos, command)
	switch v in command {
	case Terrain_Tool_Command:
		terrain_tool_undo(v)
	case Floor_Tool_Command:
		floor_tool_undo(v)
	case Paint_Tool_Command:
		paint_tool_undo(v)
	}
}

tools_redo :: proc() {
	if len(tools().redos) == 0 {
		log.debug("Nothing to redo!")
		return
	}

	command := pop(&tools().redos)
	append(&tools().undos, command)
	switch v in command {
	case Terrain_Tool_Command:
		terrain_tool_redo(v)
	case Floor_Tool_Command:
		floor_tool_redo(v)
	case Paint_Tool_Command:
		paint_tool_redo(v)
	}
}

tools_deinit :: proc() {
	tools_delete_undos()
	tools_delete_redos()

	delete(tools().undos)
	delete(tools().redos)

    delete(terrain_tool().current_command.before)
    delete(terrain_tool().current_command.after)
}

tools_delete_undos :: proc() {
	for undo in tools().undos {
		tools_delete_undo(undo)
	}
}

tools_delete_undo :: proc(undo: Tools_Command) {
	switch &v in undo {
	case Terrain_Tool_Command:
		delete(v.before)
		delete(v.after)
	case Floor_Tool_Command:
		delete(v.before)
		delete(v.after)
	case Paint_Tool_Command:
		delete(v.before)
		delete(v.after)
	}
}

tools_add_command :: proc(command: Tools_Command) {
	if len(tools().undos) == TOOLS_MAX_UNDOS {
		tools_delete_undo(pop(&tools().undos))
	}
	append(&tools().undos, command)
	tools_delete_redos()
	clear(&tools().redos)
}

tools_delete_redos :: proc() {
	for redo in tools().redos {
		switch &v in redo {
		case Terrain_Tool_Command:
			delete(v.before)
			delete(v.after)
		case Floor_Tool_Command:
			delete(v.before)
			delete(v.after)
		case Paint_Tool_Command:
			delete(v.before)
			delete(v.after)
		}
	}
}
