package main

import "vendor:glfw"

CAMERA_SPEED :: 2.0
CAMERA_TRANSLATE :: Vec3{-10, 10, -10}

zoom: f32 = 2.0
camera_position: Vec3

look_at :: proc(eye, target, up: Vec3) -> Mat4 {
	f := normalize(target - eye)
	r := normalize(cross(up, f))
	u := cross(f, r)

	view := Mat4{}

	view[0] = {r.x, u.x, -f.x, 0}
	view[1] = {r.y, u.y, -f.y, 0}
	view[2] = {r.z, u.z, -f.z, 0}
	view[3] = {-dot(r, eye), -dot(u, eye), dot(f, eye), 1}

	return view
}

ortho :: proc(left, right, bottom, top, near, far: f32) -> Mat4 {
	proj := Mat4{}

    proj[0,0] = 2 / (right - left)
    proj[1,1] = 2 / (top - bottom)
    proj[2,2] = -2 / (far - near)
    proj[3,3] = 1

    proj[0, 3] = -(right + left) / (right - left)
    proj[1, 3] = -(top + bottom) / (top - bottom)
    proj[2, 3] = -(far + near) / (far - near)

	return proj
}

update_camera :: proc(delta_time: f64) {
	camera_movement := f32(CAMERA_SPEED * delta_time)
	if is_key_down(.Key_W) {
		camera_position += Vec3{camera_movement, 0, camera_movement}
	} else if is_key_down(.Key_S) {
		camera_position += Vec3{-camera_movement, 0, -camera_movement}
	}

	if is_key_down(.Key_A) {
		camera_position += Vec3{-camera_movement, 0, camera_movement}
	} else if is_key_down(.Key_D) {
		camera_position += Vec3{camera_movement, 0, -camera_movement}
	}

	uniform_object.view = look_at(
		camera_position + CAMERA_TRANSLATE,
		camera_position,
		{0, 1, 0},
	)
	width, height := glfw.GetWindowSize(window_handle)
	aspect_ratio := f32(height) / f32(width)
	scale := f32(width) / TEXTURE_SIZE
	uniform_object.proj = ortho(
		-1 / zoom * scale,
		1 / zoom * scale,
		-aspect_ratio / zoom * scale,
		aspect_ratio / zoom * scale,
		0.1,
		100.0,
	)
}
