// -----------------------------------------------------------------------------
// Metaball Liquid Glass — merged multi-lens glass surface.
//
// This is a SEPARATE shader from the production liquid_glass.frag (which it
// never modifies). It reuses the SAME glass math by #including the shared
// helper libraries, so the merged blob refracts, rims and tints exactly like
// a real liquid-glass lens — the only difference is the silhouette:
//
//   * liquid_glass.frag  → one rounded-rect ShapeData.
//   * metaball_glass.frag → the smooth-union (polynomial smin) of up to six
//     rounded-rect ShapeData, so neighbouring lenses fuse with a liquid
//     bridge and the glass flows across the merged outline.
//
// Everything downstream of the silhouette — coverage AA, the distortion band,
// magnification, the refraction modes (shape / radial / optical) and the
// sweep border — is the production code, called through the same helpers.
//
// Copyright © 2025 Ahmed Gamil. Free to use in any project.
// -----------------------------------------------------------------------------

#include <flutter/runtime_effect.glsl>
#include "liquid_glass_common.glsl"
// Opt the shared border into the half-Lambert rim wrap for the MERGED shape.
// Single-lens shaders don't define this, so their border compiles unchanged.
#define LIQUID_GLASS_RIM_WRAP
#include "liquid_glass_border.glsl"
#define PI 3.14159265

precision highp float;

// =====================================================
// Uniforms
//
// IMPORTANT: the float-uniform DECLARATION ORDER below is the exact order
// `packMetaballGlassUniforms` writes them with `setFloat(i++, …)`. Keep the
// two in lockstep. The sampler does not consume a float index (it is bound
// via `setImageSampler(0, …)`), so it can sit anywhere.
// =====================================================
uniform vec2 u_resolution;
uniform sampler2D u_texture_input;

// Up to six lenses. u_lensN = (centerX, centerY, halfWidth, halfHeight) px.
uniform vec4 u_lens0;
uniform vec4 u_lens1;
uniform vec4 u_lens2;
uniform vec4 u_lens3;
uniform vec4 u_lens4;
uniform vec4 u_lens5;
// u_lensMetaN = (cornerRadius px, enabled[>0.5], unused, unused).
uniform vec4 u_lensMeta0;
uniform vec4 u_lensMeta1;
uniform vec4 u_lensMeta2;
uniform vec4 u_lensMeta3;
uniform vec4 u_lensMeta4;
uniform vec4 u_lensMeta5;

// Metaball blend radius in px (the "gooeyness").
uniform float u_smoothness;

// ── Shared glass block (same semantics as liquid_glass.frag) ──────────────
uniform float u_magnification;
uniform float u_distortion;
uniform float u_distortionThicknessPx;
uniform float u_enableBackgroundTransparency;
uniform float u_diagonalFlip;

uniform float u_borderWidth;
uniform float u_borderSoftness;
uniform vec4  u_borderColor;
uniform float u_borderAlpha;
uniform float u_lightIntensity;
uniform vec4  u_lightColor;
uniform vec4  u_shadowColor;
uniform float u_lightDirection;
uniform vec4  u_lensColor;
uniform float u_oneSideLightIntensity;
uniform float u_chromaticAberration;
uniform float u_saturation;
uniform float u_lightMode;
uniform float u_refractionMode;
uniform float u_refractionType;
uniform float u_refractionIndex;
uniform float u_ambientIntensity;
uniform float u_doubleSideLightIntensity;
uniform float u_borderSaturation;
uniform float u_borderSolidity;
uniform float u_borderMode;

// Capture-region mapping (see liquid_glass.frag). Full-frame capture =
// offset (0,0), size u_resolution.
uniform vec2 u_imageOffset;
uniform vec2 u_imageSize;

// 1.0 = fold the sampled backdrop's alpha into coverage (Skia capture);
// 0.0 = treat backdrop as opaque (Impeller live backdrop).
uniform float u_honorBackdropAlpha;

// In-shader blur radius in FRAGMENT px (0 = off). The single-lens pipeline
// blurs via a stacked BackdropFilter; the merged silhouette has no RRect to
// clip a BackdropFilter to, so the blur is done here (sampling the backdrop /
// captured image directly) which behaves identically on both backends.
uniform float u_blur;

// Edge-AA band width in FRAGMENT px (1.0 on Skia, dpr on Impeller). MUST be
// the last uniform — see packMetaballGlassUniforms.
uniform float u_shapeAaPx;

out vec4 frag_color;

#define REFRACTION_SHAPE    0
#define REFRACTION_RADIAL   1
#define REFRACTION_STANDARD 0
#define REFRACTION_OPTICAL  1

// Rim angular response for the MERGED shape. 0 = the production hard rim
// (front/back of the light axis, zero at 90°); 1 = half-Lambert wrap (0.5
// at 90°) so the concave neck — whose normals are perpendicular to the
// light — keeps a rim and the merged border stays connected. Tune 0..1.
#define METABALL_RIM_WRAP 1.0

// =====================================================
// Metaball field: smooth-union of the enabled lens SDFs
// =====================================================

// Polynomial smooth minimum — the metaball blend. As two SDFs come within ~k
// of each other their union grows a smooth bridge instead of a hard crease.
float smoothUnion(float a, float b, float k) {
    float kk = max(k, EPS);
    float h = clamp(0.5 + 0.5 * (b - a) / kk, 0.0, 1.0);
    return mix(b, a, h) - kk * h * (1.0 - h);
}

// One lens's signed distance.
//
// Always the EXACT rounded-rectangle SDF (|grad| ~ 1). The metaball
// smooth-union requires a true distance field to produce a correct bridge:
// the continuous/squircle corner SDFs carry a non-unit-gradient "shoulder"
// near their corners, which warps the blend so it stops following the
// outline. Circular corners blend cleanly at any radius, and a full-radius
// square is still a perfect circle.
float lensDistance(vec2 p, vec4 lens, vec4 meta) {
    vec2 halfSize = max(lens.zw, vec2(EPS));
    float r = min(meta.x, min(halfSize.x, halfSize.y));
    return roundedRectangleShape(p, lens.xy, halfSize, r);
}

float field(vec2 p) {
    float d = 1e9;
    if (u_lensMeta0.y > 0.5) d = smoothUnion(d, lensDistance(p, u_lens0, u_lensMeta0), u_smoothness);
    if (u_lensMeta1.y > 0.5) d = smoothUnion(d, lensDistance(p, u_lens1, u_lensMeta1), u_smoothness);
    if (u_lensMeta2.y > 0.5) d = smoothUnion(d, lensDistance(p, u_lens2, u_lensMeta2), u_smoothness);
    if (u_lensMeta3.y > 0.5) d = smoothUnion(d, lensDistance(p, u_lens3, u_lensMeta3), u_smoothness);
    if (u_lensMeta4.y > 0.5) d = smoothUnion(d, lensDistance(p, u_lens4, u_lensMeta4), u_smoothness);
    if (u_lensMeta5.y > 0.5) d = smoothUnion(d, lensDistance(p, u_lens5, u_lensMeta5), u_smoothness);
    return d;
}

// HARD union (plain min) of the enabled lenses — the silhouette WITHOUT the
// smooth bridge. The smooth union is always <= this, and the gap between them
// (`hard - smooth`) is exactly the bridge the smin grew: ~0 on an isolated
// lens, peaking at the neck. We use it to localize the rim `wrap` to the
// blend only, so separated lenses keep the original two-sided hard rim.
float fieldHard(vec2 p) {
    float d = 1e9;
    if (u_lensMeta0.y > 0.5) d = min(d, lensDistance(p, u_lens0, u_lensMeta0));
    if (u_lensMeta1.y > 0.5) d = min(d, lensDistance(p, u_lens1, u_lensMeta1));
    if (u_lensMeta2.y > 0.5) d = min(d, lensDistance(p, u_lens2, u_lensMeta2));
    if (u_lensMeta3.y > 0.5) d = min(d, lensDistance(p, u_lens3, u_lensMeta3));
    if (u_lensMeta4.y > 0.5) d = min(d, lensDistance(p, u_lens4, u_lensMeta4));
    if (u_lensMeta5.y > 0.5) d = min(d, lensDistance(p, u_lens5, u_lensMeta5));
    return d;
}

// Rim wrap localized to the blend: 0 where lenses are isolated (keep the
// production two-sided hard rim), ramping to METABALL_RIM_WRAP at the neck
// (half-Lambert so the concave bridge stays lit/connected). The bridge
// amount is `hard - smooth`, normalized by the smin's peak subtraction
// (~smoothness * 0.25).
float bridgeWrap(vec2 fragPx, float smoothSdf) {
    float bridge = fieldHard(fragPx) - smoothSdf;            // >= 0
    float t = clamp(bridge / max(u_smoothness * 0.25, EPS), 0.0, 1.0);
    return t * METABALL_RIM_WRAP;
}

// Merged ShapeData via the same 5-tap central-difference scheme as
// evaluateShape(), but over the smooth-union field.
ShapeData evaluateField(vec2 fragPx) {
    float h = 1.0;
    float fC  = field(fragPx);
    float fXp = field(fragPx + vec2(h, 0.0));
    float fXm = field(fragPx - vec2(h, 0.0));
    float fYp = field(fragPx + vec2(0.0, h));
    float fYm = field(fragPx - vec2(0.0, h));

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;
    return d;
}

// Influence-weighted centroid: the magnification / radial-light anchor that
// flows with the merged shape instead of snapping between fixed centers.
void accumulateAnchor(vec4 lens, vec4 meta, vec2 p, inout vec2 acc, inout float wsum) {
    if (meta.y < 0.5) return;
    float w = exp(-max(lensDistance(p, lens, meta), 0.0) / max(u_smoothness, EPS));
    acc  += lens.xy * w;
    wsum += w;
}

vec2 anchorFor(vec2 p) {
    vec2 acc = vec2(0.0);
    float wsum = 0.0;
    accumulateAnchor(u_lens0, u_lensMeta0, p, acc, wsum);
    accumulateAnchor(u_lens1, u_lensMeta1, p, acc, wsum);
    accumulateAnchor(u_lens2, u_lensMeta2, p, acc, wsum);
    accumulateAnchor(u_lens3, u_lensMeta3, p, acc, wsum);
    accumulateAnchor(u_lens4, u_lensMeta4, p, acc, wsum);
    accumulateAnchor(u_lens5, u_lensMeta5, p, acc, wsum);
    return (wsum > EPS) ? acc / wsum : p;
}

// =====================================================
// Background sampling (CA + optional in-shader blur), saturation, tint —
// mirrors liquid_glass.frag's finalSample.
// =====================================================
vec2 refractedToUv(vec2 refractedPx) {
    vec2 uv = clamp((refractedPx - u_imageOffset) / u_imageSize,
                    vec2(0.001), vec2(0.999));
    #ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
    #endif
    return uv;
}

vec3 sampleChroma(vec2 uv, float shift) {
    vec3 color = texture(u_texture_input, uv).rgb;
    if (shift < 0.001) return color;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    vec2 offset = vec2(shift * luma);
    float r = texture(u_texture_input, uv + offset).r;
    float g = texture(u_texture_input, uv).g;
    float b = texture(u_texture_input, uv - offset).b;
    return vec3(r, g, b);
}

vec3 sampleBackground(vec2 refractedPx, float caShift) {
    vec2 uv = refractedToUv(refractedPx);
    if (u_blur < 0.5) return sampleChroma(uv, caShift);
    // Two-ring blur in px space, converted to UV via u_imageSize.
    vec2 pxToUv = 1.0 / max(u_imageSize, vec2(EPS));
    vec3 color = sampleChroma(uv, caShift);
    float count = 1.0;
    for (int ring = 1; ring <= 2; ring++) {
        float radius = u_blur * float(ring) * 0.5;
        for (int tap = 0; tap < 6; tap++) {
            float angle = 6.2831853 * float(tap) / 6.0 + float(ring) * 0.5;
            vec2 duv = vec2(cos(angle), sin(angle)) * radius * pxToUv;
            color += sampleChroma(clamp(uv + duv, vec2(0.001), vec2(0.999)), caShift);
            count += 1.0;
        }
    }
    return color / count;
}

vec3 applySaturation(vec3 color, float saturation) {
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(vec3(luminance), color, saturation);
}

vec4 finalSample(vec2 refractedPx, float shapeMask, float caShift, out vec3 preTintColor) {
    vec3 refrColor = sampleBackground(refractedPx, caShift);
    refrColor = applySaturation(refrColor, u_saturation);
    preTintColor = refrColor;

    vec2 uv = refractedToUv(refractedPx);
    float texA = (u_honorBackdropAlpha > 0.5) ? texture(u_texture_input, uv).a : 1.0;
    float coverage = shapeMask * texA;

    vec4 base = vec4(refrColor * shapeMask, coverage);
    base.rgb = applyLensTint(base.rgb, shapeMask, u_lensColor, u_borderAlpha);
    return base;
}

float computeShapeMask(float shapeDistPx) {
    float aa = max(u_shapeAaPx, 1.0);
    return 1.0 - smoothstep(-0.5 * aa, 0.5 * aa, shapeDistPx);
}

// =====================================================
// Main
// =====================================================
void main() {
    vec2 fragPx   = FlutterFragCoord().xy;
    float invResY = 1.0 / u_resolution.y;
    vec2 uvNorm   = fragPx * invResY;

    // Merged silhouette + flowing anchor.
    ShapeData shapeData = evaluateField(fragPx);
    float shapeDistPx   = shapeData.orthoDist;
    float shapeMask     = computeShapeMask(shapeDistPx);

    // Rim wrap only at the blend neck; 0 on isolated lenses.
    float rimWrap = bridgeWrap(fragPx, shapeData.sdf);

    vec2 anchorPx   = anchorFor(fragPx);
    vec2 anchorNorm = anchorPx * invResY;

    float distAbsPx = abs(shapeDistPx);
    float zoneLimit = u_distortionThicknessPx;
    float zoneMask  = step(distAbsPx, zoneLimit);

    vec2 magPx = applyLensMagnification(fragPx, anchorPx, u_magnification);

    if (zoneMask < 0.5) {
        // Outside the distortion band — straight magnified sample + border.
        vec3 preTintCol = vec3(0.0);
        vec4 base = (u_enableBackgroundTransparency > 0.5)
            ? vec4(0.0)
            : finalSample(magPx, shapeMask, 0.0, preTintCol);

        vec4 borderPremul = getSweepBorder(
            uvNorm, anchorNorm, shapeData.orthoDist, shapeData.grad,
            u_borderWidth, u_borderSoftness, u_borderColor,
            u_lightColor, u_shadowColor,
            u_lightIntensity, u_borderAlpha, u_lightDirection,
            u_oneSideLightIntensity, u_lightMode,
            preTintCol, u_ambientIntensity,
            u_doubleSideLightIntensity,
            u_borderSaturation, u_borderSolidity, u_borderMode,
            rimWrap
        );

        frag_color = overlayPremul(base, borderPremul, u_borderMode);
        return;
    }

    float zoneT = 1.0 - clamp(distAbsPx / max(zoneLimit, EPS), 0.0, 1.0);

    vec2 refrPx;
    if (u_refractionType == REFRACTION_OPTICAL) {
        vec2 opticalNormal = shapeData.normal;
        if (u_refractionMode == REFRACTION_RADIAL) {
            vec2 radial = magPx - anchorPx;
            float radialLength = length(radial);
            if (radialLength > EPS) opticalNormal = radial / radialLength;
        }
        refrPx = computeRefractedPosition(
            magPx, opticalNormal, shapeData.sdf,
            u_distortionThicknessPx, u_refractionIndex, zoneT
        );
    } else if (u_refractionMode == REFRACTION_SHAPE) {
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        refrPx = computeShapeRefraction(
            magPx, shapeData.normal, shapeData.sdf,
            u_distortionThicknessPx, distortionFactor,
            u_magnification, u_diagonalFlip, zoneT
        );
    } else {
        float distortionFactor = computeDistortionFactor(u_distortion, zoneT);
        refrPx = refractFromAnchorPx(
            magPx, anchorPx, distortionFactor,
            u_magnification, u_diagonalFlip, zoneT
        );
    }

    vec3 preTintCol2 = vec3(0.0);
    float caShift = u_chromaticAberration * zoneT;
    vec4 base = finalSample(refrPx, shapeMask, caShift, preTintCol2);

    vec4 borderPremul = getSweepBorder(
        uvNorm, anchorNorm, shapeData.orthoDist, shapeData.grad,
        u_borderWidth, u_borderSoftness, u_borderColor,
        u_lightColor, u_shadowColor,
        u_lightIntensity, u_borderAlpha, u_lightDirection,
        u_oneSideLightIntensity, u_lightMode,
        preTintCol2, u_ambientIntensity,
        u_doubleSideLightIntensity,
        u_borderSaturation, u_borderSolidity, u_borderMode,
        rimWrap
    );

    frag_color = overlayPremul(base, borderPremul, u_borderMode);
}
