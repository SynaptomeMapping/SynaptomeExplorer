#version 430

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
layout(rgba8, binding = 0) uniform image2D img_output;

uniform sampler2D g_Montage;

uniform vec2 g_ViewCenter; // in tile unit coordinates
uniform vec2 g_ViewExtents; // this is based on zoom factor. in tile unit coordinates
uniform ivec2 g_TileNum; // the number of tiles in each direction. product of elements is the number of layers
uniform ivec2 g_RenderOffset;
uniform int g_Minimap;
uniform vec2 g_DispatchDenom;

uniform usampler2D g_MaskTexture;
uniform uint g_MaskParent = 704;
uniform uint g_MaskLevelBitOffset = 0;
uniform uint g_MaskLevelBitCount = 4;
uniform uint g_MaskLevelSelectionMask = 15;
uniform float g_TotalTime = 0.0;

uniform float g_TextureLod = 0.0;
uniform float g_ColorScale = 1.0;
uniform bool g_ShowMaskOutlines = true;
uniform float g_ColorizeBySubtype = 1.0;

#define YOKOGAWA

vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, vec3(0.0), vec3(1.0)), vec3(c.y));
}


void main() {
  // get index in global work group i.e x,y position
  ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
  
  vec2 maskTexStep = 1.0 / vec2(textureSize(g_MaskTexture,0).xy);

  // uv in [0,1]
  vec2 uv = (0.5 + vec2(pixel_coords)) * g_DispatchDenom;
  uv.y = 1.0 - uv.y;

  // position in tile coordinates
  vec2 corner0 = g_ViewCenter - g_ViewExtents*0.5;
  vec2 corner1 = g_ViewCenter + g_ViewExtents*0.5;
  vec2 pos = mix(corner0, corner1, uv);
  pos = mix(pos, uv*g_TileNum, float(g_Minimap));

  // calculate the tile index and the offset inside
  ivec2 tile_idx2d = ivec2(floor(pos));
  vec2 tile_offset = fract(pos);

  float in_bounds = ( (tile_idx2d.x >= 0) && (tile_idx2d.x < g_TileNum.x) && (tile_idx2d.y >= 0) && (tile_idx2d.y < g_TileNum.y)) ? 1.0 : 0.0;

  //tile_offset.y = 1.0 - tile_offset.y;

  // calculate the layer where this tile is stored in
  //int tileIdx1d = clamp( tile_idx2d.x + tile_idx2d.y*g_TileNum.x, 0, g_TileNum.x *g_TileNum.y-1);
  vec4 color;


    //vec2 mtcoords = pos * g_SmallTileSize;
    
    // below was for sparsetex
    //ivec2 bigtile_idx = ivec2(mtcoords / g_BigTileSize);
    //int layer = bigtile_idx.x + g_BigTileNum.x*bigtile_idx.y;
    //tile_offset = (mtcoords - bigtile_idx*g_BigTileSize)/g_BigTileSize;
    //color = textureLod( g_SparseTexture, vec3(tile_offset,layer),g_TextureLod);
    
    vec2 sample_uv = pos / vec2(g_TileNum);
    vec2 mask_uv = pos / vec2(g_TileNum);

#ifdef YOKOGAWA // YOKOGAWA CORRECTION
    {
        // now adjust sample_uv based on the difference of tile_num*32 and actual image dimensions!
        vec2 uv_scale = vec2(g_TileNum*32) / vec2(textureSize(g_Montage,0)) ;
        sample_uv *= uv_scale;
        mask_uv *= uv_scale;
    }
#endif
    color = textureLod( g_Montage, sample_uv, g_TextureLod);

    #if 1
    vec3 delin_boundaries = vec3(0.0);
    if(g_Minimap == 0 && g_ShowMaskOutlines)
    {
        uvec4 val = textureGather( g_MaskTexture, mask_uv);
        val.xy ^= val.zw;
        val.x |= val.y;
        
        #ifndef YOKOGAWA
        if( g_TextureLod > 4.0)
        {
            for(int i=0; i<9;++i)
            {
                int xoff = (i%3)-1;
                int yoff = (i/3)-1;
                uvec4 val2 = textureGather( g_MaskTexture, mask_uv + 0.75*(g_TextureLod - 4.0)*maskTexStep*vec2(xoff,yoff));
                val2.xy ^= val2.zw;
                val2.x |= val2.y;
                val.x |= val2.x;
            }
            
        }
        #endif
        
        if(val.x != 0u)
        {
            delin_boundaries = vec3(1.0);
            color = vec4(delin_boundaries,1.0);
        }
    }
    #else
    
    
    if(g_Minimap == 0 && g_ShowMaskOutlines)
    {
        uvec4 mask_all = textureGather( g_MaskTexture, vec3(mask_uv,0), 0);
        mask_all |= textureGather( g_MaskTexture, vec3(mask_uv,0), 1);
        mask_all |= textureGather( g_MaskTexture, vec3(mask_uv,0), 2);
        mask_all |= textureGather( g_MaskTexture, vec3(mask_uv,0), 3);
        mask_all |= textureGather( g_MaskTexture, vec3(mask_uv,1), 0);
        mask_all |= textureGather( g_MaskTexture, vec3(mask_uv,1), 1);
        mask_all |= textureGather( g_MaskTexture, vec3(mask_uv,1), 2);
        mask_all |= textureGather( g_MaskTexture, vec3(mask_uv,1), 3);
        mask_all.xy ^= mask_all.zw;
        mask_all.x |= mask_all.y;
        if(mask_all.x != 0u)
        {
            color = vec4(1.0);
        }
    }
    #endif
    float zval = 0.235;
#if 1
    uint maskVal = texture( g_MaskTexture, mask_uv).x;
    /*
        maskMult =1 when the mask value:
            - has g_MaskParent as supergroup 
            - shifted by leveOffset bits and AND'd with levelBits makes an index. use that as bit index in g_MaskLevelSelectionMask
    */
    bool parent_ok = (g_MaskParent >> (g_MaskLevelBitOffset + g_MaskLevelBitCount)) == (maskVal >> (g_MaskLevelBitOffset + g_MaskLevelBitCount));//(g_MaskParent & maskVal) == g_MaskParent;
    uint maskIndexInLevel = (maskVal >> g_MaskLevelBitOffset) & ((1u << g_MaskLevelBitCount)-1u);
    float maskMult = float(parent_ok) * float(maskIndexInLevel > 0u ) * float( (g_MaskLevelSelectionMask & (1<<(maskIndexInLevel-1u))) > 0u ) * (sin(g_TotalTime*6.5)*3.0);
    float mask_intensity = (zval + g_Minimap*(1.0 - zval))*maskMult;
    color.xyz *= 1.0 - mask_intensity * 2.0;

    color.xyz = mix(color.xyz*(1.0 - mask_intensity * 2.0), max( delin_boundaries, vec3(mask_intensity)), g_ColorizeBySubtype);

    //color.z = (zval + g_Minimap*(1.0 - zval))*maskMult;
    //color.z = (zval + g_Minimap*(1.0 - zval))*float(parent_ok) * ( maskIndexInLevel == 9 ? 1.0 : 0.0);
    // WAS: color.z = (zval + g_Minimap*(1.0 - zval))*float(maskVal == g_MaskActiveIndex);
#else
    int maskArraySlice = g_MaskActiveIndex >> 7;
    uvec4 mask4 = texture( g_MaskTexture, vec3(mask_uv,maskArraySlice));
    int maskTest = g_MaskActiveIndex & 127; 
    // maskTest is in [0,127]. Divide by 32 bits to get the component
    int maskComponent = maskTest >> 5;
    int mask = int(mask4[maskComponent]);
    int maskFinalValue = maskTest & 31;
    float maskMult = g_UseMask * float( (mask & (1 << maskFinalValue)) != 0)* (sin(g_TotalTime*6.5)*0.5 + 0.5);
    color.xyz *= 2.0;//pow(abs(color.xyz), vec3(0.75));
    color.z = color.x;
    float mask_intensity = (zval + g_Minimap*(1.0 - zval))*maskMult;
    color.xyz *= 1.0 - mask_intensity * 2.0;
#endif

    color *= in_bounds;
    
    uvec3 totalThreads = gl_WorkGroupSize * gl_NumWorkGroups;
    ivec2 pixel_coords_inv = ivec2(pixel_coords.x, int(totalThreads.y)-1-pixel_coords.y);
    if( (g_Minimap == 1) && (
        (((int(corner0.x) == pixel_coords_inv.x) || (int(corner1.x) == pixel_coords_inv.x)) && pixel_coords_inv.y >= corner0.y && pixel_coords_inv.y <= corner1.y) ||
        (((int(corner0.y) == pixel_coords_inv.y) || (int(corner1.y) == pixel_coords_inv.y)) && pixel_coords_inv.x >= corner0.x && pixel_coords_inv.x <= corner1.x)))
        color = vec4(1,1,0,1);
        
    color *= g_ColorScale;
    
  // output to a specific pixel in the image
  imageStore(img_output, pixel_coords+g_RenderOffset, color);
}