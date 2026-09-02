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

    // Colour: white -> ice with volume; amber on failure.
    float3 ice = mix(float3(1.0), float3(0.66, 0.85, 1.0), level);
    float3 tint = mix(ice, float3(0.92, 0.70, 0.45), amber);

    float intensity = clamp(aur * (0.6 + level * 0.6) + ring * 0.9, 0.0, 1.0);
    float3 rgb = tint * intensity;
    float alpha = intensity;
    return half4(half3(rgb), half(alpha));   // premultiplied over the glass
}
