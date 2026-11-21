#version 460 core

#define SCAN_LINE_MULT 1250.0

in vec4 outColor;
in vec2 outUv;
out vec4 fColor;

uniform sampler2D t;

void main() {
	vec2 tc = vec2(outUv.x, outUv.y);

	// Distance from the center
	float dx = abs(0.5-tc.x);
	float dy = abs(0.5-tc.y);

	// Square it to smooth the edges
	dx *= dx;
	dy *= dy;

	// Get texel, and add in scanline if need be
	vec4 cta = texture(t, vec2(tc.x, tc.y));

	cta.rgb += sin(tc.y * SCAN_LINE_MULT) * 0.02;

	// Apply
	fColor = cta * outColor;
}

