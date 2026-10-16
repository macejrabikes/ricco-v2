shader_type canvas_item;
// Retro filter – starý film: sépia, zrno, vinetácia a jemné blikanie.
// Číta obrazovku pod sebou (Godot docs: tutorials/shaders/screen-reading_shaders).
// HUD je vo vyššej vrstve, takže ostáva farebný.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float grain : hint_range(0.0, 0.3) = 0.07;
uniform float vignette : hint_range(0.0, 1.5) = 0.6;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 sep = vec3(l * 1.05 + 0.11, l * 0.92 + 0.05, l * 0.72 - 0.02);   // ako WANTED plagát
	float n = hash(floor(FRAGCOORD.xy) + floor(TIME * 24.0) * 7.31);        // zrno sa mení 24× za s (ako film)
	sep *= 1.0 - grain + n * grain * 2.0;
	vec2 d = SCREEN_UV - 0.5;
	sep *= clamp(1.0 - dot(d, d) * vignette * 2.0, 0.0, 1.0);
	sep *= 0.975 + 0.025 * sin(TIME * 21.0);                                 // jemné blikanie projektora
	COLOR = vec4(mix(c, clamp(sep, 0.0, 1.0), strength), 1.0);
}
