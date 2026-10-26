shader_type spatial;
// 강아지 털 (GDD_V3 3.1): 더러움 마스크 + 젖음 / 뽀송 값.
// 마스크 좌표는 UV 가 아니라 몸 중심에서 본 방향 (scripts/sim/paint_mask.gd 와 같은 식).
// mask: R=적시기 G=문지르기(진흙 지움) B=헹구기 A=드라이어

uniform sampler2D mask : filter_linear, repeat_enable;
uniform sampler2D mud : filter_linear, repeat_enable;
// 월드 → 강아지 기준 좌표 (회전판이 돌아도 마스크가 몸에 붙어 있게). 스크립트가 매 프레임 넣는다.
uniform mat4 world_to_dog = mat4(1.0);
uniform vec3 center = vec3(0.0, 0.3, 0.0);
uniform vec4 fur_color : source_color = vec4(0.95, 0.88, 0.75, 1.0);
uniform vec4 mud_color : source_color = vec4(0.42, 0.27, 0.12, 1.0);
uniform float wet_amount = 1.0;
// 부위별 색 (귀·꼬리 끝 등). 털 색에 곱한다. MeshInstance 마다 set_instance_shader_parameter("tint", 색)
instance uniform vec4 tint : source_color = vec4(1.0);
// 털결: 가는 줄무늬 세기 (0 = 매끈)
uniform float strand_amount = 0.07;
// 진행 비율만 받을 때 (다른 사람 화면): 마스크 대신 이 값을 쓴다
uniform bool use_global = false;
uniform vec4 global_mask = vec4(0.0);
// 남은 곳 반짝임: 0~1, 채널 0~3
uniform float blink = 0.0;
uniform int blink_channel = 0;

varying vec3 local_dir;
varying vec3 local_pos;

vec2 dir_to_uv(vec3 d) {
	d = normalize(d);
	return vec2((atan(d.x, d.z) + PI) / TAU, acos(clamp(d.y, -1.0, 1.0)) / PI);
}

void vertex() {
	// 부위(몸·머리·다리)가 따로 된 메시라도 같은 마스크를 쓰도록 강아지 기준 좌표로 바꾼다.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = (world_to_dog * vec4(world, 1.0)).xyz;
	local_dir = local_pos - center;
}

void fragment() {
	vec2 uv = dir_to_uv(local_dir);
	vec4 m = use_global ? global_mask : texture(mask, uv);
	float dirt = texture(mud, uv).r * (1.0 - m.g);
	// 털결: 몸 방향을 따라 흐르는 가는 줄 (젖으면 납작해져 덜 보임)
	float strand = sin(local_pos.x * 260.0 + sin(local_pos.y * 90.0) * 2.0) * sin(local_pos.z * 230.0 + local_pos.y * 120.0);
	float wet = clamp(m.r - m.a, 0.0, 1.0) * wet_amount;
	vec3 base = fur_color.rgb * tint.rgb * (1.0 + strand * strand_amount * (1.0 - wet * 0.8));
	vec3 color = mix(base, mud_color.rgb, dirt);
	color *= mix(vec3(1.0), vec3(0.42, 0.40, 0.40), wet); // 젖으면 진하게
	color = mix(color, vec3(1.0), m.a * 0.35); // 말리면 밝게
	ALBEDO = color;
	ROUGHNESS = mix(0.9, 0.55, wet);        // 젖으면 살짝 반짝 (너무 매끈하면 금속처럼 보임)
	SPECULAR = mix(0.3, 0.45, wet);
	// 보송한 테두리 (털 끝이 빛을 받는 느낌), 젖으면 사라짐
	RIM = 0.3 * (1.0 - wet);
	RIM_TINT = 0.6;
	float remaining = 1.0 - m[blink_channel];
	EMISSION = vec3(1.0, 0.85, 0.2) * blink * step(0.5, remaining) * 0.8;
}
