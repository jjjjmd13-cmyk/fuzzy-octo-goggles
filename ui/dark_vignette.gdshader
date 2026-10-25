shader_type canvas_item;
// 어둠 게이지 화면 연출 (GDD 5.4: 화면 가장자리가 점점 어두워짐, 숫자는 안 보임).

uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = length(UV - vec2(0.5)) * 1.414;
	float edge = 1.0 - amount * 0.85;
	float a = smoothstep(edge - 0.25, edge + 0.35, d) * amount;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(a * 1.1, 0.0, 0.97));
}
