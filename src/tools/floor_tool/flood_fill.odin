package floor_tool

import "core:log"
import "core:math/linalg/glsl"

import "../../game"

Visited_Tile_Triangle :: struct {
	position: glsl.ivec3,
	side:     game.Tile_Triangle_Side,
}

flood_fill :: proc(
	position: glsl.ivec3,
	side: game.Tile_Triangle_Side,
	texture: game.Tile_Triangle_Texture,
	start: glsl.ivec3 = {0, 0, 0},
	end: glsl.ivec3 = {game.WORLD_WIDTH, 0, game.WORLD_DEPTH},
	ignore_texture_check: bool = false,
) {
	tile_triangle, ok := game.tile_triangle_get_tile_triangle(position, side)
	if !ok {return}
	original_texture := tile_triangle.texture
	if original_texture == texture {return}

	visited_queue: [dynamic]Visited_Tile_Triangle
	defer delete(visited_queue)

	visited := Visited_Tile_Triangle{position, side}

	set_texture(visited, texture)

	append(&visited_queue, visited)

	for len(visited_queue) > 0 {
		visited = pop(&visited_queue)
		from := visited
		switch visited.side {
		case .South:
			next_visited := visited
			next_visited.side = .East
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .West
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .North
			next_visited.position -= {0, 0, 1}
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		case .East:
			next_visited := visited
			next_visited.side = .North
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .South
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .West
			next_visited.position += {1, 0, 0}
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		case .North:
			next_visited := visited
			next_visited.side = .East
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .West
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .South
			next_visited.position += {0, 0, 1}
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		case .West:
			next_visited := visited
			next_visited.side = .South
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .North
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
			next_visited.side = .East
			next_visited.position -= {1, 0, 0}
			process_next_visited(
				from,
				next_visited,
				original_texture,
				texture,
				&visited_queue,
				start,
				end,
				ignore_texture_check,
			)
		}
	}
}

process_next_visited :: proc(
	from: Visited_Tile_Triangle,
	to: Visited_Tile_Triangle,
	original_texture: game.Tile_Triangle_Texture,
	texture: game.Tile_Triangle_Texture,
	visited_queue: ^[dynamic]Visited_Tile_Triangle,
	start: glsl.ivec3,
	end: glsl.ivec3,
	ignore_texture_check: bool,
) {
	if ignore_texture_check {
		for key in previous_floor_tiles {
			if key.pos == to.position && key.side == to.side {
				return
			}
		}
	}
	if can_texture(
		   from,
		   to,
		   original_texture,
		   start,
		   end,
		   ignore_texture_check,
	   ) {
		set_texture(to, texture)
		append(visited_queue, to)
	}
}

set_texture :: proc(
	using visited: Visited_Tile_Triangle,
	texture: game.Tile_Triangle_Texture,
) {
	mask_texture: game.Tile_Triangle_Mask = .Grid_Mask
	if texture == .Floor_Marker {
		mask_texture = .Full_Mask
	}
	set_tile_triangle(
		position,
		side,
		game.Tile_Triangle{texture = texture, mask_texture = mask_texture},
	)
}

can_texture :: proc(
	from: Visited_Tile_Triangle,
	to: Visited_Tile_Triangle,
	texture: game.Tile_Triangle_Texture,
	start: glsl.ivec3,
	end: glsl.ivec3,
	ignore_texture_check: bool,
) -> bool {
	if to.position.x < 0 ||
	   to.position.z < 0 ||
	   to.position.x >= game.WORLD_WIDTH ||
	   to.position.z >= game.WORLD_DEPTH ||
	   (to.position.y > 0 && !game.is_tile_flat(to.position.xz)) ||
	   to.position.x < start.x ||
	   to.position.z < start.z ||
	   to.position.x > end.x ||
	   to.position.z > end.z {
		return false
	}

	switch from.side {
	case .South:
		switch to.side {
		case .South:
		case .East:
			_, ok := game.get_north_west_south_east_wall(to.position)
			if ok {
				return false
			}
		case .North:
			_, ok := game.get_east_west_wall(from.position)
			if ok {
				return false
			}
		case .West:
			_, ok := game.get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		}
	case .East:
		switch to.side {
		case .South:
			_, ok := game.get_north_west_south_east_wall(to.position)
			if ok {
				return false
			}
		case .East:
		case .North:
			_, ok := game.get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		case .West:
			_, ok := game.get_north_south_wall(to.position)
			if ok {
				return false
			}
		}
	case .North:
		switch to.side {
		case .South:
			_, ok := game.get_east_west_wall(to.position)
			if ok {
				return false
			}
		case .East:
			_, ok := game.get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		case .North:
		case .West:
			_, ok := game.get_north_west_south_east_wall(from.position)
			if ok {
				return false
			}
		}
	case .West:
		switch to.side {
		case .South:
			_, ok := game.get_south_west_north_east_wall(to.position)
			if ok {
				return false
			}
		case .East:
			_, ok := game.get_north_south_wall(from.position)
			if ok {
				return false
			}
		case .North:
			_, ok := game.get_north_west_south_east_wall(to.position)
			if ok {
				return false
			}
		case .West:
		}
	}

	tile_triangle, ok := game.tile_triangle_get_tile_triangle(to.position, to.side)

	return !ok || ignore_texture_check || tile_triangle.texture == texture
	// return !ok || (!ignore_texture_check && tile_triangle.texture == texture)
}
