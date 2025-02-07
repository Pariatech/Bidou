package game

CHUNK_WIDTH :: 8
CHUNK_DEPTH :: 8
CHUNK_HEIGHT :: 8

WORLD_WIDTH :: 64
WORLD_HEIGHT :: 4
WORLD_DEPTH :: 64
WORLD_CHUNK_WIDTH :: WORLD_WIDTH / CHUNK_WIDTH
WORLD_CHUNK_DEPTH :: WORLD_DEPTH / CHUNK_DEPTH

SUN_POWER :: 1.5

WALL_HEIGHT :: 3
DOWN_WALL_HEIGHT :: 0.2
DOWN_WALL_TEXTURE :: 1 - DOWN_WALL_HEIGHT / WALL_HEIGHT

WALL_TOP_OFFSET :: -0.0001
FLOOR_TILE_OFFSET :: 0.0001
