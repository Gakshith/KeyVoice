#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The Aurora — the voice-light that lives inside the glass HUD. This is the native Metal port of the
// approved web preview: amplitude-driven flowing bands (listening), a caustic swirl (thinking), a
// pulse ring (done), tinting white->ice with volume and amber on failure. It returns premultiplied
// colour with alpha so the system glass shows through where the light is dark.

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float vnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1)), d = hash21(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float fbm(float2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { s += a * vnoise(p); p *= 2.0; a *= 0.5; }
    return s;
}

// The KeyVoice voice-spectrum ramp: violet -> blue -> cyan -> amber -> pink, left to right.
static float3 spectrum(float t) {
    const float3 c0 = float3(0.416, 0.298, 1.000);
    const float3 c1 = float3(0.298, 0.482, 1.000);
    const float3 c2 = float3(0.184, 0.816, 0.812);
    const float3 c3 = float3(1.000, 0.694, 0.306);
    const float3 c4 = float3(1.000, 0.361, 0.541);
    t = clamp(t, 0.0, 1.0) * 4.0;
    if (t < 1.0) return mix(c0, c1, t);
    if (t < 2.0) return mix(c1, c2, t - 1.0);
    if (t < 3.0) return mix(c2, c3, t - 2.0);
    return mix(c3, c4, t - 3.0);
}

[[ stitchable ]]
half4 aurora(float2 pos, half4 color,
             float2 size, float time, float level, float think, float done, float amber) {
    float2 uv = pos / size;              // 0..1
    float2 luv = (uv - 0.5) * 2.0;       // -1..1
    luv.x *= max(size.x / size.y, 1.0) * 0.5;  // ease horizontal stretch on a wide pill

    // Flowing bands, amplitude driven by voice level; calmed while thinking.
    float amp = (0.14 + level * 0.86) * (1.0 - 0.55 * think);
    float aur = 0.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float ph = time * (0.8 + fi * 0.45) + fi * 2.0;
        float y = sin(luv.x * 3.14159 * (1.0 + fi * 0.5) + ph) * amp * 0.55 + (fi - 1.0) * 0.34;
        aur += smoothstep(0.34, 0.0, abs(luv.y - y)) * (0.6 - fi * 0.12);
    }
    // Thinking: dissolve into a slow caustic swirl.
    float sw = fbm(luv * 3.0 + float2(time * 0.5, time * 0.3));
    aur = mix(aur, smoothstep(0.4, 0.9, sw) * 0.7, think);
    aur = clamp(aur, 0.0, 1.0);

    // Done: one confident pulse ring.
    float ring = 0.0;
    if (done > 0.001) {
        float rr = done * 0.9;
        ring = smoothstep(0.16, 0.0, abs(length(luv * float2(1.0, 1.8)) - rr)) * (1.0 - done);
    }

    // Colour: the voice spectrum across the pill, brightened toward white by volume; amber on failure.
    float3 base = mix(spectrum(uv.x), float3(1.0), level * 0.25);
    float3 tint = mix(base, float3(0.95, 0.72, 0.42), amber);

    float intensity = clamp(aur * (0.6 + level * 0.6) + ring * 0.9, 0.0, 1.0);
    float3 rgb = tint * intensity;
    float alpha = intensity;
    return half4(half3(rgb), half(alpha));   // premultiplied over the glass
}
