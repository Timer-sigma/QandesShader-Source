// Dexxa Shaders - shared functions
#ifndef COMMON_LIB
#define COMMON_LIB

// Octahedral normal encode/decode (2 octets in RG of colortex1)
vec2 encodeNormal(vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    vec2 e = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    return e * 0.5 + 0.5;
}

vec3 decodeNormal(vec2 e) {
    e = e * 2.0 - 1.0;
    vec3 n = vec3(e.xy, 1.0 - abs(e.x) - abs(e.y));
    float t = max(-n.z, 0.0);
    n.xy += vec2(n.x >= 0.0 ? -t : t, n.y >= 0.0 ? -t : t);
    return normalize(n);
}

// Procedural sky gradient (used as reflection fallback)
vec3 proceduralSky(vec3 dir, vec3 skyCol, vec3 fogCol, float sunAngle) {
    float up = clamp(dir.y, 0.0, 1.0);
    vec3 col = mix(fogCol, skyCol, pow(up, 0.6));
    // sun glow
    float sunVis = float(sunAngle < 0.5);
    vec3 sunDir = normalize(vec3(0.0, sin(sunAngle * 6.2831853), -cos(sunAngle * 6.2831853)));
    float d = max(dot(dir, sunDir), 0.0);
    col += vec3(1.0, 0.8, 0.5) * pow(d, 64.0) * 0.6 * sunVis;
    return col;
}

// Fresnel (Schlick)
float fresnelSchlick(float cosTheta, float F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// Simple ACES-inspired tonemap
vec3 tonemapACES(vec3 x) {
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// bayer 4x4 dither
float bayer4(vec2 p) {
    int x = int(mod(p.x, 4.0));
    int y = int(mod(p.y, 4.0));
    int i = int(mod(x + y * 4.0, 16.0));
    float m[16];
    m[0]=0.0;  m[1]=8.0;  m[2]=2.0;  m[3]=10.0;
    m[4]=12.0; m[5]=4.0;  m[6]=14.0; m[7]=6.0;
    m[8]=3.0;  m[9]=11.0; m[10]=1.0; m[11]=9.0;
    m[12]=15.0;m[13]=7.0; m[14]=13.0;m[15]=5.0;
    return (m[i] + 0.5) / 16.0;
}

#endif
