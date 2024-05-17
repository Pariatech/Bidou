package wall

import "core:fmt"
import "core:math/linalg"
import glsl "core:math/linalg/glsl"

import "../constants"
import "../camera"
import "../terrain"

Diagonal_Wall_Axis :: enum {
	South_West_North_East,
	North_West_South_East,
}

Diagonal_Wall_Mask :: enum {
	Full,
	Side,
	Left_Extension,
	Right_Extension,
	Cross,
}

DIAGONAL_WALL_TOP_CROSS_OFFSET :: 0.0002
DIAGONAL_WALL_TOP_OFFSET :: 0.0003

diagonal_wall_full_vertices := []Wall_Vertex {
	 {
		pos = {-0.5575, 0.0, 0.5575},
		light = {1, 1, 1},
		texcoords = {0, 1, 0, 0},
	},
	 {
		pos = {0.5575, 0.0, -0.5575},
		light = {1, 1, 1},
		texcoords = {1, 1, 0, 0},
	},
	 {
		pos = {0.5575, constants.WALL_HEIGHT, -0.5575},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.5575, constants.WALL_HEIGHT, 0.5575},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_right_extension_vertices := []Wall_Vertex {
	{pos = {-0.5, 0.0, 0.5}, light = {1, 1, 1}, texcoords = {0, 1, 0, 0}},
	 {
		pos = {0.5575, 0.0, -0.5575},
		light = {1, 1, 1},
		texcoords = {1, 1, 0, 0},
	},
	 {
		pos = {0.5575, constants.WALL_HEIGHT, -0.5575},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.5, constants.WALL_HEIGHT, 0.5},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_left_extension_vertices := []Wall_Vertex {
	 {
		pos = {-0.5575, 0.0, 0.5575},
		light = {1, 1, 1},
		texcoords = {0, 1, 0, 0},
	},
	{pos = {0.5, 0.0, -0.5}, light = {1, 1, 1}, texcoords = {1, 1, 0, 0}},
	 {
		pos = {0.5, constants.WALL_HEIGHT, -0.5},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.5575, constants.WALL_HEIGHT, 0.5575},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_side_vertices := []Wall_Vertex {
	{pos = {-0.5, 0.0, 0.5}, light = {1, 1, 1}, texcoords = {0, 1, 0, 0}},
	{pos = {0.5, 0.0, -0.5}, light = {1, 1, 1}, texcoords = {1, 1, 0, 0}},
	 {
		pos = {0.5, constants.WALL_HEIGHT, -0.5},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.5, constants.WALL_HEIGHT, 0.5},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_cross_vertices := []Wall_Vertex {
	{pos = {-0.5, 0.0, -0.385}, light = {1, 1, 1}, texcoords = {0, 1, 0, 0}},
	 {
		pos = {-0.385, 0.0, -0.5},
		light = {1, 1, 1},
		texcoords = {0.115, 1, 0, 0},
	},
	 {
		pos = {-0.385, constants.WALL_HEIGHT, -0.5},
		light = {1, 1, 1},
		texcoords = {0.115, 0, 0, 0},
	},
	 {
		pos = {-0.5, constants.WALL_HEIGHT, -0.385},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}


diagonal_wall_top_cross_vertices := []Wall_Vertex {
	 {
		pos = {-0.5, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_CROSS_OFFSET, -0.385},
		light = {1, 1, 1},
		texcoords = {1, 0.115, 0, 0},
	},
	 {
		pos = {-0.385, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_CROSS_OFFSET, -0.5},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {0.615, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_CROSS_OFFSET, 0.5},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
	 {
		pos = {0.5, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_CROSS_OFFSET, 0.615},
		light = {1, 1, 1},
		texcoords = {0, 0.115, 0, 0},
	},
}

diagonal_wall_top_full_vertices := []Wall_Vertex {
	 {
		pos = {-0.5575, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.5575},
		light = {1, 1, 1},
		texcoords = {0, 0.115, 0, 0},
	},
	 {
		pos = {0.5575, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.5575},
		light = {1, 1, 1},
		texcoords = {1, 0.115, 0, 0},
	},
	 {
		pos = {0.6725, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.4425},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.4425, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.6725},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_top_left_extension_vertices := []Wall_Vertex {
	 {
		pos = {-0.5575, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.5575},
		light = {1, 1, 1},
		texcoords = {0, 0.115, 0, 0},
	},
	 {
		pos = {0.5, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.5},
		light = {1, 1, 1},
		texcoords = {1, 0.115, 0, 0},
	},
	 {
		pos = {0.615, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.385},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.4425, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.6725},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_top_right_extension_vertices := []Wall_Vertex {
	 {
		pos = {-0.5, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.5},
		light = {1, 1, 1},
		texcoords = {0, 0.115, 0, 0},
	},
	 {
		pos = {0.5575, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.5575},
		light = {1, 1, 1},
		texcoords = {1, 0.115, 0, 0},
	},
	 {
		pos = {0.6725, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.4425},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.385, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.615},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_top_side_vertices := []Wall_Vertex {
	 {
		pos = {-0.5, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.5},
		light = {1, 1, 1},
		texcoords = {0, 0.115, 0, 0},
	},
	 {
		pos = {0.5, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.5},
		light = {1, 1, 1},
		texcoords = {1, 0.115, 0, 0},
	},
	 {
		pos = {0.615, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, -0.385},
		light = {1, 1, 1},
		texcoords = {1, 0, 0, 0},
	},
	 {
		pos = {-0.385, constants.WALL_HEIGHT + DIAGONAL_WALL_TOP_OFFSET, 0.615},
		light = {1, 1, 1},
		texcoords = {0, 0, 0, 0},
	},
}

diagonal_wall_indices := []Wall_Index{0, 1, 2, 0, 2, 3}

DIAGONAL_WALL_MASK_MAP ::
	[Diagonal_Wall_Axis][camera.Rotation][Wall_Type]Diagonal_Wall_Mask {
		.South_West_North_East =  {
			.South_West =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
			.South_East =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Left_Extension,
				.End_Left_Corner = .Right_Extension,
				.Right_Corner_End = .Side,
				.End_Right_Corner = .Side,
				.Left_Corner_Side = .Left_Extension,
				.Side_Left_Corner = .Right_Extension,
				.Right_Corner_Side = .Side,
				.Side_Right_Corner = .Side,
				.Left_Corner_Left_Corner = .Full,
				.Right_Corner_Right_Corner = .Side,
				.Left_Corner_Right_Corner = .Left_Extension,
				.Right_Corner_Left_Corner = .Right_Extension,
			},
			.North_East =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
			.North_West =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Side,
				.End_Left_Corner = .Side,
				.Right_Corner_End = .Right_Extension,
				.End_Right_Corner = .Left_Extension,
				.Left_Corner_Side = .Side,
				.Side_Left_Corner = .Side,
				.Right_Corner_Side = .Right_Extension,
				.Side_Right_Corner = .Left_Extension,
				.Left_Corner_Left_Corner = .Side,
				.Right_Corner_Right_Corner = .Full,
				.Left_Corner_Right_Corner = .Left_Extension,
				.Right_Corner_Left_Corner = .Right_Extension,
			},
		},
		.North_West_South_East =  {
			.South_West =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Left_Extension,
				.End_Left_Corner = .Right_Extension,
				.Right_Corner_End = .Side,
				.End_Right_Corner = .Side,
				.Left_Corner_Side = .Left_Extension,
				.Side_Left_Corner = .Right_Extension,
				.Right_Corner_Side = .Side,
				.Side_Right_Corner = .Side,
				.Left_Corner_Left_Corner = .Full,
				.Right_Corner_Right_Corner = .Side,
				.Left_Corner_Right_Corner = .Left_Extension,
				.Right_Corner_Left_Corner = .Right_Extension,
			},
			.South_East =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
			.North_East =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Side,
				.End_Left_Corner = .Side,
				.Right_Corner_End = .Right_Extension,
				.End_Right_Corner = .Left_Extension,
				.Left_Corner_Side = .Side,
				.Side_Left_Corner = .Side,
				.Right_Corner_Side = .Right_Extension,
				.Side_Right_Corner = .Left_Extension,
				.Left_Corner_Left_Corner = .Side,
				.Right_Corner_Right_Corner = .Full,
				.Left_Corner_Right_Corner = .Left_Extension,
				.Right_Corner_Left_Corner = .Right_Extension,
			},
			.North_West =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
		},
	}

DIAGONAL_WALL_TOP_MASK_MAP ::
	[Diagonal_Wall_Axis][camera.Rotation][Wall_Type]Diagonal_Wall_Mask {
		.South_West_North_East =  {
			.South_West =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
			.South_East =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Left_Extension,
				.End_Left_Corner = .Right_Extension,
				.Right_Corner_End = .Left_Extension,
				.End_Right_Corner = .Right_Extension,
				.Left_Corner_Side = .Left_Extension,
				.Side_Left_Corner = .Right_Extension,
				.Right_Corner_Side = .Left_Extension,
				.Side_Right_Corner = .Right_Extension,
				.Left_Corner_Left_Corner = .Full,
				.Right_Corner_Right_Corner = .Side,
				.Left_Corner_Right_Corner = .Left_Extension,
				.Right_Corner_Left_Corner = .Right_Extension,
			},
			.North_East =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
			.North_West =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Right_Extension,
				.End_Left_Corner = .Left_Extension,
				.Right_Corner_End = .Right_Extension,
				.End_Right_Corner = .Left_Extension,
				.Left_Corner_Side = .Right_Extension,
				.Side_Left_Corner = .Left_Extension,
				.Right_Corner_Side = .Right_Extension,
				.Side_Right_Corner = .Left_Extension,
				.Left_Corner_Left_Corner = .Side,
				.Right_Corner_Right_Corner = .Full,
				.Left_Corner_Right_Corner = .Left_Extension,
				.Right_Corner_Left_Corner = .Right_Extension,
			},
		},
		.North_West_South_East =  {
			.South_West =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Left_Extension,
				.End_Left_Corner = .Right_Extension,
				.Right_Corner_End = .Left_Extension,
				.End_Right_Corner = .Right_Extension,
				.Left_Corner_Side = .Left_Extension,
				.Side_Left_Corner = .Right_Extension,
				.Right_Corner_Side = .Left_Extension,
				.Side_Right_Corner = .Right_Extension,
				.Left_Corner_Left_Corner = .Full,
				.Right_Corner_Right_Corner = .Full,
				.Left_Corner_Right_Corner = .Full,
				.Right_Corner_Left_Corner = .Full,
			},
			.South_East =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
			.North_East =  {
				.End_End = .Side,
				.Side_Side = .Side,
				.End_Side = .Side,
				.Side_End = .Side,
				.Left_Corner_End = .Right_Extension,
				.End_Left_Corner = .Left_Extension,
				.Right_Corner_End = .Right_Extension,
				.End_Right_Corner = .Left_Extension,
				.Left_Corner_Side = .Right_Extension,
				.Side_Left_Corner = .Left_Extension,
				.Right_Corner_Side = .Right_Extension,
				.Side_Right_Corner = .Left_Extension,
				.Left_Corner_Left_Corner = .Full,
				.Right_Corner_Right_Corner = .Full,
				.Left_Corner_Right_Corner = .Full,
				.Right_Corner_Left_Corner = .Full,
			},
			.North_West =  {
				.End_End = .Cross,
				.Side_Side = .Cross,
				.End_Side = .Cross,
				.Side_End = .Cross,
				.Left_Corner_End = .Cross,
				.End_Left_Corner = .Cross,
				.Right_Corner_End = .Cross,
				.End_Right_Corner = .Cross,
				.Left_Corner_Side = .Cross,
				.Side_Left_Corner = .Cross,
				.Right_Corner_Side = .Cross,
				.Side_Right_Corner = .Cross,
				.Left_Corner_Left_Corner = .Cross,
				.Right_Corner_Right_Corner = .Cross,
				.Left_Corner_Right_Corner = .Cross,
				.Right_Corner_Left_Corner = .Cross,
			},
		},
	}

DIAGONAL_WALL_ROTATION_MAP ::
	[Diagonal_Wall_Axis][camera.Rotation]Diagonal_Wall_Axis {
		.South_West_North_East =  {
			.South_West = .South_West_North_East,
			.South_East = .North_West_South_East,
			.North_East = .South_West_North_East,
			.North_West = .North_West_South_East,
		},
		.North_West_South_East =  {
			.South_West = .North_West_South_East,
			.South_East = .South_West_North_East,
			.North_East = .North_West_South_East,
			.North_West = .South_West_North_East,
		},
	}

DIAGONAL_WALL_DRAW_MAP ::
	[Diagonal_Wall_Axis][Wall_Type][camera.Rotation]bool {
		.South_West_North_East =  {
			.End_End =  {
				.South_West = true,
				.South_East = true,
				.North_East = true,
				.North_West = true,
			},
			.Side_Side =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.End_Side =  {
				.South_West = true,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Side_End =  {
				.South_West = false,
				.South_East = true,
				.North_East = true,
				.North_West = true,
			},
			.Left_Corner_End =  {
				.South_West = false,
				.South_East = true,
				.North_East = true,
				.North_West = true,
			},
			.End_Left_Corner =  {
				.South_West = true,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Right_Corner_End =  {
				.South_West = false,
				.South_East = true,
				.North_East = true,
				.North_West = true,
			},
			.End_Right_Corner =  {
				.South_West = true,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Left_Corner_Side =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Side_Left_Corner =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Right_Corner_Side =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Side_Right_Corner =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Left_Corner_Left_Corner =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Right_Corner_Right_Corner =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Left_Corner_Right_Corner =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
			.Right_Corner_Left_Corner =  {
				.South_West = false,
				.South_East = true,
				.North_East = false,
				.North_West = true,
			},
		},
		.North_West_South_East =  {
			.End_End =  {
				.South_West = true,
				.South_East = true,
				.North_East = true,
				.North_West = true,
			},
			.Side_Side =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.End_Side =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = true,
			},
			.Side_End =  {
				.South_West = true,
				.South_East = true,
				.North_East = true,
				.North_West = false,
			},
			.Left_Corner_End =  {
				.South_West = true,
				.South_East = true,
				.North_East = true,
				.North_West = false,
			},
			.End_Left_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = true,
			},
			.Right_Corner_End =  {
				.South_West = true,
				.South_East = true,
				.North_East = true,
				.North_West = false,
			},
			.End_Right_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = true,
			},
			.Left_Corner_Side =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.Side_Left_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.Right_Corner_Side =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.Side_Right_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.Left_Corner_Left_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.Right_Corner_Right_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.Left_Corner_Right_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
			.Right_Corner_Left_Corner =  {
				.South_West = true,
				.South_East = false,
				.North_East = true,
				.North_West = false,
			},
		},
	}

DIAGONAL_WALL_SIDE_MAP :: [Diagonal_Wall_Axis][camera.Rotation]Wall_Side {
		.South_West_North_East =  {
			.South_West = .Outside,
			.South_East = .Inside,
			.North_East = .Inside,
			.North_West = .Outside,
		},
		.North_West_South_East =  {
			.South_West = .Outside,
			.South_East = .Outside,
			.North_East = .Inside,
			.North_West = .Inside,
		},
	}


DIAGONAL_WALL_TRANSFORM_MAP :: [camera.Rotation]glsl.mat4 {
		.South_West = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
		.South_East = {0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1},
		.North_East = {-1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1, 0, 0, 0, 0, 1},
		.North_West = {0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 0, 1},
	}


draw_diagonal_wall :: proc(
	pos: glsl.ivec3,
	wall: Wall,
	axis: Diagonal_Wall_Axis,
	vertex_buffer: ^[dynamic]Wall_Vertex,
	index_buffer: ^[dynamic]Wall_Index,
) {
	mask_map := DIAGONAL_WALL_MASK_MAP
	rotation_map := DIAGONAL_WALL_ROTATION_MAP
	draw_map := DIAGONAL_WALL_DRAW_MAP
	top_mask_map := DIAGONAL_WALL_TOP_MASK_MAP
	side_map := DIAGONAL_WALL_SIDE_MAP
	transform_map := DIAGONAL_WALL_TRANSFORM_MAP

	side := side_map[axis][camera.rotation]
	rotation := rotation_map[axis][camera.rotation]
	texture := wall.textures[side]
	mask := mask_map[axis][camera.rotation][wall.type]
	top_mask := top_mask_map[axis][camera.rotation][wall.type]
	draw := draw_map[axis][wall.type][camera.rotation]
	position := glsl.vec3 {
		f32(pos.x),
		f32(pos.y) * constants.WALL_HEIGHT + terrain.terrain_heights[pos.x][pos.z],
		f32(pos.z),
	}
	transform := glsl.mat4Translate(position)
	transform *= transform_map[camera.rotation]

	if draw {
		wall_vertices: []Wall_Vertex
		switch mask {
		case .Full:
			wall_vertices = diagonal_wall_full_vertices
		case .Side:
			wall_vertices = diagonal_wall_side_vertices
		case .Left_Extension:
			wall_vertices = diagonal_wall_left_extension_vertices
		case .Right_Extension:
			wall_vertices = diagonal_wall_right_extension_vertices
		case .Cross:
			wall_vertices = diagonal_wall_cross_vertices
		}

		draw_wall_mesh(
			wall_vertices,
			diagonal_wall_indices,
			transform,
			texture,
			wall.mask,
			vertex_buffer,
			index_buffer,
		)
	}

	top_vertices: []Wall_Vertex
	switch top_mask {
	case .Full:
		top_vertices = diagonal_wall_top_full_vertices
	case .Side:
		top_vertices = diagonal_wall_top_side_vertices
	case .Left_Extension:
		top_vertices = diagonal_wall_top_left_extension_vertices
	case .Right_Extension:
		top_vertices = diagonal_wall_top_right_extension_vertices
	case .Cross:
		top_vertices = diagonal_wall_top_cross_vertices
	}

	draw_wall_mesh(
		top_vertices,
		diagonal_wall_indices,
		transform,
		.Wall_Top,
		wall.mask,
		vertex_buffer,
		index_buffer,
	)
}