package game

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"

import gl "vendor:OpenGL"

import "../game"
import "../keyboard"
import "../mouse"

Object_Tool_Mode :: enum {
	Pick,
	Place,
	Move,
}

Object_Tool_Context :: struct {
	cursor_pos:                   glsl.vec3,
	object_pos:                   glsl.vec3,
	objects:                      [dynamic]Object,
	original_objects:             [dynamic]Object,
	tile_marker:                  Object,
	tile_draw_ids:                [dynamic]Object_Draw_Id,
	previous_object_under_cursor: Maybe(Object_Id),
	previous_mode:                Object_Tool_Mode,
	mode:                         Object_Tool_Mode,
}

init_object_tool :: proc() {
	ctx := get_object_tool_context()
	// ctx.object.type = .Table
	// ctx.object.light = {1, 1, 1}
	// ctx.object.model = PLANK_TABLE_6PLACES_MODEL
	// ctx.object.size = get_object_size(ctx.object.model)
	// ctx.object.texture = PLANK_TABLE_6PLACES_TEXTURE
	// ctx.object.placement = .Floor
	// ctx.object.orientation = .North

	ctx.tile_marker.model = "Tile_Marker.Bake"
	ctx.tile_marker.texture = "resources/textures/objects/Tile_Marker.Bake.png"
	ctx.tile_marker.light = {1, 1, 1}

	// ctx.object_draw_id = create_object_draw(
	// 	object_draw_from_object(ctx.object),
	// )

	// create_object_tool_tile_marker_object_draws()
}

close_object_tool :: proc() {
	ctx := get_object_tool_context()

	object_tool_on_escape()
}

deinit_object_tool :: proc() {
	ctx := get_object_tool_context()

	delete(ctx.tile_draw_ids)
	delete(ctx.objects)
	delete(ctx.original_objects)
}

clear_object_tool_tile_marker_object_draws :: proc() {
	ctx := get_object_tool_context()

	for id in ctx.tile_draw_ids {
		delete_object_draw(id)
	}

	clear(&ctx.tile_draw_ids)
}

create_object_tool_tile_marker_object_draws :: proc() {
	ctx := get_object_tool_context()

	clear_object_tool_tile_marker_object_draws()

	it := make_object_tiles_iterator(ctx.objects[0])
	for pos in next_object_tile_pos(&it) {
		ctx.tile_marker.pos = pos
		append(
			&ctx.tile_draw_ids,
			create_object_draw(object_draw_from_object(ctx.tile_marker)),
		)
	}
}

update_object_tool_tile_marker_object_draws :: proc(light: glsl.vec3) {
	ctx := get_object_tool_context()

	it := make_object_tiles_iterator(ctx.objects[0])
	for pos, i in next_object_tile_pos(&it) {
		ctx.tile_marker.pos = pos
		draw := object_draw_from_object(ctx.tile_marker)
		draw.light = light
		draw.id = ctx.tile_draw_ids[i]
		update_object_draw(draw)
	}
}

set_object_tool_object :: proc(object: Object) -> (ok: bool = true) {
	object := object
	ctx := get_object_tool_context()
	if ctx.mode == .Move {
		return false
	}

	if ctx.mode == .Place {
		object.draw_id = ctx.objects[0].draw_id
		update_object_draw(object_draw_from_object(object))
		ctx.objects[0] = object
	} else {
		object.draw_id = create_object_draw(object_draw_from_object(object))
		ctx.mode = .Place
		append(&ctx.objects, object)
	}

	create_object_tool_tile_marker_object_draws()
	return
}

object_tool_pick_object :: proc() {
	ctx := get_object_tool_context()

	if object_under_cursor, ok := get_object_under_cursor(); ok {
		if previous_object_under_cursor, ok := ctx.previous_object_under_cursor.?;
		   ok && previous_object_under_cursor != object_under_cursor {
			if previous_obj, ok := get_object_by_id(
				previous_object_under_cursor,
			); ok {
				mouse.set_cursor(.Arrow)
				previous_obj.light = {1, 1, 1}
				update_object_draw(object_draw_from_object(previous_obj^))
			}
		}
		if object_ptr, ok := get_object_by_id(object_under_cursor); ok {
			object := object_ptr^
			if mouse.is_button_press(.Left) {
				ctx.previous_mode = ctx.mode
				if keyboard.is_key_down(.Key_Left_Control) {
					delete_object_by_id(object_under_cursor)
					ctx.previous_object_under_cursor = nil
					mouse.set_cursor(.Arrow)
				} else if keyboard.is_key_down(.Key_Left_Shift) {
					ctx.mode = .Place
					append(&ctx.objects, object)

					if object.placement == .Table ||
					   object.placement == .Counter {
						ctx.objects[0].pos.y -= 0.8
					}

					ctx.objects[0].draw_id = create_object_draw(
						object_draw_from_object(object),
					)
					create_object_tool_tile_marker_object_draws()
				} else {
					ctx.mode = .Move
					mouse.set_cursor(.Hand_Closed)
					append(&ctx.objects, object)
					append(&ctx.original_objects, object)

					for child in object.children {
						child_object, _ := get_object_by_id(child)
						append(&ctx.objects, child_object^)
						append(&ctx.original_objects, child_object^)
					}

					cursor_tile_pos := world_pos_to_tile_pos(ctx.cursor_pos)
					object_tile_pos := world_pos_to_tile_pos(
						ctx.objects[0].pos,
					)


					delete_object_by_id(ctx.objects[0].id)

					for &obj in ctx.objects {
						if obj.placement == .Table ||
						   obj.placement == .Counter {
							obj.pos.y -= 0.8
						}

						obj.draw_id = create_object_draw(
							object_draw_from_object(obj),
						)
						clear(&obj.children)
					}

					create_object_tool_tile_marker_object_draws()
					ctx.previous_object_under_cursor = nil
				}
			} else {
				if keyboard.is_key_down(.Key_Left_Control) {
					mouse.set_cursor(.Cross)
					object.light = {0.8, 0.2, 0.2}
				} else {
					mouse.set_cursor(.Hand)
					object.light = {1.5, 1.5, 1.5}
				}
				update_object_draw(object_draw_from_object(object))
				ctx.previous_object_under_cursor = object_under_cursor
			}
		}
	} else if object_under_cursor, ok := ctx.previous_object_under_cursor.?;
	   ok {
		if object, ok := get_object_by_id(object_under_cursor); ok {
			mouse.set_cursor(.Arrow)
			object.light = {1, 1, 1}
			update_object_draw(object_draw_from_object(object^))
			// ctx.previous_object_under_cursor = nil
		}
	}
}

@(private = "file")
object_tool_on_escape :: proc() {
	ctx := get_object_tool_context()

	ctx.previous_mode = ctx.mode
	ctx.mode = .Pick
	for obj in ctx.objects {
		delete_object_draw(obj.draw_id)
	}
	clear_object_tool_tile_marker_object_draws()
	clear(&ctx.objects)
}

object_tool_place_object :: proc() {
	ctx := get_object_tool_context()

	if keyboard.is_key_press(.Key_Escape) {
		object_tool_on_escape()
	} else if mouse.is_button_press(.Left) {
		id, _ := add_object(ctx.objects[0])

		if !keyboard.is_key_down(.Key_Left_Shift) {
			ctx.previous_mode = ctx.mode
			ctx.mode = .Pick

			delete_object_draw(ctx.objects[0].draw_id)
			clear_object_tool_tile_marker_object_draws()
			clear(&ctx.objects)
			ctx.previous_object_under_cursor = id
			mouse.set_cursor(.Arrow)
		}
	} else {
		if keyboard.is_key_press(.Key_R) {
			for &object in ctx.objects {
				rotate_object(&object)
			}
		}
		ctx.objects[0].pos = ctx.cursor_pos
	}
}

object_tool_move_object :: proc() {
	ctx := get_object_tool_context()

	if keyboard.is_key_press(.Key_Escape) {
		ctx.previous_mode = ctx.mode
		ctx.mode = .Pick
		for obj in ctx.original_objects {
			add_object(obj)
		}
		for obj in ctx.objects {
			delete_object_draw(obj.draw_id)
		}
		clear_object_tool_tile_marker_object_draws()
		clear(&ctx.objects)
		clear(&ctx.original_objects)
	} else if mouse.is_button_press(.Left) {

		for &obj in ctx.objects {
			id, _ := add_object(obj)
			ctx.previous_object_under_cursor = id
		}

		ctx.previous_mode = ctx.mode
		if keyboard.is_key_down(.Key_Left_Shift) {
			ctx.mode = .Place
		} else {
			ctx.mode = .Pick

			for &obj in ctx.objects {
				delete_object_draw(obj.draw_id)
			}

			clear_object_tool_tile_marker_object_draws()
			clear(&ctx.objects)
			mouse.set_cursor(.Arrow)
		}

		clear(&ctx.original_objects)
	} else {
		root_pos := ctx.objects[0].pos
		if keyboard.is_key_press(.Key_R) {
			for &object in ctx.objects {
				rotate_object(&object)
				t_pos := object.pos - root_pos
				rotate_pos := t_pos.zyx
				rotate_pos.z *= -1
				object.pos = root_pos + rotate_pos
			}
		}

		new_pos := ctx.cursor_pos
		log.info(new_pos)
		for &obj in ctx.objects {
			obj.pos += new_pos - root_pos
			obj.pos.xz = glsl.clamp(
				obj.pos.xz,
				glsl.vec2{0, 0},
				glsl.vec2 {
					game.WORLD_WIDTH - 1,
					game.WORLD_DEPTH - 1,
				},
			)
		}
	}
}

update_object_tool :: proc() {
	ctx := get_object_tool_context()

	previous_pos: glsl.vec3
	previous_orientation: Object_Orientation
	if len(ctx.objects) > 0 {
		previous_pos = ctx.objects[0].pos
		previous_orientation = ctx.objects[0].orientation
	}

    floor := get_floor_context()
	on_cursor_tile_intersect(
		object_tool_on_intersect,
		floor.previous_floor,
		floor.floor,
	)

	switch ctx.mode {
	case .Pick:
		object_tool_pick_object()
	case .Place:
		object_tool_place_object()
	case .Move:
		object_tool_move_object()
	}

	if ctx.mode != .Pick {
		can_add: bool
		for placement in ctx.objects[0].placement_set {
			ctx.objects[0].placement = placement
			can_add = can_add_object(ctx.objects[0])

			if can_add {
				root := ctx.objects[0]
				previous_pos := root.pos
				clamp_object(&root)
				new_pos := root.pos
				for &obj in ctx.objects {
					obj.pos += new_pos - previous_pos
				}
				break
			} else if ctx.objects[0].placement == .Wall &&
			   mouse.is_button_up(.Left) {
				snap_wall_object()
				break
			}
		}

		if previous_pos != ctx.objects[0].pos {
			update_wall_masks_on_object_placement(
				previous_pos,
				previous_orientation,
			)
		}

		draw_object_tool(can_add)
	}
}

snap_wall_object :: proc() {
	ctx := get_object_tool_context()

	for i in 0 ..< len(Object_Orientation) {
		obj := ctx.objects[0]
		obj.orientation = Object_Orientation(
			(int(obj.orientation) + i) % len(Object_Orientation),
		)

		if can_add_object(obj) {
			ctx.objects[0].orientation = obj.orientation
			break
		}
	}
}

update_wall_masks_on_object_placement :: proc(
	previous_pos: glsl.vec3,
	previous_orientation: Object_Orientation,
) {
	ctx := get_object_tool_context()

	if ctx.objects[0].type != .Window && ctx.objects[0].type != .Door {
		return
	}

	previous_obj := ctx.objects[0]
	previous_obj.pos = previous_pos
	previous_obj.orientation = previous_orientation

	if can_add_object(previous_obj) {
		set_wall_mask_from_object(previous_obj, .Full_Mask)
	}

	if can_add_object(ctx.objects[0]) {
		set_wall_mask_from_object(ctx.objects[0], ctx.objects[0].wall_mask.?)
	}
}

set_wall_mask_from_object :: proc(obj: Object, mask: Wall_Mask_Texture) {
	it := make_object_tiles_iterator(obj)
	for pos in next_object_tile_pos(&it) {
		tile_pos := world_pos_to_tile_pos(pos)
		chunk_pos := world_pos_to_chunk_pos(pos)
		wall_pos: glsl.ivec3 = {tile_pos.x, chunk_pos.y, tile_pos.y}
		axis: Wall_Axis
		switch obj.orientation {
		case .East:
			wall_pos.x += 1
			axis = .N_S
		case .West:
			axis = .N_S
		case .South:
			axis = .E_W
		case .North:
			wall_pos.z += 1
			axis = .E_W
		}

		w, _ := get_wall(wall_pos, axis)
		w.mask = mask
		set_wall(wall_pos, axis, w)
	}
}

object_tool_on_intersect :: proc(intersect: glsl.vec3) {
	ctx := get_object_tool_context()
	ctx.cursor_pos = intersect
}

draw_object_tool :: proc(can_add: bool) -> bool {
	ctx := get_object_tool_context()

	light: glsl.vec3
	if !can_add {
		light = {0.8, 0.2, 0.2}
	} else {
		light = {1, 1, 1}
	}

	for object in ctx.objects {
		object := object
		if !can_add {
			object.pos += {0, 0.01, 0}
		}

		object.light = light

		if object.placement == .Counter || object.placement == .Table {
			object.pos.y += 0.8
		}

		draw := object_draw_from_object(object)
		// log.info(draw)
		update_object_draw(draw)
	}
	update_object_tool_tile_marker_object_draws(light)

	return true
}
