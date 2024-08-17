package wall

import "core:fmt"
import "core:math"
import "core:math/linalg"
import glsl "core:math/linalg/glsl"

import "../camera"
import "../constants"
import "../game"
import "../terrain"

Diagonal_Wall_Mask :: enum {
	Full,
	Side,
	Left_Extension,
	Right_Extension,
	Cross,
}

DIAGONAL_WALL_TOP_CROSS_OFFSET :: -0.0002
DIAGONAL_WALL_TOP_OFFSET :: 0.0003

DIAGONAL_WALL_MASK_MODEL_NAME_MAP :: [Wall_Type][Wall_Side]string {
	.Start =  {
		.Outside = "Wall_Diagonal.Up.Start.Outside",
		.Inside = "Wall_Diagonal.Up.Start.Inside",
	},
	.End =  {
		.Outside = "Wall_Diagonal.Up.End.Outside",
		.Inside = "Wall_Diagonal.Up.End.Inside",
	},
	.Extended_Left =  {
		.Outside = "Wall_Diagonal.Up.Extended_Left.Outside",
		.Inside = "Wall_Diagonal.Up.Extended_Left.Inside",
	},
	.Extended_Right =  {
		.Outside = "Wall_Diagonal.Up.Extended_Right.Outside",
		.Inside = "Wall_Diagonal.Up.Extended_Right.Inside",
	},
	.Full =  {
		.Outside = "Wall_Diagonal.Up.Full.Outside",
		.Inside = "Wall_Diagonal.Up.Full.Inside",
	},
	.Side =  {
		.Outside = "Wall_Diagonal.Up.Side.Outside",
		.Inside = "Wall_Diagonal.Up.Side.Inside",
	},
	.Extended_Start =  {
		.Outside = "Wall_Diagonal.Up.Extended_Start.Outside",
		.Inside = "Wall_Diagonal.Up.Extended_Start.Inside",
	},
	.Extended_End =  {
		.Outside = "Wall_Diagonal.Up.Extended_End.Outside",
		.Inside = "Wall_Diagonal.Up.Extended_End.Inside",
	},
	.Extended =  {
		.Outside = "Wall_Diagonal.Up.Extended.Outside",
		.Inside = "Wall_Diagonal.Up.Extended.Inside",
	},
}

DIAGONAL_WALL_TYPE_TOP_MODEL_NAME_MAP :: [Wall_Type]string {
	.Start          = "Wall_Diagonal.Up.Top.Extended_Left",
	.End            = "Wall_Diagonal.Up.Top.Extended_Right",
	.Extended_Left  = "Wall_Diagonal.Up.Top.Extended_Left",
	.Extended_Right = "Wall_Diagonal.Up.Top.Extended_Right",
	.Full           = "Wall_Diagonal.Up.Top.Full",
	.Side           = "Wall_Diagonal.Up.Top.Side",
	.Extended_Start = "Wall_Diagonal.Up.Top.Extended_Left",
	.Extended_End   = "Wall_Diagonal.Up.Top.Extended_Right",
	.Extended       = "Wall_Diagonal.Up.Top.Full",
}

DIAGONAL_WALL_ROTATION_MAP :: #partial [Wall_Axis][camera.Rotation]Wall_Axis {
	.SW_NE =  {
		.South_West = .SW_NE,
		.South_East = .NW_SE,
		.North_East = .SW_NE,
		.North_West = .NW_SE,
	},
	.NW_SE =  {
		.South_West = .NW_SE,
		.South_East = .SW_NE,
		.North_East = .NW_SE,
		.North_West = .SW_NE,
	},
}

DIAGONAL_WALL_TRANSFORM_MAP :: [camera.Rotation]glsl.mat4 {
	.South_West = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
	.South_East = {0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1},
	.North_East = {-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1},
	.North_West = {0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 0, 1},
}


draw_diagonal_wall :: proc(
    using game: ^game.Game_Context,
	pos: glsl.ivec3,
	wall: Wall,
	axis: Wall_Axis,
	vertex_buffer: ^[dynamic]Wall_Vertex,
	index_buffer: ^[dynamic]Wall_Index,
) {
	rotation_map := DIAGONAL_WALL_ROTATION_MAP
	transform_map := DIAGONAL_WALL_TRANSFORM_MAP

	rotation := rotation_map[axis][camera.rotation]
	// texture := wall.textures[side]
	position := glsl.vec3 {
		f32(pos.x),
		f32(pos.y) * constants.WALL_HEIGHT +
		terrain.terrain_heights[pos.x][pos.z],
		f32(pos.z),
	}
	transform := glsl.mat4Translate(position)
	if axis == .SW_NE {
		transform *= glsl.mat4Rotate({0, 1, 0}, 0.5 * math.PI)
	}

	light := glsl.vec3{0.95, 0.95, 0.95}

	for texture, side in wall.textures {
		model_name_map := DIAGONAL_WALL_MASK_MODEL_NAME_MAP
		model_name := model_name_map[wall.type][side]
		model := models.models[model_name]
		vertices := model.vertices[:]
		indices := model.indices[:]
		draw_wall_mesh(
			vertices,
			indices,
			transform,
			texture,
			wall.mask,
			light,
			vertex_buffer,
			index_buffer,
		)
	}

	model_name_map := DIAGONAL_WALL_TYPE_TOP_MODEL_NAME_MAP
	model_name := model_name_map[wall.type]
	model := models.models[model_name]
	vertices := model.vertices[:]
	indices := model.indices[:]
	draw_wall_mesh(
		vertices,
		indices,
		transform,
		.Wall_Top,
		.Full_Mask,
		light,
		vertex_buffer,
		index_buffer,
	)
}
