package main

import "core:fmt"
import m "core:math/linalg/glsl"
import "core:math/noise"

terrain_heights: [WORLD_WIDTH + 1][WORLD_DEPTH + 1]f32
terrain_lights: [WORLD_WIDTH + 1][WORLD_DEPTH + 1]m.vec3

// terrain_quad_tree_nodes: [dynamic]Terrain_Quad_Tree_Node
//
// Terrain_Quad_Tree_Node_Indices :: struct {
// 	children: [4]int,
// }
//
// Terrain_Quad_Tree_Node_Tile_Triangles :: struct {
// 	children: [4]Tile_Triangle,
// }
//
// Terrain_Quad_Tree_Node :: union {
// 	Terrain_Quad_Tree_Node_Indices,
// 	Terrain_Quad_Tree_Node_Tile_Triangles,
// }

init_terrain :: proc() {
	// append(
	// 	&terrain_quad_tree_nodes,
	// 	Terrain_Quad_Tree_Node_Tile_Triangles {
	// 		children =  {
	// 			{texture = .Grass, mask_texture = .Grid_Mask},
	// 			{texture = .Grass, mask_texture = .Grid_Mask},
	// 			{texture = .Grass, mask_texture = .Grid_Mask},
	// 			{texture = .Grass, mask_texture = .Grid_Mask},
	// 		},
	// 	},
	// )

	// set_terrain_tile_triangle(
	// 	2,
	// 	2,
	// 	{texture = .Gravel, mask_texture = .Grid_Mask},
	// 	.South,
	// )

	// set_terrain_tile_triangle(
	// 	0,
	// 	0,
	// 	{texture = .Grass, mask_texture = .Grid_Mask},
	// 	.South,
	// )

	set_terrain_height(3, 3, .5)
	// set_terrain_height(1, 1, 0)

	// SEED :: 694201337
	// for x in 0 ..= WORLD_WIDTH {
	// 	for z in 0 ..= WORLD_DEPTH {
	// 		terrain_heights[x][z] =
	// 			noise.noise_2d(SEED, {f64(x), f64(z)}) / 2.0
	// 	}
	// }

	for x in 0 ..= WORLD_WIDTH {
		for z in 0 ..= WORLD_DEPTH {
			calculate_terrain_light(x, z)
		}
	}
}

calculate_terrain_light :: proc(x, z: int) {
	normal: m.vec3
	if x == 0 && z == 0 {
		triangles := [?][3]m.vec3 {
			 {
				{-0.5, terrain_heights[x][z], -0.5},
				{0.5, terrain_heights[x + 1][z], -0.5},
				{-0.5, terrain_heights[x][z + 1], 0.5},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == WORLD_WIDTH && z == WORLD_DEPTH {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == 0 && z == WORLD_DEPTH {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
				{1.0, terrain_heights[x + 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if z == 0 && x == WORLD_WIDTH {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z + 1], 1.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == 0 {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{1.0, terrain_heights[x + 1][z], 0.0},
				{0.0, terrain_heights[x][z + 1], 1.0},
			},
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
				{1.0, terrain_heights[x + 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if z == 0 {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{1.0, terrain_heights[x + 1][z], 0.0},
				{0.0, terrain_heights[x][z + 1], 1.0},
			},
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z + 1], 1.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == WORLD_WIDTH {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z + 1], 1.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
			},
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if z == WORLD_DEPTH {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
			},
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
				{1.0, terrain_heights[x + 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else {
		triangles := [?][3]m.vec3 {
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{1.0, terrain_heights[x + 1][z], 0.0},
				{0.0, terrain_heights[x][z + 1], 1.0},
			},
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z + 1], 1.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
			},
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
				{1.0, terrain_heights[x + 1][z], 0.0},
			},
			 {
				{0.0, terrain_heights[x][z], 0.0},
				{-1.0, terrain_heights[x - 1][z], 0.0},
				{0.0, terrain_heights[x][z - 1], -1.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	}

	normal = m.normalize(normal)
	light := m.dot(m.normalize(sun), normal)
	// light :f32 = 1.0
	terrain_lights[x][z] = {light, light, light}
}

get_terrain_tile_triangle_lights :: proc(
	side: Tile_Triangle_Side,
	x, z, w: int,
) -> (
	lights: [3]m.vec3,
) {
	lights = {{1, 1, 1}, {1, 1, 1}, {1, 1, 1}}

	tile_lights := [4]m.vec3 {
		terrain_lights[x][z],
		terrain_lights[x + w][z],
		terrain_lights[x + w][z + w],
		terrain_lights[x][z + w],
	}

	lights[2] = {0, 0, 0}
	for light in tile_lights {
		lights[2] += light
	}
	lights[2] /= 4
	switch side {
	case .South:
		lights[0] = tile_lights[0]
		lights[1] = tile_lights[1]
	case .East:
		lights[0] = tile_lights[1]
		lights[1] = tile_lights[2]
	case .North:
		lights[0] = tile_lights[2]
		lights[1] = tile_lights[3]
	case .West:
		lights[0] = tile_lights[3]
		lights[1] = tile_lights[0]
	}

	return
}

get_terrain_tile_triangle_heights :: proc(
	side: Tile_Triangle_Side,
	x, z, w: int,
) -> (
	heights: [3]f32,
) {
	heights = {0, 0, 0}

	tile_heights := [4]f32 {
		terrain_heights[x][z],
		terrain_heights[x + w][z],
		terrain_heights[x + w][z + w],
		terrain_heights[x][z + w],
	}

	heights[2] = 0
	lowest := min(
		tile_heights[0],
		tile_heights[1],
		tile_heights[2],
		tile_heights[3],
	)
	highest := max(
		tile_heights[0],
		tile_heights[1],
		tile_heights[2],
		tile_heights[3],
	)
	heights[2] = (lowest + highest) / 2

	switch side {
	case .South:
		heights[0] = tile_heights[0]
		heights[1] = tile_heights[1]
	case .East:
		heights[0] = tile_heights[1]
		heights[1] = tile_heights[2]
	case .North:
		heights[0] = tile_heights[2]
		heights[1] = tile_heights[3]
	case .West:
		heights[0] = tile_heights[3]
		heights[1] = tile_heights[0]
	}

	return
}

get_tile_height :: proc(x, z: int) -> f32 {
	total :=
		terrain_heights[x][z] +
		terrain_heights[x + 1][z] +
		terrain_heights[x][z + 1] +
		terrain_heights[x + 1][z + 1]
	return total / 4
}

set_terrain_height :: proc(x, z: int, height: f32) {
	if terrain_heights[x][z] == height {return}
	terrain_heights[x][z] = height

	if x > 0 && z > 0 {
		tile_quadtrees_set_height({i32(x - 1), 0, i32(z - 1)}, height)
	}
	if x > 0 && z < WORLD_DEPTH {
		tile_quadtrees_set_height({i32(x - 1), 0, i32(z)}, height)
	}

	if x < WORLD_WIDTH && z > 0 {
		tile_quadtrees_set_height({i32(x), 0, i32(z - 1)}, height)
	}

	if x < WORLD_WIDTH && z < WORLD_DEPTH {
		tile_quadtrees_set_height({i32(x), 0, i32(z)}, height)
	}
}
