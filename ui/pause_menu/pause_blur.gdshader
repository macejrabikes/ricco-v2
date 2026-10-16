shader_type canvas_item;
// Rozmazané a stmavené pozadie pod pause menu.
// Godot docs: tutorials/shaders/screen-reading_shaders – textureLod so screen texture
// a filter_linear_mipmap dáva rozmazanie (vyšší lod = viac rozmazané).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur : hint_range(0.0, 5.0) = 0.0;
uniform float dim : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, blur).rgb;
	COLOR = vec4(c * (1.0 - dim), 1.0);
}
