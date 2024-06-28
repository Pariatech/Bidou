package wall

import "core:log"
import "core:math/linalg/glsl"

import "../camera"
import "../floor"

Cutaway_State :: enum {
	Up,
	Down,
}

cutaway_state: Cutaway_State

previous_visible_chunks_start: glsl.ivec2
previous_visible_chunks_end: glsl.ivec2

CUTAWAY_WALL_MASK_MAP :: [State][Wall_Axis][camera.Rotation]Wall_Mask{}

set_walls_down :: proc() {
	cutaway_state = .Down
	set_cutaway(.Down)
}

set_walls_up :: proc() {
	cutaway_state = .Up
	set_cutaway(.Up)
}

set_cutaway :: proc(state: State) {
	for x in camera.visible_chunks_start.x ..< camera.visible_chunks_end.x {
		for z in camera.visible_chunks_start.y ..< camera.visible_chunks_end.y {
			chunk := &chunks[floor.floor][x][z]
			chunk.dirty = true

			for wall_pos, &w in chunk.east_west {
				w.state = state
			}

			for wall_pos, &w in chunk.north_south {
				w.state = state
			}

			for wall_pos, &w in chunk.south_west_north_east {
				w.state = state
			}

			for wall_pos, &w in chunk.north_west_south_east {
				w.state = state
			}
		}
	}
}

init_cutaways :: proc() {
	// set_walls_down()
}

apply_cutaway :: proc() -> bool {
	if cutaway_state != .Down {
		return false
	}

	if floor.previous_floor != floor.floor {
		return true
	}

	if previous_visible_chunks_start != camera.visible_chunks_start {
		return true
	}

	if previous_visible_chunks_end != camera.visible_chunks_end {
		return true
	}

	// if chunk.dirty {
	// 	return true
	// }

	return false
}

wall_is_frame :: proc(w: Wall) -> bool {
	return w.textures == {.Inside = .Frame, .Outside = .Frame}
}

update_cutaways :: proc(force: bool = false) {
	if !force && !apply_cutaway() {
		return
	}

	for x in camera.visible_chunks_start.x ..< camera.visible_chunks_end.x {
		for z in camera.visible_chunks_start.y ..< camera.visible_chunks_end.y {
			chunk := &chunks[floor.previous_floor][x][z]

			chunk.dirty = true

			for wall_pos, &w in chunk.east_west {
				w.state = .Up
			}

			for wall_pos, &w in chunk.north_south {
				w.state = .Up
			}

			for wall_pos, &w in chunk.south_west_north_east {
				w.state = .Up
			}

			for wall_pos, &w in chunk.north_west_south_east {
				w.state = .Up
			}

			if cutaway_state == .Down {
				chunk := &chunks[floor.floor][x][z]
				chunk.dirty = true

				for wall_pos, &w in chunk.east_west {
					if wall_is_frame(w) {
						continue
					}
					w.state = .Down
				}

				for wall_pos, &w in chunk.north_south {
					if wall_is_frame(w) {
						continue
					}
					w.state = .Down
				}

				for wall_pos, &w in chunk.south_west_north_east {
					if wall_is_frame(w) {
						continue
					}
					w.state = .Down
				}

				for wall_pos, &w in chunk.north_west_south_east {
					if wall_is_frame(w) {
						continue
					}
					w.state = .Down
				}
			}
		}
	}

	previous_visible_chunks_start = camera.visible_chunks_start
	previous_visible_chunks_end = camera.visible_chunks_end
}

set_wall_up :: proc(pos: glsl.ivec3, axis: Wall_Axis) {
	if cutaway_state == .Up {
		return
	}

	w, ok := get_wall(pos, axis)
	if !ok {
		return
	}

	w.state = .Up
	set_wall(pos, axis, w)

	ew_left: State
	ew_right: State

	switch camera.rotation {
	case .South_West, .North_West:
		ew_left = .Left
		ew_right = .Right
	case .South_East, .North_East:
		ew_left = .Right
		ew_right = .Left
	}

	ns_left: State
	ns_right: State

	switch camera.rotation {
	case .South_West, .South_East:
		ns_left = .Left
		ns_right = .Right
	case .North_West, .North_East:
		ns_left = .Right
		ns_right = .Left
	}

	diagonal_left: State
	diagonal_right: State

	switch camera.rotation {
	case .South_West, .South_East:
		diagonal_left = .Left
		diagonal_right = .Right
	case .North_East, .North_West:
		diagonal_left = .Right
		diagonal_right = .Left
	}

	switch axis {
	case .E_W:
		if w, ok := get_wall(pos + {-1, 0, 0}, .E_W); ok {
            w.state = ew_left
			set_wall(pos + {-1, 0, 0}, .E_W, w)
		}
		if w, ok := get_wall(pos + {1, 0, 0}, .E_W); ok {
			w.state = ew_right
			set_wall(pos + {1, 0, 0}, .E_W, w)
		}

		if w, ok := get_wall(pos + {0, 0, 0}, .N_S); ok {
			w.state = ns_right
			set_wall(pos + {0, 0, 0}, .N_S, w)
		}
		if w, ok := get_wall(pos + {0, 0, -1}, .N_S); ok {
            w.state = ns_left
			set_wall(pos + {0, 0, -1}, .N_S, w)
		}
		if w, ok := get_wall(pos + {1, 0, 0}, .N_S); ok {
			w.state = ns_right
			set_wall(pos + {1, 0, 0}, .N_S, w)
		}
		if w, ok := get_wall(pos + {1, 0, -1}, .N_S); ok {
            w.state = ns_left
			set_wall(pos + {1, 0, -1}, .N_S, w)
		}

		if w, ok := get_wall(pos + {-1, 0, 0}, .NW_SE); ok {
            w.state = ew_left
			set_wall(pos + {-1, 0, 0}, .NW_SE, w)
		}
		if w, ok := get_wall(pos + {1, 0, -1}, .NW_SE); ok {
			w.state = ew_right
			set_wall(pos + {1, 0, -1}, .NW_SE, w)
		}

		if w, ok := get_wall(pos + {-1, 0, -1}, .SW_NE); ok {
            w.state = ew_left
			set_wall(pos + {-1, 0, -1}, .SW_NE, w)
		}
		if w, ok := get_wall(pos + {1, 0, 0}, .SW_NE); ok {
			w.state = ew_right
			set_wall(pos + {1, 0, 0}, .SW_NE, w)
		}
	case .N_S:
		if w, ok := get_wall(pos + {0, 0, -1}, .N_S); ok {
            w.state = ns_left
			set_wall(pos + {0, 0, -1}, .N_S, w)
		}
		if w, ok := get_wall(pos + {0, 0, 1}, .N_S); ok {
            w.state = ns_right
			set_wall(pos + {0, 0, 1}, .N_S, w)
		}

		if w, ok := get_wall(pos + {0, 0, 0}, .E_W); ok {
            w.state = ew_right
			set_wall(pos + {0, 0, 0}, .E_W, w)
		}
		if w, ok := get_wall(pos + {-1, 0, 0}, .E_W); ok {
            w.state = ew_left
			set_wall(pos + {-1, 0, 0}, .E_W, w)
		}
		if w, ok := get_wall(pos + {0, 0, 1}, .E_W); ok {
            w.state = ew_right
			set_wall(pos + {0, 0, 1}, .E_W, w)
		}
		if w, ok := get_wall(pos + {-1, 0, 1}, .E_W); ok {
            w.state = ew_left
			set_wall(pos + {-1, 0, 1}, .E_W, w)
		}

		if w, ok := get_wall(pos + {-1, 0, 1}, .NW_SE); ok {
            w.state = ns_left
			set_wall(pos + {-1, 0, 1}, .NW_SE, w)
		}
		if w, ok := get_wall(pos + {0, 0, -1}, .NW_SE); ok {
            w.state = ns_right
			set_wall(pos + {0, 0, -1}, .NW_SE, w)
		}

		if w, ok := get_wall(pos + {-1, 0, -1}, .SW_NE); ok {
            w.state = ns_left
			set_wall(pos + {-1, 0, -1}, .SW_NE, w)
		}
		if w, ok := get_wall(pos + {0, 0, 1}, .SW_NE); ok {
            w.state = ns_right
			set_wall(pos + {0, 0, 1}, .SW_NE, w)
		}
	case .SW_NE:
		if w, ok := get_wall(pos + {-1, 0, -1}, .SW_NE); ok {
			w.state = diagonal_left
			set_wall(pos + {-1, 0, -1}, .SW_NE, w)
		}
		if w, ok := get_wall(pos + {1, 0, 1}, .SW_NE); ok {
			w.state = diagonal_right
			set_wall(pos + {1, 0, 1}, .SW_NE, w)
		}

		if w, ok := get_wall(pos + {0, 0, -1}, .NW_SE); ok {
			w.state = diagonal_left
			set_wall(pos + {0, 0, -1}, .NW_SE, w)
		}
		if w, ok := get_wall(pos + {-1, 0, 0}, .NW_SE); ok {
			w.state = diagonal_right
			set_wall(pos + {-1, 0, 0}, .NW_SE, w)
		}

		if w, ok := get_wall(pos + {0, 0, 1}, .NW_SE); ok {
			w.state = diagonal_right
			set_wall(pos + {0, 0, 1}, .NW_SE, w)
		}
		if w, ok := get_wall(pos + {1, 0, 0}, .NW_SE); ok {
			w.state = diagonal_left
			set_wall(pos + {1, 0, 0}, .NW_SE, w)
		}

		if w, ok := get_wall(pos + {0, 0, -1}, .N_S); ok {
			w.state = diagonal_left
			set_wall(pos + {0, 0, -1}, .N_S, w)
		}
		if w, ok := get_wall(pos + {1, 0, 1}, .N_S); ok {
			w.state = diagonal_right
			set_wall(pos + {1, 0, 1}, .N_S, w)
		}

		if w, ok := get_wall(pos + {1, 0, 1}, .E_W); ok {
			w.state = diagonal_left
			set_wall(pos + {1, 0, 1}, .E_W, w)
		}
		if w, ok := get_wall(pos + {-1, 0, 0}, .E_W); ok {
			w.state = diagonal_right
			set_wall(pos + {-1, 0, 0}, .E_W, w)
		}
	case .NW_SE:
		if w, ok := get_wall(pos + {-1, 0, 1}, .NW_SE); ok {
			w.state = diagonal_left
			set_wall(pos + {-1, 0, 1}, .NW_SE, w)
		}
		if w, ok := get_wall(pos + {1, 0, -1}, .NW_SE); ok {
			w.state = diagonal_right
			set_wall(pos + {1, 0, -1}, .NW_SE, w)
		}

		if w, ok := get_wall(pos + {-1, 0, 0}, .SW_NE); ok {
			w.state = diagonal_left
			set_wall(pos + {-1, 0, 0}, .SW_NE, w)
		}
		if w, ok := get_wall(pos + {0, 0, 1}, .SW_NE); ok {
			w.state = diagonal_right
			set_wall(pos + {0, 0, 1}, .SW_NE, w)
		}

		if w, ok := get_wall(pos + {1, 0, 0}, .SW_NE); ok {
			w.state = diagonal_right
			set_wall(pos + {1, 0, 0}, .SW_NE, w)
		}
		if w, ok := get_wall(pos + {0, 0, -1}, .SW_NE); ok {
			w.state = diagonal_left
			set_wall(pos + {0, 0, -1}, .SW_NE, w)
		}

		if w, ok := get_wall(pos + {1, 0, -1}, .N_S); ok {
			w.state = diagonal_left
			set_wall(pos + {1, 0, -1}, .N_S, w)
		}
		if w, ok := get_wall(pos + {0, 0, 1}, .N_S); ok {
			w.state = diagonal_right
			set_wall(pos + {0, 0, 1}, .N_S, w)
		}

		if w, ok := get_wall(pos + {-1, 0, 1}, .E_W); ok {
			w.state = diagonal_left
			set_wall(pos + {-1, 0, 1}, .E_W, w)
		}
		if w, ok := get_wall(pos + {1, 0, 0}, .E_W); ok {
			w.state = diagonal_right
			set_wall(pos + {1, 0, 0}, .E_W, w)
		}
	}
}
