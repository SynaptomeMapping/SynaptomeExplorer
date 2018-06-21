#version 400

#define POINTSPRITES

#ifndef POINTSPRITES
layout(location = 0) in vec2 in_position;
#endif

uniform vec2 g_ViewCenter; // in tile unit coordinates
uniform vec2 g_ViewExtents; // this is based on zoom factor. in tile unit coordinates
uniform ivec2 g_TileNum; // the number of tiles in each direction. product of elements is the number of layers
uniform float g_PunctaScale; // think of it as megapixels-per-screen-pixel
uniform float g_PunctaOpacity;
uniform float g_Zoom = 1.0;
uniform samplerBuffer g_PointBuffer;
uniform int g_BufferOffset;

uniform int g_RenderMode = 0;
uniform vec4 g_FilterLow1;
uniform vec4 g_FilterLow2;
uniform vec4 g_FilterHigh1;
uniform vec4 g_FilterHigh2;
uniform uvec4 g_FilterAreaColocSubtypeProteinLow;
uniform uvec4 g_FilterAreaColocSubtypeProteinHigh;


uniform uvec4 g_TypeAndSubtypeMask = uvec4(0xffffffff);

#define YOKOGAWA_DATA

#ifdef YOKOGAWA_DATA
uniform uint g_FilterIntensityLow;
uniform uint g_FilterIntensityHigh;
uniform float g_FilterZLow;
uniform float g_FilterZHigh;
#else
uniform uvec4 g_FilterIntensityMinMaxMeanLow;
uniform uvec4 g_FilterIntensityMinMaxMeanHigh;
#endif

uniform float g_ProteinColorScales[4];
uniform float g_SubtypeColorScale = 1.0;

uniform float g_ColorizeBySubtype = 0.0;

uniform vec3 subtypeColors[37] = vec3[37](
vec3(0, 0, 1),
vec3(1, 0, 0),
vec3(0, 1, 0),
vec3(1, 0.103448275862069, 0.724137931034483),
vec3(1, 0.827586206896552, 0),
vec3(0, 0.517241379310345, 0.965517241379310),
vec3(0, 0.551724137931035, 0.275862068965517),
vec3(0.655172413793103, 0.379310344827586, 0.241379310344828),
vec3(0.310344827586207, 0, 0.413793103448276),
vec3(0, 1, 0.965517241379310),
vec3(0.241379310344828, 0.482758620689655, 0.551724137931035),
vec3(0.931034482758621, 0.655172413793103, 1),
vec3(0.827586206896552, 1, 0.586206896551724),
vec3(0.724137931034483, 0.310344827586207, 1),
vec3(0.896551724137931, 0.103448275862069, 0.344827586206897),
vec3(0.517241379310345, 0.517241379310345, 0),
vec3(0, 1, 0.586206896551724),
vec3(0.379310344827586, 0, 0.172413793103448),
vec3(0.965517241379310, 0.517241379310345, 0.0689655172413793),
vec3(0.793103448275862, 1, 0),
vec3(0.172413793103448, 0.241379310344828, 0),
vec3(0, 0.206896551724138, 0.758620689655172),
vec3(1, 0.793103448275862, 0.517241379310345),
vec3(0, 0.172413793103448, 0.379310344827586),
vec3(0.620689655172414, 0.448275862068966, 0.551724137931035),
vec3(0.310344827586207, 0.724137931034483, 0.0689655172413793),
vec3(0.620689655172414, 0.758620689655172, 1),
vec3(0.586206896551724, 0.620689655172414, 0.482758620689655),
vec3(1, 0.482758620689655, 0.689655172413793),
vec3(0.620689655172414, 0.0344827586206897, 0),
vec3(1, 0.724137931034483, 0.724137931034483),
vec3(0.517241379310345, 0.379310344827586, 0.793103448275862),
vec3(0.620689655172414, 0, 0.448275862068966),
vec3(0.517241379310345, 0.862068965517241, 0.655172413793103),
vec3(1, 0, 0.965517241379310),
vec3(0, 0.827586206896552, 1),
vec3(1, 0.448275862068966, 0.344827586206897));

out vec4 vars;
out vec4 var_color;

struct punctum_t
{
#ifdef YOKOGAWA_DATA
    float z;
    uint intensity;
#else
    uvec4 intensity_min_max_mean;
#endif
    uvec4 area_coloc_subtype_protein;
    vec4 stddev_circ_skew_kurt;
    vec4 ar_roundness_solidity_coloc;
    uvec2 pos;
};

#define CHECK_BIT(var,pos) ((var) & (1u<<(pos)))
bool CheckTypeAndSubtype( uint type, uint subtype0)
{
    uint t = g_TypeAndSubtypeMask.x & (1u << type);
    //return t > 0;
    // The first 32 subtypes are in .y component, the rest 5 are in .z component
    uint st = g_TypeAndSubtypeMask[1 + (subtype0 >> 5)] & (1u << (subtype0 & 31u));
    return min(t,st) > 0;
}

bool do_render(in punctum_t p)
{
    //return all(greaterThanEqual(p.stddev_circ_skew_kurt, g_FilterLow1)) &&
    //all(lessThanEqual(p.stddev_circ_skew_kurt, g_FilterHigh1)) &&
    //all(greaterThanEqual(p.ar_roundness_solidity_coloc.xyz, g_FilterLow2.xyz)) &&
    //all(lessThanEqual(p.ar_roundness_solidity_coloc.xyz, g_FilterHigh2.xyz));

    return CheckTypeAndSubtype(p.area_coloc_subtype_protein.w, p.area_coloc_subtype_protein.z-1) && all(greaterThanEqual(p.stddev_circ_skew_kurt, g_FilterLow1)) &&
    all(lessThanEqual(p.stddev_circ_skew_kurt, g_FilterHigh1)) &&
    all(greaterThanEqual(p.ar_roundness_solidity_coloc, g_FilterLow2)) &&
    all(lessThanEqual(p.ar_roundness_solidity_coloc, g_FilterHigh2)) &&
#ifdef YOKOGAWA_DATA
    (p.intensity >= g_FilterIntensityLow && p.intensity <= g_FilterIntensityHigh) &&
    (p.z >= g_FilterZLow && p.z <= g_FilterZHigh) &&
#else 
    all(greaterThanEqual(p.intensity_min_max_mean, g_FilterIntensityMinMaxMeanLow)) &&
    all(lessThanEqual(p.intensity_min_max_mean, g_FilterIntensityMinMaxMeanHigh)) &&
#endif
    all(greaterThanEqual(p.area_coloc_subtype_protein, g_FilterAreaColocSubtypeProteinLow)) &&
    all(lessThanEqual(p.area_coloc_subtype_protein, g_FilterAreaColocSubtypeProteinHigh));
}

float scan_offs_x[5] = float[5](6.5120, 1.3947, 3.2792, 0.3856, 0);
float scan_offs_y[5] = float[5](4.9854, 5.4490, 5.4503, 2.0471, 4.8825);

void parse_punctum(out punctum_t p, int offset)
{
    int off = (offset + g_BufferOffset)*3;
    
    vec4 v0f = texelFetch(g_PointBuffer, off + 0);
    uvec4 v0 = floatBitsToUint(v0f);
    p.stddev_circ_skew_kurt = texelFetch(g_PointBuffer, off + 1);
    p.ar_roundness_solidity_coloc = texelFetch(g_PointBuffer, off + 2);

    p.pos = uvec2(ivec2(v0.xy));// + 2*g_PunctaOffsets[int(p.ar_roundness_solidity_coloc.z)]);
#if 0
    {
        int scanid = int(p.ar_roundness_solidity_coloc.z);
        vec2 scanstart = 10000*vec2(scan_offs_x[scanid],scan_offs_y[scanid]);
        vec2 rel_to_scanstart = vec2(p.pos) - scanstart;
        vec2 mult = vec2(0.999, 0.995);
        p.pos = uvec2( scanstart + rel_to_scanstart * mult);
    }
#endif

#ifdef YOKOGAWA_DATA
    p.z = v0f.z;
    p.intensity = v0.w & 65535u;
#else
    p.intensity_min_max_mean.x = v0.z & 65535u;
    p.intensity_min_max_mean.y = v0.z >> 16u;
    p.intensity_min_max_mean.z = v0.w & 65535u;
#endif
    p.area_coloc_subtype_protein.x = (v0.w >> 16u) & 127u; // 7 bits
    p.area_coloc_subtype_protein.y = (v0.w >> 23u) & 1u; // 1 bits
    p.area_coloc_subtype_protein.z = (v0.w >> 24u) & 63u; // 6 bits
    p.area_coloc_subtype_protein.w = (v0.w >> 30u) & 3u; // 2 bits
    
#if 0 // found grid_ind bug using this. 
    // This is getting weirder. For the test melissa dataset, it looks like SAP behaves right with the below enabled, while PSD95 with the below disabled. Does that mean that the order in the text files can vary and I need to detect it? Would I detect it via the "filename" instead of the grid index?
    if(p.area_coloc_subtype_protein.w == 0)
    {
        uvec2 off256 = p.pos & 255u;
        uvec2 grididx = (p.pos >> 8) & 1;
        //grididx.x = 1u - grididx.x;
        grididx.xy = grididx.yx;
        p.pos = ((p.pos >> 9u) << 9u) + (grididx.xy << 8u) + off256;
    }
#endif
}

void main()
{
    
#ifdef POINTSPRITES
    vec2 in_position = vec2(0.0);
    int punctumId = gl_VertexID;
#else
    int punctumId = gl_InstanceID;
#endif
    
    vec2 pos = in_position;
    vars.xy = in_position;

    // position in tile coordinates
    vec2 corner0 = 512.0*(g_ViewCenter - g_ViewExtents*0.5);
    vec2 corner1 = 512.0*(g_ViewCenter + g_ViewExtents*0.5);

    punctum_t p;
    parse_punctum(p, punctumId);
    vec2 position = vec2(p.pos);
    //position.x -= 512.0;

    if(!do_render(p))
    {
        gl_Position = vec4(0.0);
        return;
    }

    float radius = sqrt(float(p.area_coloc_subtype_protein.x) / 3.14159);

    //float scale = 0.5*float( p.area_coloc_subtype_protein.x) ;//radius / min( g_Zoom, 1.0);
    float scale = radius * g_PunctaScale;
    vec2 wcs = position;// + scale * 0.5*in_position;
    vec2 sspos = 2.0*((wcs - corner0)/(corner1 - corner0)) - 1.0;
    sspos.y *= -1.0;

    // multiply intensity by 2 to match raw!
#ifdef YOKOGAWA_DATA
    vars.zw = vec2(2.0 * float(p.intensity) / 65535.0, radius);
    vars.z = mix(vars.z, 1.0, g_ColorizeBySubtype);
#else
    vars.zw = vec2(2.0 * float(p.intensity_min_max_mean.z) / 65535.0, radius);
#endif 
    uint subtype = p.area_coloc_subtype_protein.z;
    uint uprotein = p.area_coloc_subtype_protein.w;
    float protein = float(uprotein);
    vec4 proteinColor = vec4(1-protein, protein,1-protein,0.0);
    proteinColor.xyz *= g_ProteinColorScales[uprotein];

    proteinColor.xyz = mix(proteinColor.xyz, subtypeColors[subtype-1]* g_SubtypeColorScale, g_ColorizeBySubtype);
    float opacity = g_PunctaOpacity;
    
#ifdef POINTSPRITES
    float pointSize = scale * g_Zoom;
    gl_PointSize = max( pointSize, 1.0);
    // if real point size < 1, then adjust opacity. NOT FOR SUBTYPES
    opacity *= max( min(pointSize, 1.0), g_ColorizeBySubtype); 
#endif

    var_color = opacity * proteinColor;

    //vec2 pos = mix(corner0, corner1, uv);
    gl_Position = vec4(sspos,0.0,1);
}