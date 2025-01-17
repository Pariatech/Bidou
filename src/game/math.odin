package game

import m "core:math/linalg/glsl"
import "core:testing"

triangle_normal :: proc(p0, p1, p2: m.vec3) -> m.vec3 {
	a := p1 - p0
	b := p2 - p0
	return m.cross(a, b)
}

vec3_to_vec4 :: proc(v: m.vec3) -> (result: m.vec4) {
    result.xyz = v.xyz
	return
}

vec3_scalar_to_vec4 :: proc(v: m.vec3, scalar: f32) -> (result: m.vec4) {
    result.xyz = v.xyz
    result.w = scalar
	return
}

vec4 :: proc {
    vec3_to_vec4,
    vec3_scalar_to_vec4,
}

point_in_rhombus :: proc(
	point: m.vec2,
	center: m.vec2,
	top: m.vec2,
	right: m.vec2,
	bottom: m.vec2,
	left: m.vec2,
) -> bool {
	center_to_top := top - center
	center_to_right := right - center
	center_to_bottom := bottom - center
	center_to_left := left - center
	center_to_point := point - center

	return(
		m.dot(center_to_point, center_to_top) <=
			m.dot(center_to_top, center_to_top) &&
		m.dot(center_to_point, center_to_right) <=
			m.dot(center_to_right, center_to_right) &&
		m.dot(center_to_point, center_to_bottom) <=
			m.dot(center_to_bottom, center_to_bottom) &&
		m.dot(center_to_point, center_to_left) <=
			m.dot(center_to_left, center_to_left) \
	)
}

point_in_square :: proc(point: m.vec2, center: m.vec2, size: f32) -> bool {
	half_size := size / 2

	return(
		point.x >= center.x - half_size &&
		point.x <= center.x + half_size &&
		point.y >= center.y - half_size &&
		point.y <= center.y + half_size \
	)
}

Rectangle :: struct {
	x: i32,
	y: i32,
	w: i32,
	h: i32,
}

aabb_intersection :: proc(a: Rectangle, b: Rectangle) -> bool {
    a_left := a.x
    a_right := a.x + a.w
    a_bottom := a.y
    a_top := a.y + a.h

    b_left := b.x
    b_right := b.x + b.w
    b_bottom := b.y
    b_top := b.y + b.h

    x_overlap := a_left <= b_right && a_right >= b_left
    y_overlap := a_bottom <= b_top && a_top >= b_bottom

    return x_overlap && y_overlap
}


@(test)
aabb_intersection_test :: proc(t: ^testing.T) {
    testing.expect_value(t, aabb_intersection({0, 0, 1, 1}, {0, 0, 1, 1}), true)
    testing.expect_value(t, aabb_intersection({0, 0, 1, 1}, {0, 0, 2, 2}), true)
    testing.expect_value(t, aabb_intersection({0, 0, 1, 1}, {2, 2, 2, 2}), false)
    testing.expect_value(t, aabb_intersection({1, 1, 1, 1}, {0, 0, 2, 2}), true)
    testing.expect_value(t, aabb_intersection({2, 2, 1, 1}, {0, 0, 3, 3}), true)
    testing.expect_value(t, aabb_intersection({1, 1, 2, 2}, {0, 0, 3, 3}), true)
}
