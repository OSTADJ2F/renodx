#version 450
#extension GL_EXT_scalar_block_layout : require

#include "./scene_tonemap.slangi"

// Baseline 1:1 of Switch 2 guest HDR output shader 0x5B009ED7:
// scene + UI -> 64^3 display LUT (built by the game, includes PQ) -> output.
// c6.data[2]: <0 test patterns, 0/1 LUT path, >1 LUT bypass. c6.data[1]: colour-blind matrix.
// c6.data[8] low/high 16 bits: output width/height. The original aliases c1/c6 with
// u16/s16/u32/f32 views; this reads the same bytes through one uint/float view each.

layout(set = 0, binding = 0, scalar) uniform fs_cbuf_block_4f
{
    float data[16384];
} c1;

layout(set = 0, binding = 1, scalar) uniform fs_cbuf_block_4u
{
    uint data[16384];
} c6;

layout(set = 0, binding = 2) uniform sampler2D fs_tex2_70;
layout(set = 0, binding = 3) uniform sampler3D fs_tex2_80;

layout(push_constant, scalar) uniform ResolutionInfo
{
    uint rescaling_textures[4];
    uint rescaling_images[2];
    float down_factor;
} rescaling_push_constants;

layout(location = 0) in vec4 in_attr0;
layout(location = 0) out vec4 frag_color0;

// CUSTOM: NaN and negatives become 0, +inf is capped at half-float max (scene buffer is RGBA16F).
float SanitizeScene(float x)
{
    return isnan(x) ? 0.0 : clamp(x, 0.0, 65504.0);
}

// Matches SPIR-V NMax/NMin: NaN becomes the non-NaN operand (0).
float NanClamp01(float x)
{
    return isnan(x) ? 0.0 : clamp(x, 0.0, 1.0);
}

void main()
{
    float _inv_w = 1.0 / gl_FragCoord.w;
    precise float _u = _inv_w * (in_attr0.x * gl_FragCoord.w);
    precise float _v = _inv_w * (in_attr0.y * gl_FragCoord.w);
    vec4 _tex = texture(fs_tex2_70, vec2(_u, _v));
    int mode = int(c6.data[2u]);
    int blind = int(c6.data[1u]);

    float px = gl_FragCoord.x * rescaling_push_constants.down_factor;
    float py = gl_FragCoord.y * rescaling_push_constants.down_factor;
    float width = float(c6.data[8u] & 65535u);
    float height = float(c6.data[8u] >> 16u);

    if (mode == -1) {
        precise float _fx = (px * 4.0) * (1.0 / width);
        precise float _fy = (py * 4.0) * (1.0 / height);
        if (isnan(_fx)) _fx = 0.0;
        if (isnan(_fy)) _fy = 0.0;
        uint _x = uint(max(trunc(min(_fx, 4294967040.0)), 0.0)) | (_fx >= 4294967296.0 ? 4294967295u : 0u);
        uint _y = uint(max(trunc(min(_fy, 4294967040.0)), 0.0)) | (_fy >= 4294967296.0 ? 4294967295u : 0u);
        precise float _g = c1.data[(((_y << 2u) + _x) << 2u) >> 2u] * 0.000977517106;
        frag_color0 = vec4(_g, _g, _g, 1.0);
        return;
    }
    if (mode == -2) {
        precise float _g = (px * 9.77517128) * (1.0 / width);
        frag_color0 = vec4(_g, _g, _g, 1.0);
        return;
    }
    if (mode == -3) {
        precise float _g = (px * 0.977517128) * (1.0 / width);
        frag_color0 = vec4(_g, _g, _g, 1.0);
        return;
    }
    if (mode == -4) {
        precise float _ramp = px * (1.0 / width);
        float _g;
        if (!(py >= 16.0)) {
            _g = (_ramp <= fma(uintBitsToFloat(c6.data[7u]), 2.5, -2.0)) ? 1.0 : 0.0;
        } else {
            precise float _s = _ramp * 59.5208015;
            float _oetf;
            if (!(_s <= 0.0179999992)) {
                _oetf = fma(exp2(log2(abs(_s)) * 0.449999988), 1.09899998, -0.0989999995);
            } else {
                _oetf = _ramp * 267.843597;
            }
            precise float _gamma = uintBitsToFloat(c6.data[7u]) * 2.4000001;
            _g = exp2(_gamma * log2(abs(_oetf))) * 0.00977517106;
        }
        frag_color0 = vec4(_g, _g, _g, 1.0);
        return;
    }
    if (mode == -5) {
        precise float _ramp = px * (1.0 / width);
        if (!(py >= 16.0)) {
            precise float _limit = uintBitsToFloat(c6.data[5u]) * 10.0;
            float _g = (_ramp <= _limit) ? 1.0 : 0.0;
            frag_color0 = vec4(_g, _g, _g, 1.0);
            return;
        }
        precise float _cell_x = _ramp * 8.0;
        precise float _cell_y = (py * 8.0) * (1.0 / height);
        float _frac_x = _cell_x + (-floor(_cell_x));
        float _frac_y = _cell_y + (-floor(_cell_y));
        int _ix = isnan(_cell_x) ? 0 : int(min(max(trunc(_cell_x), -2147483648.0), 2147483648.0));
        int _iy = isnan(_cell_y) ? 0 : int(min(max(trunc(_cell_y), -2147483648.0), 2147483648.0));
        float _g = 0.0;
        if (!(abs(_frac_y - 0.5) > 0.25 || abs(_frac_x - 0.5) > 0.25)) {
            _g = fma(float((_iy << 3) + _ix), 0.000977517106, uintBitsToFloat(c6.data[5u]));
        }
        frag_color0 = vec4(_g, _g, _g, 1.0);
        return;
    }

    vec3 _color = _tex.rgb;
    if (mode == 0 || mode == 1) {
        precise float _lr = log2(fma(_tex.x, 912.838501, 1.0)) * 0.0595238134;
        precise float _lg = log2(fma(_tex.y, 912.838501, 1.0)) * 0.0595238134;
        precise float _lb = log2(fma(_tex.z, 912.838501, 1.0)) * 0.0595238134;
        _color = texture(fs_tex2_80, vec3(_lr, _lg, _lb)).xyz;
        if (RENODX_TONE_MAP_TYPE != RENODX_TONE_MAP_TYPE_VANILLA) {
            // CUSTOM: PsychoV35 replaces the display LUT; the LUT output above is the hue/chroma reference.
            vec3 _scene = vec3(SanitizeScene(_tex.x), SanitizeScene(_tex.y), SanitizeScene(_tex.z));
            vec3 _ref = texture(fs_tex2_80, log2(fma(_scene, vec3(912.838501), vec3(1.0))) * 0.0595238134).xyz;
            _color = ApplyPsychoV35PQ(_scene, SanitizeScene(_tex.w), _ref);
        }
    }

    float R = NanClamp01(_color.x);
    float G = NanClamp01(_color.y);
    float B = NanClamp01(_color.z);
    vec3 _out = vec3(R, G, B);

    if (mode != 0) {
        if (blind == 3) {
            precise float _a = G * 0.0940800831;
            precise float _b = G * 0.880087137;
            precise float _c = G * 0.954257727;
            precise float _d = fma(R, 0.991885245, _a);
            precise float _e = fma(R, 0.0103428941, _b);
            precise float _f = fma(R, -0.0823079124, _c);
            _out = vec3(fma(B, -0.0859676227, _d), fma(B, 0.10957285, _e), fma(B, 0.128027633, _f));
        } else if (blind == 2) {
            precise float _a = G * 0.537387192;
            precise float _b = G * 0.55702126;
            precise float _c = G * 0.0117227379;
            precise float _d = fma(R, 0.442539424, _a);
            precise float _e = fma(R, 0.459525615, _b);
            precise float _f = fma(R, -0.0121606272, _c);
            _out = vec3(fma(B, 0.020139629, _d), fma(B, -0.0166014954, _e), fma(B, 1.00043929, _f));
        } else if (blind == 1) {
            precise float _a = G * 0.799202323;
            precise float _b = G * 0.828885734;
            precise float _c = G * 0.00452826964;
            precise float _d = fma(R, 0.170944571, _a);
            precise float _e = fma(R, 0.177506015, _b);
            precise float _f = fma(R, -0.00469741924, _c);
            _out = vec3(fma(B, 0.0299516693, _d), fma(B, -0.00641283346, _e), fma(B, 1.00016975, _f));
        }
    } else {
        if (blind == 3) {
            precise float _a = G * 0.873909295;
            precise float _b = fma(G, 0.127398878, R);
            precise float _c = fma(R, 2.53536259e-09, _a);
            precise float _d = fma(R, 3.26433192e-09, _a);
            _out = vec3(fma(B, -0.127398849, _b), fma(B, 0.126090705, _c), fma(B, 0.126090705, _d));
        } else if (blind == 2) {
            precise float _a = G * 0.669339955;
            precise float _b = G * 0.0278553758;
            precise float _c = fma(R, 0.330660075, _a);
            precise float _d = fma(R, -0.0278553814, _b);
            precise float _e = B + _d;
            _out = vec3(fma(B, 1.05125331e-08, _c), fma(B, 4.39522641e-09, _c), _e);
        } else if (blind == 1) {
            precise float _a = R * 0.170556992;
            precise float _b = G * 0.00451713707;
            precise float _c = fma(G, 0.829443038, _a);
            precise float _d = fma(G, 0.829442978, _a);
            precise float _e = fma(R, -0.00451714173, _b);
            precise float _f = B + _e;
            _out = vec3(fma(B, 7.65392283e-09, _c), fma(B, 3.34409545e-09, _d), _f);
        }
    }

    frag_color0 = vec4(NanClamp01(_out.x), NanClamp01(_out.y), NanClamp01(_out.z), 1.0);
}
