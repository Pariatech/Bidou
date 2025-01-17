package game

import "core:log"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/noise"

MIN_LIGHT :: 0.6

Terrain_Context :: struct {
	sun:             glsl.vec3,
	terrain_heights: [WORLD_WIDTH + 1][WORLD_DEPTH + 1]f32,
	terrain_lights:  [WORLD_WIDTH + 1][WORLD_DEPTH + 1]glsl.vec3,
}

init_terrain :: proc() {
	ctx := get_terrain_context()
	ctx.sun = {1, -2, 1}
	for x in 0 ..= WORLD_WIDTH {
		for z in 0 ..= WORLD_DEPTH {
			calculate_terrain_light(x, z)
		}
	}
}

calculate_terrain_light :: proc(x, z: int) {
	ctx := get_terrain_context()
	normal: glsl.vec3
	if x == 0 && z == 0 {
		triangles := [?][3]glsl.vec3 {
			 {
				{-0.5, ctx.terrain_heights[x][z], -0.5},
				{0.5, ctx.terrain_heights[x + 1][z], -0.5},
				{-0.5, ctx.terrain_heights[x][z + 1], 0.5},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == WORLD_WIDTH && z == WORLD_DEPTH {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == 0 && z == WORLD_DEPTH {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
				{1.0, ctx.terrain_heights[x + 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if z == 0 && x == WORLD_WIDTH {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z + 1], 1.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == 0 {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{1.0, ctx.terrain_heights[x + 1][z], 0.0},
				{0.0, ctx.terrain_heights[x][z + 1], 1.0},
			},
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
				{1.0, ctx.terrain_heights[x + 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if z == 0 {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{1.0, ctx.terrain_heights[x + 1][z], 0.0},
				{0.0, ctx.terrain_heights[x][z + 1], 1.0},
			},
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z + 1], 1.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if x == WORLD_WIDTH {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z + 1], 1.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
			},
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else if z == WORLD_DEPTH {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
			},
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
				{1.0, ctx.terrain_heights[x + 1][z], 0.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	} else {
		triangles := [?][3]glsl.vec3 {
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{1.0, ctx.terrain_heights[x + 1][z], 0.0},
				{0.0, ctx.terrain_heights[x][z + 1], 1.0},
			},
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z + 1], 1.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
			},
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
				{1.0, ctx.terrain_heights[x + 1][z], 0.0},
			},
			 {
				{0.0, ctx.terrain_heights[x][z], 0.0},
				{-1.0, ctx.terrain_heights[x - 1][z], 0.0},
				{0.0, ctx.terrain_heights[x][z - 1], -1.0},
			},
		}
		for tri in triangles {
			normal += triangle_normal(tri[0], tri[1], tri[2])
		}
	}

	normal = glsl.normalize(normal)
	light := clamp(glsl.dot(glsl.normalize(ctx.sun), normal), MIN_LIGHT, 1)
	// light :f32 = 1.0
	ctx.terrain_lights[x][z] = {light, light, light}
}

get_tile_height :: proc(x, z: int) -> f32 {
	ctx := get_terrain_context()
	x := math.clamp(x, 0, WORLD_WIDTH - 1)
	z := math.clamp(z, 0, WORLD_DEPTH - 1)
	total :=
		ctx.terrain_heights[x][z] +
		ctx.terrain_heights[x + 1][z] +
		ctx.terrain_heights[x][z + 1] +
		ctx.terrain_heights[x + 1][z + 1]
	return total / 4
}

is_tile_flat :: proc(xz: glsl.ivec2) -> bool {
	ctx := get_terrain_context()
	xz := glsl.clamp(
		xz,
		glsl.ivec2{0, 0},
		glsl.ivec2{WORLD_WIDTH - 1, WORLD_DEPTH - 1},
	)
	return(
		ctx.terrain_heights[xz.x][xz.y] == ctx.terrain_heights[xz.x + 1][xz.y] &&
		ctx.terrain_heights[xz.x][xz.y] == ctx.terrain_heights[xz.x][xz.y + 1] &&
		ctx.terrain_heights[xz.x][xz.y] == ctx.terrain_heights[xz.x + 1][xz.y + 1] \
	)
}

set_terrain_height :: proc(x, z: int, height: f32) {
	ctx := get_terrain_context()
	if ctx.terrain_heights[x][z] == height {return}
	log.info(x, z, height)
	ctx.terrain_heights[x][z] = height
}

get_terrain_height :: proc(pos: glsl.ivec2) -> f32 {
	ctx := get_terrain_context()
	return(
		ctx.terrain_heights[clamp(pos.x, 0, WORLD_WIDTH)][clamp(pos.y, 0, WORLD_DEPTH)] \
	)
}
