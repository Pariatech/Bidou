package game

import "core:math/linalg/glsl"

Plot :: struct {
	name: string,
}

Plots :: struct {
    data: [dynamic]Plot,
    tile_plot_indices: [WORLD_WIDTH][WORLD_DEPTH]u8,
}

AVAILABLE_PLOT :: Plot {
	name = "Available Plot",
}

WORLD_PLOT :: Plot {
	name = "World Plot",
}

plots :: proc() -> ^Plots {
    return &game().plots
}

plots_init :: proc() {
    append(&plots().data, AVAILABLE_PLOT)
    append(&plots().data, WORLD_PLOT)

    for i in 0 ..< 9 {
        for j in 0 ..< WORLD_WIDTH {
            plots_set_tile_plot_world({i32(i), i32(j)})
            plots_set_tile_plot_world({i32(j), i32(i)})
        }
    }
}

plots_deinit :: proc() {
    delete(plots().data)
}

plots_get_plot :: proc(index: u8) -> Plot {
    return plots().data[index]
}

plots_get_tile_plot :: proc(tile: glsl.ivec2) -> u8 {
    return plots().tile_plot_indices[tile.x][tile.y]
}

plots_set_tile_plot :: proc(tile: glsl.ivec2, plot_index: u8) {
    plots().tile_plot_indices[tile.x][tile.y] = plot_index
}

plots_set_tile_plot_world :: proc(tile: glsl.ivec2) {
    plots_set_tile_plot(tile, 1)
}

