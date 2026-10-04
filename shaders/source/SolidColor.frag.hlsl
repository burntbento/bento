 cbuffer UBO : register(b0, space3)
 {
		float4 Tint;
 };

 float4 main(float4 Color : TEXCOORD0) : SV_Target0
 {
		return Tint;
 }
