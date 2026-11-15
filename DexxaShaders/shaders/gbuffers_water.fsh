#version 330 compatibility

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float frameTimeCounter;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normalW;
in vec3 viewPosW;
in float isWater;

/* RENDERTARGETS: 0,1 */
layout(location = 0) out vec4 color0;
layout(location = 1) out vec4 data1;

// procedural wave normal perturbation (3 octaves for realism)
vec3 waveNormal(vec3 n, vec3 vpos) {
    float t = frameTimeCounter * WATER_WAVE_SPEED;
    // large slow swell
    float w1 = sin(vpos.x * 1.4 + t * 1.1) + sin(vpos.z * 1.9 - t * 0.9);
    // medium ripples
    float w2 = sin(vpos.x * 3.3 - t * 1.9) + sin(vpos.z * 4.1 + t * 1.5);
    // fine detail
    float w3 = sin(vpos.x * 7.7 + t * 2.6) + sin((vpos.x + vpos.z) * 6.1 - t * 2.1);
    vec2 pert = vec2(w1 * 0.030 + w2 * 0.014 + w3 * 0.006,
                     w1 * 0.024 - w2 * 0.016 + w3 * 0.005);
    return normalize(vec3(n.xy + pert, n.z));
}

void main() {
    vec4 color = texture2D(gtexture, texcoord) * glcolor;
    color.rgb *= texture2D(lightmap, lmcoord).rgb;
    if (color.a < 0.01) discard;

    vec3 n = normalize(normalW);
    float smoothness = 0.0;
    float matId = 0.0;

    if (isWater > 0.5) {
        n = waveNormal(n, viewPosW);
        smoothness = 0.94;
        matId = 1.0;
        // realistic water tint: deeper blue-green, slightly less transparent
        vec3 waterTint = vec3(0.35, 0.62, 0.78);
        color.rgb = mix(color.rgb * 0.55, waterTint * color.rgb * 1.6, 0.45);
        color.a = max(color.a, 0.75);
    } else if (color.a > 0.9) {
        // glass / ice - lightly reflective
        smoothness = 0.6;
        matId = 2.0;
    }

    color0 = color;
    data1  = vec4(encodeNormal(n), smoothness, matId / 255.0);
}
