package billboard

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import gl "vendor:OpenGL"
import "vendor:cgltf"
import stbi "vendor:stb/image"

import "../game"
import "../renderer"

BILLBOARD_VERTEX_SHADER_PATH :: "resources/shaders/billboard.vert"
BILLBOARD_FRAGMENT_SHADER_PATH :: "resources/shaders/billboard.frag"
BILLBOARD_MODEL_PATH :: "resources/models/billboard.glb"
FOUR_TILES_BILLBOARD_MODEL_PATH :: "resources/models/4tiles-billboard.glb"
BILLBOARD_TEXTURE_WIDTH :: 128
BILLBOARD_TEXTURE_HEIGHT :: 256
FOUR_TILES_BILLBOARD_TEXTURE_WIDTH :: 512
FOUR_TILES_BILLBOARD_TEXTURE_HEIGHT :: 1024

billboard_shader_program: u32
billboard_uniform_object: Billboard_Uniform_Object
billboard_ubo: u32
billboard_1x1_draw_context: Billboard_Draw_Context
billboard_2x2_draw_context: Billboard_Draw_Context
chunks_1x1: [game.CHUNK_HEIGHT][game.WORLD_CHUNK_WIDTH][game.WORLD_CHUNK_DEPTH]Billboard_Chunk(
	Billboard_1x1,
)
chunks_2x2: [game.CHUNK_HEIGHT][game.WORLD_CHUNK_WIDTH][game.WORLD_CHUNK_DEPTH]Billboard_Chunk(
	Billboard_2x2,
)

Billboard_Chunk :: struct($T: typeid) {
	instances:   map[Key]T,
	vao, ibo:    u32,
	dirty:       bool,
	initialized: bool,
}

Billboard_Type :: enum {
	Door,
	Window_E_W,
	Window_N_S,
	Cursor,
	Chair,
	Table,
	Object,
}

Key :: struct {
	pos:  glsl.vec3,
	type: Billboard_Type,
}

Billboard_Draw_Context :: struct {
	indices:                 [6]u8,
	vertices:                [4]Billboard_Vertex,
	vbo, ebo:                u32,
	texture_array:           u32,
	depth_map_texture_array: u32,
}

Billboard_Instance :: struct {
	position:  glsl.vec3,
	light:     glsl.vec3,
	texture:   f32,
	depth_map: f32,
}

Billboard_1x1 :: struct {
	light:     glsl.vec3,
	texture:   Texture_1x1,
	depth_map: Texture_1x1,
}

Billboard_2x2 :: struct {
	light:     glsl.vec3,
	texture:   Texture_2x2,
	depth_map: Texture_2x2,
}

Billboard_Vertex :: struct {
	pos:       glsl.vec3,
	texcoords: glsl.vec2,
}

Billboard_Uniform_Object :: struct {
	proj, view: glsl.mat4,
}

Texture_1x1 :: enum u8 {
	// Chair_Wood_SW,
	// Chair_Wood_SE,
	// Chair_Wood_NE,
	// Chair_Wood_NW,
	// Table6_001_Wood_SW,
	// Table6_001_Wood_SE,
	// Table6_001_Wood_NE,
	// Table6_001_Wood_NW,
	// Table6_002_Wood_SW,
	// Table6_002_Wood_SE,
	// Table6_002_Wood_NE,
	// Table6_002_Wood_NW,
	// Letter_A_SW,
	// Letter_A_SE,
	// Letter_A_NE,
	// Letter_A_NW,
	// Letter_G_SW,
	// Letter_G_SE,
	// Letter_G_NE,
	// Letter_G_NW,
	// Letter_D_SW,
	// Letter_D_SE,
	// Letter_D_NE,
	// Letter_D_NW,
	// Letter_E_SW,
	// Letter_E_SE,
	// Letter_E_NE,
	// Letter_E_NW,
	Door_Wood_SW,
	Door_Wood_SE,
	Door_Wood_NE,
	Door_Wood_NW,
	Door_Dark_Wood_SW,
	Door_Dark_Wood_SE,
	Door_Dark_Wood_NE,
	Door_Dark_Wood_NW,
	Window_Wood_SW,
	Window_Wood_SE,
	Window_Wood_NE,
	Window_Wood_NW,
	Window_Dark_Wood_SW,
	Window_Dark_Wood_SE,
	Window_Dark_Wood_NE,
	Window_Dark_Wood_NW,
	Shovel_1_SW,
	Shovel_2_SW,
	Shovel_3_SW,
	Shovel_4_SW,
	Shovel_5_SW,
	Shovel_6_SW,
	Shovel_7_SW,
	Shovel_8_SW,
	Shovel_9_SW,
	Shovel_10_SW,
	Wall_Cursor,
}

BILLBOARD_CLOCKWISE_ROTATION_TABLE_1X1 :: [Texture_1x1]Texture_1x1 {
	// .Chair_Wood_SW       = .Chair_Wood_SE,
	// .Chair_Wood_SE       = .Chair_Wood_NE,
	// .Chair_Wood_NE       = .Chair_Wood_NW,
	// .Chair_Wood_NW       = .Chair_Wood_SW,
	// .Table6_001_Wood_SW  = .Table6_001_Wood_SE,
	// .Table6_001_Wood_SE  = .Table6_001_Wood_NE,
	// .Table6_001_Wood_NE  = .Table6_001_Wood_NW,
	// .Table6_001_Wood_NW  = .Table6_001_Wood_SW,
	// .Table6_002_Wood_SW  = .Table6_002_Wood_SE,
	// .Table6_002_Wood_SE  = .Table6_002_Wood_NE,
	// .Table6_002_Wood_NE  = .Table6_002_Wood_NW,
	// .Table6_002_Wood_NW  = .Table6_002_Wood_SW,
	// .Letter_A_SW         = .Letter_A_SE,
	// .Letter_A_SE         = .Letter_A_NE,
	// .Letter_A_NE         = .Letter_A_NW,
	// .Letter_A_NW         = .Letter_A_SW,
	// .Letter_G_SW         = .Letter_G_SE,
	// .Letter_G_SE         = .Letter_G_NE,
	// .Letter_G_NE         = .Letter_G_NW,
	// .Letter_G_NW         = .Letter_G_SW,
	// .Letter_D_SW         = .Letter_D_SE,
	// .Letter_D_SE         = .Letter_D_NE,
	// .Letter_D_NE         = .Letter_D_NW,
	// .Letter_D_NW         = .Letter_D_SW,
	// .Letter_E_SW         = .Letter_E_SE,
	// .Letter_E_SE         = .Letter_E_NE,
	// .Letter_E_NE         = .Letter_E_NW,
	// .Letter_E_NW         = .Letter_E_SW,
	.Door_Wood_SW        = .Door_Wood_SE,
	.Door_Wood_SE        = .Door_Wood_NE,
	.Door_Wood_NE        = .Door_Wood_NW,
	.Door_Wood_NW        = .Door_Wood_SW,
	.Door_Dark_Wood_SW   = .Door_Dark_Wood_SE,
	.Door_Dark_Wood_SE   = .Door_Dark_Wood_NE,
	.Door_Dark_Wood_NE   = .Door_Dark_Wood_NW,
	.Door_Dark_Wood_NW   = .Door_Dark_Wood_SW,
	.Window_Wood_SW      = .Window_Wood_SE,
	.Window_Wood_SE      = .Window_Wood_NE,
	.Window_Wood_NE      = .Window_Wood_NW,
	.Window_Wood_NW      = .Window_Wood_SW,
	.Window_Dark_Wood_SW = .Window_Dark_Wood_SE,
	.Window_Dark_Wood_SE = .Window_Dark_Wood_NE,
	.Window_Dark_Wood_NE = .Window_Dark_Wood_NW,
	.Window_Dark_Wood_NW = .Window_Dark_Wood_SW,
	.Shovel_1_SW         = .Shovel_1_SW,
	.Shovel_2_SW         = .Shovel_2_SW,
	.Shovel_3_SW         = .Shovel_3_SW,
	.Shovel_4_SW         = .Shovel_4_SW,
	.Shovel_5_SW         = .Shovel_5_SW,
	.Shovel_6_SW         = .Shovel_6_SW,
	.Shovel_7_SW         = .Shovel_7_SW,
	.Shovel_8_SW         = .Shovel_8_SW,
	.Shovel_9_SW         = .Shovel_9_SW,
	.Shovel_10_SW        = .Shovel_10_SW,
	.Wall_Cursor         = .Wall_Cursor,
}

BILLBOARD_COUNTER_CLOCKWISE_ROTATION_TABLE_1X1 :: [Texture_1x1]Texture_1x1 {
	// .Chair_Wood_SW       = .Chair_Wood_NW,
	// .Chair_Wood_SE       = .Chair_Wood_SW,
	// .Chair_Wood_NE       = .Chair_Wood_SE,
	// .Chair_Wood_NW       = .Chair_Wood_NE,
	// .Table6_001_Wood_SW  = .Table6_001_Wood_NW,
	// .Table6_001_Wood_SE  = .Table6_001_Wood_SW,
	// .Table6_001_Wood_NE  = .Table6_001_Wood_SE,
	// .Table6_001_Wood_NW  = .Table6_001_Wood_NE,
	// .Table6_002_Wood_SE  = .Table6_002_Wood_SW,
	// .Table6_002_Wood_SW  = .Table6_002_Wood_NW,
	// .Table6_002_Wood_NE  = .Table6_002_Wood_SE,
	// .Table6_002_Wood_NW  = .Table6_002_Wood_NE,
	// .Letter_A_SW         = .Letter_A_NW,
	// .Letter_A_SE         = .Letter_A_SW,
	// .Letter_A_NE         = .Letter_A_SE,
	// .Letter_A_NW         = .Letter_A_NE,
	// .Letter_G_SW         = .Letter_G_NW,
	// .Letter_G_SE         = .Letter_G_SW,
	// .Letter_G_NE         = .Letter_G_SE,
	// .Letter_G_NW         = .Letter_G_NE,
	// .Letter_D_SW         = .Letter_D_NW,
	// .Letter_D_SE         = .Letter_D_SW,
	// .Letter_D_NE         = .Letter_D_SE,
	// .Letter_D_NW         = .Letter_D_NE,
	// .Letter_E_SW         = .Letter_E_NW,
	// .Letter_E_SE         = .Letter_E_SW,
	// .Letter_E_NE         = .Letter_E_SE,
	// .Letter_E_NW         = .Letter_E_NE,
	.Door_Wood_SW        = .Door_Wood_NW,
	.Door_Wood_SE        = .Door_Wood_SW,
	.Door_Wood_NE        = .Door_Wood_SE,
	.Door_Wood_NW        = .Door_Wood_NE,
	.Door_Dark_Wood_SW   = .Door_Dark_Wood_NW,
	.Door_Dark_Wood_SE   = .Door_Dark_Wood_SW,
	.Door_Dark_Wood_NE   = .Door_Dark_Wood_SE,
	.Door_Dark_Wood_NW   = .Door_Dark_Wood_NE,
	.Window_Wood_SW      = .Window_Wood_NW,
	.Window_Wood_SE      = .Window_Wood_SW,
	.Window_Wood_NE      = .Window_Wood_SE,
	.Window_Wood_NW      = .Window_Wood_NE,
	.Window_Dark_Wood_SW = .Window_Dark_Wood_NW,
	.Window_Dark_Wood_SE = .Window_Dark_Wood_SW,
	.Window_Dark_Wood_NE = .Window_Dark_Wood_SE,
	.Window_Dark_Wood_NW = .Window_Dark_Wood_NE,
	.Shovel_1_SW         = .Shovel_1_SW,
	.Shovel_2_SW         = .Shovel_2_SW,
	.Shovel_3_SW         = .Shovel_3_SW,
	.Shovel_4_SW         = .Shovel_4_SW,
	.Shovel_5_SW         = .Shovel_5_SW,
	.Shovel_6_SW         = .Shovel_6_SW,
	.Shovel_7_SW         = .Shovel_7_SW,
	.Shovel_8_SW         = .Shovel_8_SW,
	.Shovel_9_SW         = .Shovel_9_SW,
	.Shovel_10_SW        = .Shovel_10_SW,
	.Wall_Cursor         = .Wall_Cursor,
}

Texture_2x2 :: enum u8 {
	Table_8_Places_Wood_SW,
	Table_8_Places_Wood_SE,
	Table_8_Places_Wood_NE,
	Table_8_Places_Wood_NW,
}

BILLBOARD_CLOCKWISE_ROTATION_TABLE_2X2 :: [Texture_2x2]Texture_2x2 {
	.Table_8_Places_Wood_SW = .Table_8_Places_Wood_SE,
	.Table_8_Places_Wood_SE = .Table_8_Places_Wood_NE,
	.Table_8_Places_Wood_NE = .Table_8_Places_Wood_NW,
	.Table_8_Places_Wood_NW = .Table_8_Places_Wood_SW,
}

BILLBOARD_COUNTER_CLOCKWISE_ROTATION_TABLE_2X2 :: [Texture_2x2]Texture_2x2 {
	.Table_8_Places_Wood_SW = .Table_8_Places_Wood_NW,
	.Table_8_Places_Wood_SE = .Table_8_Places_Wood_SW,
	.Table_8_Places_Wood_NE = .Table_8_Places_Wood_SE,
	.Table_8_Places_Wood_NW = .Table_8_Places_Wood_NE,
}

BILLBOARD_TEXTURE_PATHS :: [Texture_1x1]cstring {
	// .Chair_Wood_SW       = "resources/textures/objects/Chairs/diffuse/Chair_0001.png",
	// .Chair_Wood_SE       = "resources/textures/objects/Chairs/diffuse/Chair_0002.png",
	// .Chair_Wood_NE       = "resources/textures/objects/Chairs/diffuse/Chair_0003.png",
	// .Chair_Wood_NW       = "resources/textures/objects/Chairs/diffuse/Chair_0004.png",
	// .Table6_001_Wood_SW  = "resources/textures/objects/Tables/diffuse/Table.6Places.001_0001.png",
	// .Table6_001_Wood_SE  = "resources/textures/objects/Tables/diffuse/Table.6Places.001_0002.png",
	// .Table6_001_Wood_NE  = "resources/textures/objects/Tables/diffuse/Table.6Places.001_0003.png",
	// .Table6_001_Wood_NW  = "resources/textures/objects/Tables/diffuse/Table.6Places.001_0004.png",
	// .Table6_002_Wood_SW  = "resources/textures/objects/Tables/diffuse/Table.6Places.002_0001.png",
	// .Table6_002_Wood_SE  = "resources/textures/objects/Tables/diffuse/Table.6Places.002_0002.png",
	// .Table6_002_Wood_NE  = "resources/textures/objects/Tables/diffuse/Table.6Places.002_0003.png",
	// .Table6_002_Wood_NW  = "resources/textures/objects/Tables/diffuse/Table.6Places.002_0004.png",
	// .Letter_A_SW         = "resources/textures/objects/Letters/diffuse/A_0001.png",
	// .Letter_A_SE         = "resources/textures/objects/Letters/diffuse/A_0002.png",
	// .Letter_A_NE         = "resources/textures/objects/Letters/diffuse/A_0003.png",
	// .Letter_A_NW         = "resources/textures/objects/Letters/diffuse/A_0004.png",
	// .Letter_G_SW         = "resources/textures/objects/Letters/diffuse/G_0001.png",
	// .Letter_G_SE         = "resources/textures/objects/Letters/diffuse/G_0002.png",
	// .Letter_G_NE         = "resources/textures/objects/Letters/diffuse/G_0003.png",
	// .Letter_G_NW         = "resources/textures/objects/Letters/diffuse/G_0004.png",
	// .Letter_D_SW         = "resources/textures/objects/Letters/diffuse/D_0001.png",
	// .Letter_D_SE         = "resources/textures/objects/Letters/diffuse/D_0002.png",
	// .Letter_D_NE         = "resources/textures/objects/Letters/diffuse/D_0003.png",
	// .Letter_D_NW         = "resources/textures/objects/Letters/diffuse/D_0004.png",
	// .Letter_E_SW         = "resources/textures/objects/Letters/diffuse/E_0001.png",
	// .Letter_E_SE         = "resources/textures/objects/Letters/diffuse/E_0002.png",
	// .Letter_E_NE         = "resources/textures/objects/Letters/diffuse/E_0003.png",
	// .Letter_E_NW         = "resources/textures/objects/Letters/diffuse/E_0004.png",
	.Door_Wood_SW        = "resources/textures/billboards/door-wood/sw-diffuse.png",
	.Door_Wood_SE        = "resources/textures/billboards/door-wood/se-diffuse.png",
	.Door_Wood_NE        = "resources/textures/billboards/door-wood/ne-diffuse.png",
	.Door_Wood_NW        = "resources/textures/billboards/door-wood/nw-diffuse.png",
	.Door_Dark_Wood_SW   = "resources/textures/billboards/door/dark_wood/sw-diffuse.png",
	.Door_Dark_Wood_SE   = "resources/textures/billboards/door/dark_wood/se-diffuse.png",
	.Door_Dark_Wood_NE   = "resources/textures/billboards/door/dark_wood/ne-diffuse.png",
	.Door_Dark_Wood_NW   = "resources/textures/billboards/door/dark_wood/nw-diffuse.png",
	.Window_Wood_SW      = "resources/textures/billboards/window-wood/sw-diffuse.png",
	.Window_Wood_SE      = "resources/textures/billboards/window-wood/se-diffuse.png",
	.Window_Wood_NE      = "resources/textures/billboards/window-wood/ne-diffuse.png",
	.Window_Wood_NW      = "resources/textures/billboards/window-wood/nw-diffuse.png",
	.Window_Dark_Wood_SW = "resources/textures/billboards/window/dark_wood/sw-diffuse.png",
	.Window_Dark_Wood_SE = "resources/textures/billboards/window/dark_wood/se-diffuse.png",
	.Window_Dark_Wood_NE = "resources/textures/billboards/window/dark_wood/ne-diffuse.png",
	.Window_Dark_Wood_NW = "resources/textures/billboards/window/dark_wood/nw-diffuse.png",
	.Shovel_1_SW         = "resources/textures/billboards/shovel/1-diffuse.png",
	.Shovel_2_SW         = "resources/textures/billboards/shovel/2-diffuse.png",
	.Shovel_3_SW         = "resources/textures/billboards/shovel/3-diffuse.png",
	.Shovel_4_SW         = "resources/textures/billboards/shovel/4-diffuse.png",
	.Shovel_5_SW         = "resources/textures/billboards/shovel/5-diffuse.png",
	.Shovel_6_SW         = "resources/textures/billboards/shovel/6-diffuse.png",
	.Shovel_7_SW         = "resources/textures/billboards/shovel/7-diffuse.png",
	.Shovel_8_SW         = "resources/textures/billboards/shovel/8-diffuse.png",
	.Shovel_9_SW         = "resources/textures/billboards/shovel/9-diffuse.png",
	.Shovel_10_SW        = "resources/textures/billboards/shovel/10-diffuse.png",
	.Wall_Cursor         = "resources/textures/billboards/wall-cursor/diffuse.png",
}

FOUR_TILES_BILLBOARD_TEXTURE_PATHS :: [Texture_2x2]cstring {
	.Table_8_Places_Wood_SW = "resources/textures/billboards/table-8places-wood/sw-diffuse.png",
	.Table_8_Places_Wood_SE = "resources/textures/billboards/table-8places-wood/se-diffuse.png",
	.Table_8_Places_Wood_NE = "resources/textures/billboards/table-8places-wood/ne-diffuse.png",
	.Table_8_Places_Wood_NW = "resources/textures/billboards/table-8places-wood/nw-diffuse.png",
}

BILLBOARD_DEPTH_MAP_TEXTURE_PATHS :: [Texture_1x1]cstring {
	// .Chair_Wood_SW       = "resources/textures/objects/Chairs/mist/Chair_0001.png",
	// .Chair_Wood_SE       = "resources/textures/objects/Chairs/mist/Chair_0002.png",
	// .Chair_Wood_NE       = "resources/textures/objects/Chairs/mist/Chair_0003.png",
	// .Chair_Wood_NW       = "resources/textures/objects/Chairs/mist/Chair_0004.png",
	// .Table6_001_Wood_SW  = "resources/textures/objects/Tables/mist/Table.6Places.001_0001.png",
	// .Table6_001_Wood_SE  = "resources/textures/objects/Tables/mist/Table.6Places.001_0002.png",
	// .Table6_001_Wood_NE  = "resources/textures/objects/Tables/mist/Table.6Places.001_0003.png",
	// .Table6_001_Wood_NW  = "resources/textures/objects/Tables/mist/Table.6Places.001_0004.png",
	// .Table6_002_Wood_SW  = "resources/textures/objects/Tables/mist/Table.6Places.002_0001.png",
	// .Table6_002_Wood_SE  = "resources/textures/objects/Tables/mist/Table.6Places.002_0002.png",
	// .Table6_002_Wood_NE  = "resources/textures/objects/Tables/mist/Table.6Places.002_0003.png",
	// .Table6_002_Wood_NW  = "resources/textures/objects/Tables/mist/Table.6Places.002_0004.png",
	// .Letter_A_SW         = "resources/textures/objects/Letters/mist/A_0001.png",
	// .Letter_A_SE         = "resources/textures/objects/Letters/mist/A_0002.png",
	// .Letter_A_NE         = "resources/textures/objects/Letters/mist/A_0003.png",
	// .Letter_A_NW         = "resources/textures/objects/Letters/mist/A_0004.png",
	// .Letter_G_SW         = "resources/textures/objects/Letters/mist/G_0001.png",
	// .Letter_G_SE         = "resources/textures/objects/Letters/mist/G_0002.png",
	// .Letter_G_NE         = "resources/textures/objects/Letters/mist/G_0003.png",
	// .Letter_G_NW         = "resources/textures/objects/Letters/mist/G_0004.png",
	// .Letter_D_SW         = "resources/textures/objects/Letters/mist/D_0001.png",
	// .Letter_D_SE         = "resources/textures/objects/Letters/mist/D_0002.png",
	// .Letter_D_NE         = "resources/textures/objects/Letters/mist/D_0003.png",
	// .Letter_D_NW         = "resources/textures/objects/Letters/mist/D_0004.png",
	// .Letter_E_SW         = "resources/textures/objects/Letters/mist/E_0001.png",
	// .Letter_E_SE         = "resources/textures/objects/Letters/mist/E_0002.png",
	// .Letter_E_NE         = "resources/textures/objects/Letters/mist/E_0003.png",
	// .Letter_E_NW         = "resources/textures/objects/Letters/mist/E_0004.png",
	.Door_Wood_SW        = "resources/textures/billboards/door-wood/sw-depth-map.png",
	.Door_Wood_SE        = "resources/textures/billboards/door-wood/se-depth-map.png",
	.Door_Wood_NE        = "resources/textures/billboards/door-wood/ne-depth-map.png",
	.Door_Wood_NW        = "resources/textures/billboards/door-wood/nw-depth-map.png",
	.Door_Dark_Wood_SW   = "resources/textures/billboards/door/dark_wood/sw-depth-map.png",
	.Door_Dark_Wood_SE   = "resources/textures/billboards/door/dark_wood/se-depth-map.png",
	.Door_Dark_Wood_NE   = "resources/textures/billboards/door/dark_wood/ne-depth-map.png",
	.Door_Dark_Wood_NW   = "resources/textures/billboards/door/dark_wood/nw-depth-map.png",
	.Window_Wood_SW      = "resources/textures/billboards/window-wood/sw-depth-map.png",
	.Window_Wood_SE      = "resources/textures/billboards/window-wood/se-depth-map.png",
	.Window_Wood_NE      = "resources/textures/billboards/window-wood/ne-depth-map.png",
	.Window_Wood_NW      = "resources/textures/billboards/window-wood/nw-depth-map.png",
	.Window_Dark_Wood_SW = "resources/textures/billboards/window/dark_wood/sw-depth-map.png",
	.Window_Dark_Wood_SE = "resources/textures/billboards/window/dark_wood/se-depth-map.png",
	.Window_Dark_Wood_NE = "resources/textures/billboards/window/dark_wood/ne-depth-map.png",
	.Window_Dark_Wood_NW = "resources/textures/billboards/window/dark_wood/nw-depth-map.png",
	.Shovel_1_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_2_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_3_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_4_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_5_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_6_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_7_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_8_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_9_SW         = "resources/textures/billboards/shovel/depth-map.png",
	.Shovel_10_SW        = "resources/textures/billboards/shovel/depth-map.png",
	.Wall_Cursor         = "resources/textures/billboards/wall-cursor/depth-map.png",
}

FOUR_TILES_BILLBOARD_DEPTH_MAP_TEXTURE_PATHS :: [Texture_2x2]cstring {
	.Table_8_Places_Wood_SW = "resources/textures/billboards/table-8places-wood/sw-depth-map.png",
	.Table_8_Places_Wood_SE = "resources/textures/billboards/table-8places-wood/se-depth-map.png",
	.Table_8_Places_Wood_NE = "resources/textures/billboards/table-8places-wood/ne-depth-map.png",
	.Table_8_Places_Wood_NW = "resources/textures/billboards/table-8places-wood/nw-depth-map.png",
}

billboard_init_draw_context :: proc(
	draw_context: ^Billboard_Draw_Context,
	model_path: cstring,
	texture_paths: [$T]cstring,
	depth_map_texture_paths: [$D]cstring,
	expected_texture_width: i32,
	expected_texture_height: i32,
) -> (
	ok: bool = false,
) {
	load_billboard_model(
		model_path,
		&draw_context.vertices,
		&draw_context.indices,
	) or_return

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	gl.GenBuffers(1, &draw_context.vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, draw_context.vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(draw_context.vertices) * size_of(Billboard_Vertex),
		&draw_context.vertices,
		gl.STATIC_DRAW,
	)

	gl.GenBuffers(1, &draw_context.ebo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, draw_context.ebo)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(draw_context.indices) * size_of(u8),
		&draw_context.indices,
		gl.STATIC_DRAW,
	)


	gl.GenTextures(1, &draw_context.texture_array)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, draw_context.texture_array)
	load_billboard_texture_array(
		texture_paths,
		expected_texture_width,
		expected_texture_height,
	) or_return

	gl.GenTextures(1, &draw_context.depth_map_texture_array)
	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_2D_ARRAY, draw_context.depth_map_texture_array)
	load_billboard_depth_map_texture_array(
		depth_map_texture_paths,
		expected_texture_width,
		expected_texture_height,
	) or_return

	renderer.load_shader_program(
		&billboard_shader_program,
		BILLBOARD_VERTEX_SHADER_PATH,
		BILLBOARD_FRAGMENT_SHADER_PATH,
	) or_return


	gl.Uniform1i(
		gl.GetUniformLocation(billboard_shader_program, "texture_sampler"),
		0,
	)
	gl.Uniform1i(
		gl.GetUniformLocation(
			billboard_shader_program,
			"depth_map_texture_sampler",
		),
		1,
	)

	gl.BindVertexArray(0)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindBuffer(gl.UNIFORM_BUFFER, 0)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	gl.UseProgram(0)

	return true
}

load_billboard_model :: proc(
	path: cstring,
	vertices: ^[4]Billboard_Vertex,
	indices: ^[6]u8,
) -> (
	ok: bool = false,
) {
	options: cgltf.options
	data, result := cgltf.parse_file(options, path)
	if result != .success {
		log.error("failed to parse file")
		return
	}
	result = cgltf.load_buffers(options, data, path)
	if result != .success {
		log.error("failed to load buffers")
		return
	}
	defer cgltf.free(data)

	for mesh in data.meshes {
		primitive := mesh.primitives[0]
		log.info(mesh.name)
		if primitive.indices != nil {
			accessor := primitive.indices
			log.info(path, accessor.count)
			for i in 0 ..< accessor.count {
				index := cgltf.accessor_read_index(accessor, i)
				indices[i] = u8(index)
			}
		}

		for attribute in primitive.attributes {
			if attribute.type == .position {
				accessor := attribute.data
				for i in 0 ..< accessor.count {
					_ = cgltf.accessor_read_float(
						accessor,
						i,
						raw_data(&vertices[i].pos),
						3,
					)
					vertices[i].pos.x *= -1
				}
			}
			if attribute.type == .texcoord {
				accessor := attribute.data
				for i in 0 ..< accessor.count {
					_ = cgltf.accessor_read_float(
						accessor,
						i,
						raw_data(&vertices[i].texcoords),
						2,
					)
				}
			}
		}
	}

	return true
}

load_billboard_depth_map_texture_array :: proc(
	paths: [$T]cstring,
	expected_width: i32,
	expected_height: i32,
) -> (
	ok: bool = true,
) {
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.CLAMP)
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.CLAMP)

	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

	textures :: len(paths)

	if (textures == 0) {
		return true
	}

	stbi.set_flip_vertically_on_load(0)
	stbi.set_flip_vertically_on_load_thread(false)

	gl.TexImage3D(
		gl.TEXTURE_2D_ARRAY,
		0,
		gl.R16,
		expected_width,
		expected_height,
		textures,
		0,
		gl.RED,
		gl.UNSIGNED_SHORT,
		nil,
	)

	for path, i in paths {
		width: i32
		height: i32
		channels: i32
		pixels := stbi.load_16(path, &width, &height, &channels, 1)
		defer stbi.image_free(pixels)

		if pixels == nil {
			log.error("Failed to load texture: ", path)
			return false
		}

		if width != expected_width {
			log.error(
				"Texture: ",
				path,
				" is of a different width. expected: ",
				expected_width,
				" got: ",
				width,
			)
			return false
		}

		if height != expected_height {
			log.error(
				"Texture: ",
				path,
				" is of a different height. expected: ",
				expected_height,
				" got: ",
				height,
			)
			return false
		}

		gl.TexSubImage3D(
			gl.TEXTURE_2D_ARRAY,
			0,
			0,
			0,
			i32(i),
			expected_width,
			expected_height,
			1,
			gl.RED,
			gl.UNSIGNED_SHORT,
			pixels,
		)
	}

	gl_error := gl.GetError()
	if (gl_error != gl.NO_ERROR) {
		log.error(
			"Error loading billboard depth map texture array: ",
			gl_error,
		)
		return false
	}

	return
}

load_billboard_texture_array :: proc(
	paths: [$T]cstring,
	expected_width: i32,
	expected_height: i32,
) -> (
	ok: bool = true,
) {
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_WRAP_T, gl.REPEAT)

	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	// gl.TexParameteri(gl.TEXTURE_2D_ARRAY, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	textures :: len(paths)

	if (textures == 0) {
		return true
	}

	stbi.set_flip_vertically_on_load(0)
	stbi.set_flip_vertically_on_load_thread(false)

	gl.TexImage3D(
		gl.TEXTURE_2D_ARRAY,
		0,
		gl.RGBA8,
		expected_width,
		expected_height,
		textures,
		0,
		gl.RGBA,
		gl.UNSIGNED_BYTE,
		nil,
	)

	for path, i in paths {
		width: i32
		height: i32
		pixels := stbi.load(path, &width, &height, nil, 4)
		defer stbi.image_free(pixels)

		if pixels == nil {
			log.error("Failed to load texture: ", path)
			return false
		}

		if width != expected_width {
			log.error(
				"Texture: ",
				path,
				" is of a different width. expected: ",
				expected_width,
				" got: ",
				width,
			)
			return false
		}

		if height != expected_height {
			log.error(
				"Texture: ",
				path,
				" is of a different height. expected: ",
				expected_height,
				" got: ",
				height,
			)
			return false
		}

		gl.TexSubImage3D(
			gl.TEXTURE_2D_ARRAY,
			0,
			0,
			0,
			i32(i),
			expected_width,
			expected_height,
			1,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			pixels,
		)
	}

	return
}

init_draw_contexts :: proc() -> bool {
	gl.GenBuffers(1, &billboard_ubo)

	billboard_init_draw_context(
		&billboard_1x1_draw_context,
		BILLBOARD_MODEL_PATH,
		BILLBOARD_TEXTURE_PATHS,
		BILLBOARD_DEPTH_MAP_TEXTURE_PATHS,
		BILLBOARD_TEXTURE_WIDTH,
		BILLBOARD_TEXTURE_HEIGHT,
	) or_return

	billboard_init_draw_context(
		&billboard_2x2_draw_context,
		FOUR_TILES_BILLBOARD_MODEL_PATH,
		FOUR_TILES_BILLBOARD_TEXTURE_PATHS,
		FOUR_TILES_BILLBOARD_DEPTH_MAP_TEXTURE_PATHS,
		FOUR_TILES_BILLBOARD_TEXTURE_WIDTH,
		FOUR_TILES_BILLBOARD_TEXTURE_HEIGHT,
	) or_return

	return true
}

get_chunk_1x1 :: proc(pos: glsl.vec3) -> ^Billboard_Chunk(Billboard_1x1) {
	floor := get_floor_from_vec3(pos)
	x := clamp(
		int(pos.x / game.CHUNK_WIDTH),
		0,
		game.WORLD_CHUNK_WIDTH - 1,
	)
	z := clamp(
		int(pos.z / game.CHUNK_DEPTH),
		0,
		game.WORLD_CHUNK_DEPTH - 1,
	)
	return &chunks_1x1[floor][x][z]
}

get_billboard_1x1 :: proc(key: Key) -> (^Billboard_1x1, bool) {
	chunk := get_chunk_1x1(key.pos)
	return &chunk.instances[key]
}

has_billboard_1x1 :: proc(key: Key) -> bool {
	chunk := get_chunk_1x1(key.pos)
	return key in chunk.instances
}

mark_chunk_1x1_dirty :: proc(key: Key) {
	chunk := get_chunk_1x1(key.pos)
	chunk.dirty = true
}

billboard_1x1_set_texture :: proc(key: Key, texture: Texture_1x1) {
	chunk := get_chunk_1x1(key.pos)
	billboard, ok := &chunk.instances[key]
	if ok {
		billboard.texture = texture
		billboard.depth_map = texture
		chunk.dirty = true
	}
}

billboard_1x1_set_light :: proc(key: Key, light: glsl.vec3) {
	chunk := get_chunk_1x1(key.pos)
	billboard, ok := &chunk.instances[key]
	if ok {
		billboard.light = light
		chunk.dirty = true
	}
}

billboard_1x1_remove :: proc(key: Key) {
	chunk := get_chunk_1x1(key.pos)
	delete_key(&chunk.instances, key)
	chunk.dirty = true
}

get_floor_from_vec3 :: proc(pos: glsl.vec3) -> int {
	terrain_height := game.get_terrain_height(
		{i32(pos.x + 0.5), i32(pos.z + 0.5)},
	)
	return clamp(
		int((pos.y - terrain_height) / game.WALL_HEIGHT),
		0,
		game.CHUNK_HEIGHT - 1,
	)
}

billboard_1x1_move :: proc(of: ^Key, to: glsl.vec3) {
	if of.pos == to {
		return
	}
	from_chunk := get_chunk_1x1(of.pos)
	to_chunk := get_chunk_1x1(to)
	billboard, ok := from_chunk.instances[of^]
	if ok {
		delete_key(&from_chunk.instances, of^)
		of.pos = to
		to_chunk.instances[of^] = billboard
		to_chunk.dirty = true
		from_chunk.dirty = true
	}
}

billboard_1x1_set :: proc(key: Key, billboard: Billboard_1x1) {
	chunk := get_chunk_1x1(key.pos)
	chunk.instances[key] = billboard
	chunk.dirty = true
}

chunk_billboards_draw :: proc(
	billboards: ^Billboard_Chunk($T),
	billboard_draw_context: Billboard_Draw_Context,
) {
	if !billboards.initialized {
		billboards.initialized = true
		billboards.dirty = true

		gl.GenVertexArrays(1, &billboards.vao)
		gl.BindVertexArray(billboards.vao)

		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, billboard_draw_context.ebo)

		gl.GenBuffers(1, &billboards.ibo)

		gl.BindBuffer(gl.ARRAY_BUFFER, billboard_draw_context.vbo)

		gl.EnableVertexAttribArray(0)
		gl.VertexAttribPointer(
			0,
			3,
			gl.FLOAT,
			gl.FALSE,
			size_of(Billboard_Vertex),
			offset_of(Billboard_Vertex, pos),
		)

		gl.EnableVertexAttribArray(1)
		gl.VertexAttribPointer(
			1,
			2,
			gl.FLOAT,
			gl.FALSE,
			size_of(Billboard_Vertex),
			offset_of(Billboard_Vertex, texcoords),
		)

		gl.BindBuffer(gl.ARRAY_BUFFER, billboards.ibo)

		gl.EnableVertexAttribArray(2)
		gl.VertexAttribPointer(
			2,
			3,
			gl.FLOAT,
			gl.FALSE,
			size_of(Billboard_Instance),
			offset_of(Billboard_Instance, position),
		)

		gl.EnableVertexAttribArray(3)
		gl.VertexAttribPointer(
			3,
			3,
			gl.FLOAT,
			gl.FALSE,
			size_of(Billboard_Instance),
			offset_of(Billboard_Instance, light),
		)

		gl.EnableVertexAttribArray(4)
		gl.VertexAttribPointer(
			4,
			1,
			gl.FLOAT,
			gl.FALSE,
			size_of(Billboard_Instance),
			offset_of(Billboard_Instance, texture),
		)

		gl.EnableVertexAttribArray(5)
		gl.VertexAttribPointer(
			5,
			1,
			gl.FLOAT,
			gl.FALSE,
			size_of(Billboard_Instance),
			offset_of(Billboard_Instance, depth_map),
		)

		gl.VertexAttribDivisor(2, 1)
		gl.VertexAttribDivisor(3, 1)
		gl.VertexAttribDivisor(4, 1)
		gl.VertexAttribDivisor(5, 1)

		gl.BindVertexArray(0)
		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0)
	}

	if billboards.dirty {
		billboards.dirty = false

		gl.BindBuffer(gl.ARRAY_BUFFER, billboards.ibo)
		gl.BufferData(
			gl.ARRAY_BUFFER,
			len(billboards.instances) * size_of(Billboard_Instance),
			nil,
			gl.STATIC_DRAW,
		)

		i := 0
		for k, v in billboards.instances {
			instance: Billboard_Instance = {
				position  = k.pos,
				light     = v.light,
				texture   = f32(v.texture),
				depth_map = f32(v.depth_map),
			}
			gl.BufferSubData(
				gl.ARRAY_BUFFER,
				i * size_of(Billboard_Instance),
				size_of(Billboard_Instance),
				&instance,
			)
			i += 1
		}

		gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	}

	if len(billboard_draw_context.indices) == 0 ||
	   len(billboards.instances) == 0 {
		return
	}

	gl.BindVertexArray(billboards.vao)
	gl.DrawElementsInstanced(
		gl.TRIANGLES,
		i32(len(billboard_draw_context.indices)),
		gl.UNSIGNED_BYTE,
		nil,
		i32(len(billboards.instances)),
	)
	gl.BindVertexArray(0)
}

billboard_update_draw_context_after_rotation :: proc(draw_context: $T) {
	gl.BindBuffer(gl.ARRAY_BUFFER, draw_context.vbo)
	for v, i in draw_context.vertices {
		v := v
		rotation := glsl.mat4Rotate(
			{0, 1, 0},
			(math.PI / 2) * f32(game.camera().rotation),
		)
		v.pos = (glsl.vec4{v.pos.x, v.pos.y, v.pos.z, 1} * rotation).xyz
		gl.BufferSubData(
			gl.ARRAY_BUFFER,
			i * size_of(Billboard_Vertex),
			size_of(Billboard_Vertex),
			&v,
		)
	}
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
}

update_after_rotation :: proc() {
	billboard_update_draw_context_after_rotation(billboard_1x1_draw_context)
	billboard_update_draw_context_after_rotation(billboard_2x2_draw_context)
}

update_after_clockwise_rotation :: proc() {
	for &floor in chunks_1x1 {
		for &row in floor {
			for &chunk in row {
				update_after_clockwise_rotation_1x1(&chunk)
			}
		}
	}
	for &floor in chunks_2x2 {
		for &row in floor {
			for &chunk in row {
				update_after_clockwise_rotation_2x2(&chunk)
			}
		}
	}
}

update_after_counter_clockwise_rotation :: proc() {
	for &floor in chunks_1x1 {
		for &row in floor {
			for &chunk in row {
				update_after_counter_clockwise_rotation_1x1(&chunk)
			}
		}
	}
	for &floor in chunks_2x2 {
		for &row in floor {
			for &chunk in row {
				update_after_counter_clockwise_rotation_2x2(&chunk)
			}
		}
	}
}

update_after_counter_clockwise_rotation_1x1 :: proc(
	billboards: ^Billboard_Chunk(Billboard_1x1),
) {
	rotation_table := BILLBOARD_COUNTER_CLOCKWISE_ROTATION_TABLE_1X1
	for _, &billboard in billboards.instances {
		billboard.texture = rotation_table[billboard.texture]
		billboard.depth_map = rotation_table[billboard.depth_map]
	}
	billboards.dirty = true
}

update_after_counter_clockwise_rotation_2x2 :: proc(
	billboards: ^Billboard_Chunk(Billboard_2x2),
) {
	rotation_table := BILLBOARD_COUNTER_CLOCKWISE_ROTATION_TABLE_2X2
	for _, &billboard in billboards.instances {
		billboard.texture = rotation_table[billboard.texture]
		billboard.depth_map = rotation_table[billboard.depth_map]
	}
	billboards.dirty = true
}

update_after_clockwise_rotation_1x1 :: proc(
	billboards: ^Billboard_Chunk(Billboard_1x1),
) {
	rotation_table := BILLBOARD_CLOCKWISE_ROTATION_TABLE_1X1
	for _, &billboard in billboards.instances {
		billboard.texture = rotation_table[billboard.texture]
		billboard.depth_map = rotation_table[billboard.depth_map]
	}
	billboards.dirty = true
}

update_after_clockwise_rotation_2x2 :: proc(
	billboards: ^Billboard_Chunk(Billboard_2x2),
) {
	rotation_table := BILLBOARD_CLOCKWISE_ROTATION_TABLE_2X2
	for _, &billboard in billboards.instances {
		billboard.texture = rotation_table[billboard.texture]
		billboard.depth_map = rotation_table[billboard.depth_map]
	}
	billboards.dirty = true
}

draw_billboards :: proc(floor: i32) {
	gl.BindBuffer(gl.UNIFORM_BUFFER, billboard_ubo)
	ubo_index := gl.GetUniformBlockIndex(
		billboard_shader_program,
		"UniformBufferObject",
	)
	gl.UniformBlockBinding(billboard_shader_program, ubo_index, 2)
	gl.BindBufferBase(gl.UNIFORM_BUFFER, 2, billboard_ubo)

	billboard_uniform_object.view = game.camera().view
	billboard_uniform_object.proj = game.camera().proj

	gl.BufferData(
		gl.UNIFORM_BUFFER,
		size_of(Billboard_Uniform_Object),
		&billboard_uniform_object,
		gl.STATIC_DRAW,
	)

	gl.UseProgram(billboard_shader_program)

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(
		gl.TEXTURE_2D_ARRAY,
		billboard_1x1_draw_context.texture_array,
	)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(
		gl.TEXTURE_2D_ARRAY,
		billboard_1x1_draw_context.depth_map_texture_array,
	)

	for &floor in chunks_1x1[:floor + 1] {
		for x in game.camera().visible_chunks_start.x ..< game.camera().visible_chunks_end.x {
			for z in game.camera().visible_chunks_start.y ..< game.camera().visible_chunks_end.y {
				chunk_billboards_draw(&floor[x][z], billboard_1x1_draw_context)
			}
		}
	}

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(
		gl.TEXTURE_2D_ARRAY,
		billboard_2x2_draw_context.texture_array,
	)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(
		gl.TEXTURE_2D_ARRAY,
		billboard_2x2_draw_context.depth_map_texture_array,
	)

	for &floor in chunks_2x2 {
		for x in game.camera().visible_chunks_start.x ..< game.camera().visible_chunks_end.x {
			for z in game.camera().visible_chunks_start.y ..< game.camera().visible_chunks_end.y {
				chunk_billboards_draw(&floor[x][z], billboard_2x2_draw_context)
			}
		}
	}
}
