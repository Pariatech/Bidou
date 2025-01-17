package game

import "core:log"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "vendor:glfw"

CAMERA_SPEED :: 8.0
CAMERA_ZOOM_SPEED :: 0.05
CAMERA_ZOOM_MAX :: 2
CAMERA_ZOOM_MIN :: 0.5
CAMERA_ANGLE :: f64(math.RAD_PER_DEG * 30)
CAMERA_DISTANCE :: f64(40)

Camera :: struct {
	zoom:                 f64,
	position:             glsl.dvec3,
	rotation:             Camera_Rotation,
	distance:             f64,
	translate:            glsl.dvec3,
	view:                 glsl.mat4,
	proj:                 glsl.mat4,
	dview:                glsl.dmat4,
	dproj:                glsl.dmat4,
	view_proj:            glsl.mat4,
	inverse_view_proj:    glsl.mat4,
	dview_proj:           glsl.dmat4,
	dinverse_view_proj:   glsl.dmat4,
	left:                 f64,
	right:                f64,
	top:                  f64,
	bottom:               f64,
	visible_chunks_start: glsl.ivec2,
	visible_chunks_end:   glsl.ivec2,
}

Camera_Visible_Chunk_Iterator :: struct {
	pos:  glsl.ivec2,
	next: proc(it: ^Camera_Visible_Chunk_Iterator) -> (glsl.ivec2, bool),
}

Camera_Rotation :: enum {
	South_West,
	South_East,
	North_East,
	North_West,
}

Camera_Rotated :: enum {
	Clockwise,
	Counter_Clockwise,
}

camera :: proc() -> ^Camera {
	return &game().camera
}

camera_init :: proc() -> bool {
	camera().zoom = 1
	camera().distance = CAMERA_DISTANCE
	camera().translate = glsl.dvec3 {
		-CAMERA_DISTANCE,
		math.sqrt(math.pow(CAMERA_DISTANCE, 2) * 2) * math.tan(CAMERA_ANGLE),
		-CAMERA_DISTANCE,
	}

	return true
}

camera_rotate_counter_clockwise :: proc() {
	camera().translate *= glsl.dvec3{-1, 1, 1}
	camera().translate.zx = camera().translate.xz
	camera().rotation = Camera_Rotation((int(camera().rotation) + 3) % 4)
}

camera_rotate_clockwise :: proc() {
	camera().translate *= glsl.dvec3{1, 1, -1}
	camera().translate.zx = camera().translate.xz
	camera().rotation = Camera_Rotation((int(camera().rotation) + 1) % 4)
}

camera_update :: proc(delta_time: f64) {
	camera().zoom -= mouse_get_scroll().y * CAMERA_ZOOM_SPEED
	camera().zoom = math.clamp(camera().zoom, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	// fixed_zoom := math.pow(2, math.round(math.log2(zoom)))

	width, height := glfw.GetWindowSize(window().handle)

	movement := glsl.dvec3 {
		CAMERA_SPEED * delta_time * (camera().zoom + 1),
		0,
		CAMERA_SPEED * delta_time * (camera().zoom + 1),
	}

	movement *= camera().translate / camera().distance

	if keyboard_is_key_down(.Key_W) {
		camera().position += glsl.dvec3{-movement.x, 0, -movement.z}
	} else if keyboard_is_key_down(.Key_S) {
		camera().position += glsl.dvec3{movement.x, 0, movement.z}
	}

	if keyboard_is_key_down(.Key_A) {
		camera().position += glsl.dvec3{movement.z, 0, -movement.x}
	} else if keyboard_is_key_down(.Key_D) {
		camera().position += glsl.dvec3{-movement.z, 0, movement.x}
	}

	// position.x = math.floor(position.x * 512) / 512
	// position.y = math.floor(position.y * 512) / 512
	// position.z = math.floor(position.z * 512) / 512
	// log.info(position)

	camera().dview = glsl.dmat4LookAt(
		camera().position + camera().translate,
		camera().position,
		{0, 1, 0},
	)
	aspect_ratio := f64(height) / f64(width)
	scale := f64(width) / (math.pow(f64(2.8284), 5) / camera().zoom)
	scale *= f64(window().scale.y)

	camera().left = scale
	camera().right = -scale
	camera().bottom = -aspect_ratio * scale
	camera().top = aspect_ratio * scale

	camera().dproj = glsl.dmat4Ortho3d(
		camera().left,
		camera().right,
		camera().bottom,
		camera().top,
		0.1,
		120.0,
	)

	camera().dview_proj = camera().dproj * camera().dview
	camera().dinverse_view_proj = linalg.inverse(camera().dview_proj)

	camera().view = linalg.matrix_cast(camera().dview, f32)
	camera().proj = linalg.matrix_cast(camera().dproj, f32)
	camera().view_proj = linalg.matrix_cast(camera().dview_proj, f32)
	camera().inverse_view_proj = linalg.matrix_cast(
		camera().dinverse_view_proj,
		f32,
	)
}

camera_get_view_corner :: proc(screen_point: glsl.vec2) -> glsl.vec2 {
	p1 :=
		linalg.inverse(camera().view_proj) *
		glsl.vec4{screen_point.x, screen_point.y, -1, 1}
	p2 :=
		linalg.inverse(camera().view_proj) *
		glsl.vec4{screen_point.x, screen_point.y, 1, 1}
	t := -p1.y / (p2.y - p1.y)
	return glsl.vec2{p1.x + t * (p2.x - p1.x), p1.z + t * (p2.z - p1.z)}
}

camera_get_aabb :: proc() -> Rectangle {
	bottom_left := camera_get_view_corner({-1, -1})
	top_left := camera_get_view_corner({-1, 1})
	bottom_right := camera_get_view_corner({1, -1})
	top_right := camera_get_view_corner({1, 1})
	dcamera := camera().position + camera().translate
	cam := glsl.vec3{f32(dcamera.x), f32(dcamera.y), f32(dcamera.z)}

	aabb: Rectangle
	switch camera().rotation {
	case .South_West:
		cam.x = bottom_left.x
		cam.z = bottom_right.y
		width := top_right.x - cam.x
		height := top_left.y - cam.z

		aabb = Rectangle {
			x = i32(cam.x),
			y = i32(cam.z),
			w = i32(math.ceil(width)),
			h = i32(math.ceil(height)),
		}
	case .South_East:
		cam.x = bottom_right.x
		cam.z = bottom_left.y
		width := cam.x - top_left.x
		height := top_right.y - cam.z

		aabb = Rectangle {
			x = i32(top_left.x),
			y = i32(cam.z),
			w = i32(math.ceil(width)),
			h = i32(math.ceil(height)),
		}
	case .North_East:
		cam.x = bottom_left.x
		cam.z = bottom_right.y
		width := cam.x - top_right.x
		height := cam.z - top_left.y

		aabb = Rectangle {
			x = i32(top_right.x),
			y = i32(top_left.y),
			w = i32(math.ceil(width)),
			h = i32(math.ceil(height)),
		}
	case .North_West:
		cam.x = bottom_right.x
		cam.z = bottom_left.y
		width := top_left.x - cam.x
		height := cam.z - top_right.y

		aabb = Rectangle {
			x = i32(cam.x),
			y = i32(top_right.y),
			w = i32(math.ceil(width)),
			h = i32(math.ceil(height)),
		}
	}

	return aabb
}

camera_next_visible_chunk_south_west :: proc(
	it: ^Camera_Visible_Chunk_Iterator,
) -> (
	glsl.ivec2,
	bool,
) {
	if it.pos.x < camera().visible_chunks_start.x {
		it.pos.x = camera().visible_chunks_end.x - 1
		it.pos.y -= 1
	}

	if it.pos.y < camera().visible_chunks_start.y {
		return {}, false
	}

	pos := it.pos
	it.pos.x -= 1
	return pos, true
}

camera_next_visible_chunk_south_east :: proc(
	it: ^Camera_Visible_Chunk_Iterator,
) -> (
	glsl.ivec2,
	bool,
) {
	if it.pos.x >= camera().visible_chunks_end.x {
		it.pos.x = camera().visible_chunks_start.x
		it.pos.y -= 1
	}

	if it.pos.y < camera().visible_chunks_start.y {
		return {}, false
	}

	pos := it.pos
	it.pos.x += 1
	return pos, true
}

camera_next_visible_chunk_north_east :: proc(
	it: ^Camera_Visible_Chunk_Iterator,
) -> (
	glsl.ivec2,
	bool,
) {
	if it.pos.x >= camera().visible_chunks_end.x {
		it.pos.x = camera().visible_chunks_start.x
		it.pos.y += 1
	}

	if it.pos.y >= camera().visible_chunks_end.y {
		return {}, false
	}

	pos := it.pos
	it.pos.x += 1
	return pos, true
}

camera_next_visible_chunk_north_west :: proc(
	it: ^Camera_Visible_Chunk_Iterator,
) -> (
	glsl.ivec2,
	bool,
) {
	if it.pos.x < camera().visible_chunks_start.x {
		it.pos.x = camera().visible_chunks_end.x - 1
		it.pos.y += 1
	}

	if it.pos.y >= camera().visible_chunks_end.y {
		return {}, false
	}

	pos := it.pos
	it.pos.x -= 1
	return pos, true
}

camera_make_visible_chunk_iterator :: proc() -> Camera_Visible_Chunk_Iterator {
	it: Camera_Visible_Chunk_Iterator
	switch camera().rotation {
	case .South_West:
		it.pos = camera().visible_chunks_end - {1, 1}
		it.next = camera_next_visible_chunk_south_west
	case .South_East:
		it.pos.x = camera().visible_chunks_start.x
		it.pos.y = camera().visible_chunks_end.y - 1
		it.next = camera_next_visible_chunk_south_east
	case .North_East:
		it.pos = camera().visible_chunks_start
		it.next = camera_next_visible_chunk_north_east
	case .North_West:
		it.pos.x = camera().visible_chunks_end.x - 1
		it.pos.y = camera().visible_chunks_start.y
		it.next = camera_next_visible_chunk_north_west
	}
	return it
}
