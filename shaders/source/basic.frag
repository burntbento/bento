#version 460 core

in vec4 outColor;
in vec2 outUv;
out vec4 fColor;

uniform sampler2D t;

void main() {
	fColor = outColor * texture(t, outUv);
}
