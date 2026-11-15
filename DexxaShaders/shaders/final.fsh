#version 330 compatibility

#include "/lib/settings.glsl"
#include "/lib/common.glsl"

uniform sampler2D colortex0;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;

#ifdef ENABLE_TONEMAP
    color = tonemapACES(color * 1.05);
#endif

    // saturation
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, SATURATION);

#if VIGNETTE > 0.0
    vec2 uv = texcoord - 0.5;
    float vig = 1.0 - dot(uv, uv) * VIGNETTE * 2.0;
    color *= clamp(vig, 0.0, 1.0);
#endif

    // subtle dither to avoid banding
    color += (bayer4(gl_FragCoord.xy) - 0.5) / 255.0;

    outColor = vec4(color, 1.0);
}
