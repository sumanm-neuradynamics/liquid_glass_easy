// -----------------------------------------------------------------------------
// Copyright © 2025 Ahmed Gamil
//
// Free to use in any project.
// If you find this useful, a small credit would be appreciated.
// -----------------------------------------------------------------------------

#ifndef LIQUID_GLASS_HELPER_GLSL
#define LIQUID_GLASS_HELPER_GLSL

precision highp float;
#define PI 3.14159265

/* ===========================
   CONSTS / SMALL HELPERS
   =========================== */
const float EPS   = 1e-6;
const float EPS_T = 1e-3;

vec2  safe2(vec2 v){ return max(v, vec2(EPS)); }
float safe1(float v){ return max(v, EPS); }

float fastPow(float x, float n){ return exp2(n * log2(x)); }

/* ===========================
   SHAPE DATA
   =========================== */
struct ShapeData {
    float sdf;
    vec2  grad;
    vec2  normal;
    float orthoDist;
};

/* ===========================
   ROUNDED RECTANGLE SDF
   =========================== */
float roundedRectangleShape(vec2 p, vec2 c, vec2 h, float r){
    vec2 q = abs(p - c) - h + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

/* ===========================
   CONTINUOUS ROUNDED RECTANGLE (Apple-style corners)
   ---------------------------------------------------
   Same construction as the rounded rect, but the corner occupies a
   WIDER zone than the visual radius (Apple's continuous corners run
   ~1.528 × r along each edge) and uses an Ln-norm profile instead of
   the circular L2. `zone` is the corner-zone size in px and `n` the
   Ln exponent; both are derived ONCE per fragment from (radius,
   smoothing) by the caller — see the .frag shape branches. When
   zone == r and n == 2 this reduces exactly to the circular rounded
   rect, which is also the automatic full-radius (capsule) limit.
   =========================== */
float continuousRoundedRectShape(vec2 p, vec2 c, vec2 h, float zone, float n){
    vec2 q = abs(p - c) - h + zone;
    vec2 m = max(q, vec2(EPS));
    float corner = fastPow(fastPow(m.x, n) + fastPow(m.y, n), 1.0 / n) - zone;
    return min(max(q.x, q.y), 0.0) + corner;
}

/* ===========================
   SHARED: Evaluate SDF + gradient (rounded rectangle)
   =========================== */
ShapeData evaluateShape(
    vec2 fragPx,
    vec2 centerPx,
    vec2 halfSizePx,
    float radius
){
    float h = 1.0;

    float fC  = roundedRectangleShape(fragPx,                  centerPx, halfSizePx, radius);
    float fXp = roundedRectangleShape(fragPx + vec2(h,0.0),    centerPx, halfSizePx, radius);
    float fXm = roundedRectangleShape(fragPx - vec2(h,0.0),    centerPx, halfSizePx, radius);
    float fYp = roundedRectangleShape(fragPx + vec2(0.0,h),    centerPx, halfSizePx, radius);
    float fYm = roundedRectangleShape(fragPx - vec2(0.0,h),    centerPx, halfSizePx, radius);

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL  = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;

    return d;
}

/* ===========================
   Continuous-corner zone + exponent from (radius, smoothing).
   ---------------------------------------------------
   smoothing 0 → zone = r, n = 2 (plain circular corner).
   smoothing 1 → zone = 1.528 r (Apple's continuous-corner extension),
   n ≈ 3.26 chosen so the curve passes through the SAME apex point as
   the circular corner of radius r — the perceived radius stays r.
   The zone is clamped to the shorter half-side, so as the radius
   approaches full (capsule) the zone collapses back to r and n → 2:
   a smooth degradation to a circular cap, exactly like iOS/Figma.
   Returns vec2(zone, n).
   =========================== */
vec2 continuousCornerParams(float r, float smoothing, float maxCorner){
    // Corner zone, clamped by the shorter half-side. As the radius
    // approaches the maximum the zone collapses back to r and the
    // exponent below lands exactly on n = 2 — the smoothing fades out
    // and the shape returns to the PLAIN rounded rectangle (a clean
    // capsule at full radius), matching iOS/Figma behavior.
    float zone  = min(r * (1.0 + 0.528 * smoothing), maxCorner);
    // Solve  1 - 2^(-1/n) = (1 - 1/sqrt(2)) * r / zone  for n, so the
    // Ln corner's 45° apex coincides with the circular corner's apex.
    float base  = 1.0 - 0.29289322 * (r / max(zone, EPS));
    float n     = -1.0 / log2(clamp(base, 0.5, 1.0 - EPS));
    return vec2(zone, n);
}

/* ===========================
   Evaluate SDF + gradient for the CONTINUOUS ROUNDED RECT.
   Same 5-tap central-difference scheme as evaluateShape; kept
   separate because it needs both the zone size AND the exponent.
   =========================== */
ShapeData evaluateContinuousRRect(
    vec2 fragPx,
    vec2 centerPx,
    vec2 halfSizePx,
    float zone,
    float n
){
    float h = 1.0;
    float fC  = continuousRoundedRectShape(fragPx,               centerPx, halfSizePx, zone, n);
    float fXp = continuousRoundedRectShape(fragPx + vec2(h,0.0), centerPx, halfSizePx, zone, n);
    float fXm = continuousRoundedRectShape(fragPx - vec2(h,0.0), centerPx, halfSizePx, zone, n);
    float fYp = continuousRoundedRectShape(fragPx + vec2(0.0,h), centerPx, halfSizePx, zone, n);
    float fYm = continuousRoundedRectShape(fragPx - vec2(0.0,h), centerPx, halfSizePx, zone, n);

    vec2 grad = 0.5 * vec2(fXp - fXm, fYp - fYm);
    float gL  = max(length(grad), EPS);

    ShapeData d;
    d.sdf       = fC;
    d.grad      = grad;
    d.normal    = grad / gL;
    d.orthoDist = fC / gL;
    return d;
}

/* ===========================
   SHARED CORE: REFRACTION FROM ANCHOR
   =========================== */
vec2 refractFromAnchorPx(
    vec2 frag,
    vec2 anchor,
    float df,
    float mag,
    float flip,
    float t
){
    vec2 v = frag - anchor;
    float s = max(df, EPS);
    vec2 refr = anchor + v / s;

    float k = smoothstep(1.0 - flip, 1.0, t);
    vec2 flipped = anchor - (refr - anchor);

    return mix(refr, flipped, k);
}

/* ===========================
   Unified Anchor Helper
   =========================== */
vec2 computeInsetAnchor(vec2 fragPx, vec2 normal, float sdf, float insetPx){
    return fragPx - normal * (sdf + insetPx);
}

/* ===========================
   DISTORTION FACTOR
   =========================== */
float computeDistortionFactor(float u_distortion, float t){
    float d = clamp(u_distortion,0.0,1.0) * 100.0;
    return 1.0 + d * pow(t, d);
}
//float computeDistortionFactor(float u_distortion, float zoneT) {
//    // clamp distortion input
//    float distortionClamped = clamp(u_distortion, 0.0, 1.0);
//    float distortionStrength = distortionClamped * 100.0;
//
//
//    // --- stronger curve (outer edge emphasis)
//    //float edgeFactorStrongCurve = pow(zoneT, distortionStrength) * 0.5;
//    float edgeFactorStrongCurve = pow(zoneT, distortionStrength);
//
//    float distortionStrong = 1.0 + distortionStrength * edgeFactorStrongCurve;
//
//    // --- softer curve (inner falloff)
//    float edgeFactorSoftCurve = pow(zoneT, 5.0) * 0.08;
//    float distortionSoft = 1.0 + distortionStrength * edgeFactorSoftCurve;
//
//    // --- combined result
//    float distortionFactor = distortionStrong + (distortionSoft - 1.0);
//    //float distortionFactor = distortionStrong;
//
//    return distortionFactor;
//}

/* ===========================
   FINAL UNIFIED REFRACTION (PX)
   =========================== */
vec2 computeShapeRefraction(
    vec2 fragPx,
    vec2 normal,
    float sdf,
    float insetPx,
    float distortionFactor,
    float magnification,
    float diagonalFlip,
    float zoneT
){
    vec2 anchor = computeInsetAnchor(fragPx, normal, sdf, insetPx);
    return refractFromAnchorPx(
        fragPx,
        anchor,
        distortionFactor,
        magnification,
        diagonalFlip,
        zoneT
    );
}

/* ===========================
   PHYSICAL REFRACTION (Snell's law via a 3D surface normal)
   ---------------------------------------------------------
   Lifts the 2D SDF gradient into a 3D normal that faces the viewer
   deep inside the glass and tilts outward at the edge, then bends the
   incident ray with refract() and displaces the sample by its
   screen-space part.

   Displacement strength = thickness * distortion (the public lens
   `distortion` parameter, 0..1), tunable from Dart with no shader
   edit. REFRACTION_DEPTH_SCALE is an extra global multiplier (1.0).
   =========================== */
#ifndef REFRACTION_DEPTH_SCALE
#define REFRACTION_DEPTH_SCALE 1.0
#endif

vec2 computeRefractedPosition(
    vec2 fragPx,
    vec2 normal2D,
    float sdf,
    float thickness,
    float refractiveIndex,
    float distortion,
    float zoneT
){
    // 2D gradient -> 3D surface normal.
    float h     = clamp(-sdf / max(thickness, EPS), 0.0, 1.0);
    float bulge = sqrt(max(1.0 - h * h, 0.0));
    vec3  normal3D = normalize(vec3(normal2D * bulge, h));

    // Incident ray straight into the screen.
    vec3  I   = vec3(0.0, 0.0, -1.0);
    float eta = 1.0 / max(refractiveIndex, EPS);

    vec3 refr = refract(I, normal3D, eta);

    // Displace by the refracted ray's screen-space (xy) component.
    float depth = thickness * distortion * 5*REFRACTION_DEPTH_SCALE * zoneT;
    return fragPx + refr.xy * depth;
}

vec2 applyLensMagnification(
    vec2 fragPx,
    vec2 lensCenterPx,
    float magnification
){
    float m = max(magnification, 0.001);
    return lensCenterPx + (fragPx - lensCenterPx) / m;
}

/* ===========================
   TINT
   =========================== */
vec3 applyLensTint(vec3 base, float mask, vec4 color, float borderAlpha){
    return (color.a > 0.001 && mask > 0.001)
        ? mix(base, color.rgb, color.a * borderAlpha * mask)
        : base;
}

#endif
