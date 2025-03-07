package game

import "core:math/linalg/glsl"
import "core:testing"

Lot :: struct {
	name:  string,
	start: glsl.ivec2,
	end:   glsl.ivec2,
}

Lots :: struct {
	active_lot: Lot,
	data:       [dynamic]Lot,
}

AVAILABLE_LOT :: Lot {
	name = "Available lot",
}

WORLD_LOT :: Lot {
	name = "World lot",
}

lots :: proc() -> ^Lots {
	return &game().lots
}

lots_init :: proc() {
	lot := Lot {
		name = "My Store",
		start = {2, 2},
		end = {5, 6},
	}
	lots_add_lot(lot)
	lots_set_active_lot(lot)
}

lots_deinit :: proc() {
	delete(lots().data)
}

lots_get_lot_by_pos :: proc(pos: glsl.ivec2) -> (Lot, bool) {
	chunk_pos := pos / {CHUNK_WIDTH, CHUNK_DEPTH}
	for lot in lots().data {
		if lot.start.x <= chunk_pos.x &&
		   lot.start.y <= chunk_pos.y &&
		   chunk_pos.x < lot.end.x &&
		   chunk_pos.y < lot.end.y {
			return lot, true
		}
	}

	return {}, false
}

lots_can_add_lot :: proc(lot: Lot) -> bool {
	return can_add_lot(normalize_lot(lot))
}

lots_add_lot :: proc(lot: Lot) -> bool {
	normalized_lot := normalize_lot(lot)

	if !can_add_lot(normalized_lot) {
		return false
	}

	append(&lots().data, normalized_lot)

	return true
}

lots_set_active_lot :: proc(lot: Lot) {
	lots().active_lot = lot
}

lots_inside_active_lot :: proc(pos: glsl.ivec2) -> bool {
	lot := lots().active_lot
	chunk_pos := pos / {CHUNK_WIDTH, CHUNK_DEPTH}

	return(
		lot.start.x <= chunk_pos.x &&
		lot.start.y <= chunk_pos.y &&
		chunk_pos.x < lot.end.x &&
		chunk_pos.y < lot.end.y \
	)
}

lots_active_lot_start_pos :: proc() -> glsl.ivec2 {
	lot := lots().active_lot
    return lot.start * {CHUNK_WIDTH, CHUNK_DEPTH}
}

lots_active_lot_end_pos :: proc() -> glsl.ivec2 {
	lot := lots().active_lot
    return lot.end * {CHUNK_WIDTH, CHUNK_DEPTH}
}

@(private = "file")
normalize_lot :: proc(lot: Lot) -> Lot {
	normalized_lot := lot
	normalized_lot.start = glsl.min(lot.start, lot.end)
	normalized_lot.end = glsl.max(lot.start, lot.end)
	return normalized_lot
}

@(private = "file")
can_add_lot :: proc(lot: Lot) -> bool {
	for existing_lot in lots().data {
		if lot.end.x <= existing_lot.start.x ||
		   lot.end.y <= existing_lot.start.y {
			continue
		}

		if lot.start.x >= existing_lot.end.x ||
		   lot.start.y >= existing_lot.end.y {
			continue
		}

		return false
	}

	return true

}

@(test)
lots_test :: proc(t: ^testing.T) {
	game := new(Game_Context)
	context.user_ptr = game
	defer {
		lots_deinit()
		free(game)
	}

	ok := lots_add_lot({name = "My Lot", start = {1, 2}, end = {5, 6}})
	testing.expect_value(t, ok, true)
	testing.expect(t, len(lots().data) > 0)
	{
		result, ok := lots_get_lot_by_pos({12, 18})
		testing.expect_value(t, ok, true)
		testing.expect_value(
			t,
			result,
			Lot{name = "My Lot", start = {1, 2}, end = {5, 6}},
		)
	}

	{
		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {1, 2}, end = {5, 6}},
			),
			false,
		)

		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {2, 3}, end = {4, 5}},
			),
			false,
		)

		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {0, 1}, end = {6, 7}},
			),
			false,
		)

		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {0, 1}, end = {4, 5}},
			),
			false,
		)

		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {6, 1}, end = {0, 5}},
			),
			false,
		)

		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {4, 1}, end = {6, 5}},
			),
			false,
		)

		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {4, 5}, end = {6, 7}},
			),
			false,
		)

		testing.expect_value(
			t,
			lots_can_add_lot(
				{name = "My Lot 2", start = {5, 6}, end = {6, 7}},
			),
			true,
		)
	}
}
