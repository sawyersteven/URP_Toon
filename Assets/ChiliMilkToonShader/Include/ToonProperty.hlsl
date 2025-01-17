﻿#ifndef TOON_PROPERTY_INCLUDED
    #define TOON_PROPERTY_INCLUDED

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

    CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    half4 _BaseColor;
    half3 _shadowColor;
    half _shadowStep;
    half _shadowFeather;
    half _DiffuseRampV;
    half _InShadowMapStrength;

    half _Cutoff;
    half _BumpScale;

    half _SpecularSmoothness;
    half4 _SpecColor;
    half _SpecularStep;
    half _SpecularFeather;
    half _SpecularShift1;
    half _SpecularShift2;
    half _Specular2Mul;
    half _SpecularShiftIntensity;
    float4 _SpecularShiftMap_ST;
    half _Metallic;

    half3 _RimColor;
    half _RimPow;
    half _RimStep;
    half _RimFeather;

    half _OutlineWidth;
    half4 _OutlineColor;
    CBUFFER_END

    TEXTURE2D(_ClipMask);   SAMPLER(sampler_ClipMask);
    //TEXTURE2D(_shadowMap);   SAMPLER(sampler_shadowMap);
    #ifdef _INSHADOWMAP
        TEXTURE2D(_InShadowMap);  SAMPLER(sampler_InShadowMap);
    #endif
    TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
    TEXTURE2D(_SpecGlossMap);   SAMPLER(sampler_SpecGlossMap);
    #ifdef _SPECULARSHIFTMAP
        TEXTURE2D(_SpecularShiftMap);   SAMPLER(sampler_SpecularShiftMap);
    #endif
    #ifdef _DIFFUSERAMPMAP
        TEXTURE2D( _DiffuseRampMap);  SAMPLER(sampler_DiffuseRampMap);
    #endif

    #ifdef _SPECULAR_SETUP
        #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
    #else
        #define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
    #endif

    struct SurfaceDataToon
    {
        half3 albedo;
        half3 specular;
        half  metallic;
        half  smoothness;
        half3 normalTS;
        half  alpha;
        //Specular
        #ifdef _HAIRSPECULAR
            half specularShift1;
            half specularShift2;
        #endif
        //Shadow
        half3 shadow;
        #ifdef _INSHADOWMAP
            half inShadow;
        #endif
    };

    struct InputDataToon
    {
        float3  positionWS;
        half3   normalWS;
        half3   viewDirectionWS;
        float4  shadowCoord;
        half    fogCoord;
        half3   vertexLighting;
        half3   bakedGI;
        float2  normalizedScreenSpaceUV;
        half4   shadowMask;
        #ifdef _HAIRSPECULAR
            half3   tangentWS;
            half3   bitangentWS;
        #endif
    };

    half SampleClipMask(float2 uv)
    {
        #ifdef _ALPHATEST_ON
            #ifdef _INVERSECLIPMASK
                return 1.0h-SAMPLE_TEXTURE2D(_ClipMask,sampler_ClipMask,uv).r;
            #else
                return SAMPLE_TEXTURE2D(_ClipMask,sampler_ClipMask,uv).r;
            #endif
        #else
            return 1.0;
        #endif
    }

    half SampleInShadow(float2 uv)
    {
        #ifdef _INSHADOWMAP
            half inShadow = SAMPLE_TEXTURE2D(_InShadowMap,sampler_InShadowMap,uv).r*_InShadowMapStrength;
            return inShadow;
        #else
            return 0.0;
        #endif
    }

    half SampleSpecularShift(float2 uv,half shiftAdd)
    {
        #ifdef _SPECULARSHIFTMAP
            half specularShift = SAMPLE_TEXTURE2D(_SpecularShiftMap,sampler_SpecularShiftMap,uv*_SpecularShiftMap_ST.xy+_SpecularShiftMap_ST.zw).r*_SpecularShiftIntensity+shiftAdd;
            return specularShift;
        #else
            return _SpecularShiftIntensity+shiftAdd;
        #endif
    }

    half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha,half smoothness)
    {
        half4 specGloss;
        #ifdef _METALLICSPECGLOSSMAP
            specGloss = SAMPLE_METALLICSPECULAR(uv);
            specGloss.a *= smoothness;
        #else
            #if _SPECULAR_SETUP
                specGloss.rgb = _SpecColor.rgb;
            #else
                specGloss.rgb = _Metallic.rrr;
            #endif
            specGloss.a = smoothness;
        #endif
        return specGloss;
    }
    
    inline void InitializeSurfaceDataToon(float2 uv,out SurfaceDataToon outSurfaceData)
    {
        half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
        outSurfaceData.alpha = Alpha(albedoAlpha.a*SampleClipMask(uv), _BaseColor, _Cutoff);
        half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a,_SpecularSmoothness);
        outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
        //outSurfaceData.shadow = SAMPLE_TEXTURE2D(_shadowMap,sampler_shadowMap,uv)*_shadowColor;
        outSurfaceData.shadow = albedoAlpha.rgb *_shadowColor;
        #ifdef _INSHADOWMAP
            outSurfaceData.inShadow = SampleInShadow(uv);
        #endif
        #if _SPECULAR_SETUP
            outSurfaceData.metallic = 1.0h;
            outSurfaceData.specular = specGloss.rgb;
        #else
            outSurfaceData.metallic = specGloss.r;
            outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
        #endif
        outSurfaceData.smoothness = specGloss.a;
        outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
        #ifdef _HAIRSPECULAR
            outSurfaceData.specularShift1 = SampleSpecularShift(uv,_SpecularShift1);
            outSurfaceData.specularShift2 = SampleSpecularShift(uv,_SpecularShift2);
        #endif
        

    }
#endif