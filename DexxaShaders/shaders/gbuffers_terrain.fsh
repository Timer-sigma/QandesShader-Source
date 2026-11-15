#version 330 compatibility

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normalW;
in float materialId;
in float smoothness;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 color0;
layout(location = 1) out vec4 data1;

void main() {
    vec4 color = texture2D(gtexture, texcoord) * glcolor;
    color.rgb *= texture2D(lightmap, lmcoord).rgb;

    if (color.a < 0.1) discard;

    color0 = vec4(color.rgb, 1.0);
    data1 = vec4(encodeNormal(normalize(normalW)), smoothness, materialId / 255.0);
}
