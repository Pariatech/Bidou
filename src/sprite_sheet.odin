package main

Texture :: enum {
	Full_Mask,
	Grid_Mask,
	Terrain_Leveling_Mask,
	Grass,
	Gravel,
	Wood,
	Brick,
	Varg,
	Nyana,
	Light_Post_Base,
	Light_Post_Top,
	Wall_Top,
	Shovel_Base,
	Shovel_Top,
	Floor_Marker,
	Cursors_Wall_Tool_Base,
	Cursors_Wall_Tool_Top,
}

texture_paths :: [Texture]cstring {
	.Full_Mask              = "resources/textures/full-mask.png",
	.Grid_Mask              = "resources/textures/grid-mask.png",
	.Terrain_Leveling_Mask  = "resources/textures/leveling-mask.png",
	.Grass                  = "resources/textures/lawn-diffuse-512x512.png",
	.Gravel                 = "resources/textures/gravel-diffuse-512x512.png",
	.Brick                  = "resources/textures/brick.png",
	.Varg                   = "resources/textures/varg.png",
	.Nyana                  = "resources/textures/nyana.png",
	.Light_Post_Base        = "resources/textures/light-pole-base.png",
	.Light_Post_Top         = "resources/textures/light-pole-top.png",
	.Wall_Top               = "resources/textures/wall-top.png",
	.Shovel_Base            = "resources/textures/shovel-base.png",
	.Shovel_Top             = "resources/textures/shovel-top.png",
	.Floor_Marker           = "resources/textures/floors/floor-marker.png",
	.Wood                   = "resources/textures/floors/wood.png",
	.Cursors_Wall_Tool_Base = "resources/textures/cursors/wall-tool-base.png",
	.Cursors_Wall_Tool_Top  = "resources/textures/cursors/wall-tool-top.png",
}
