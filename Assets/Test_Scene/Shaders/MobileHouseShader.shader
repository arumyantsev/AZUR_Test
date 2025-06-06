Shader "Custom/URP/MobileHouseShader"
{
    Properties
    {
        _MainTex ("Base Texture (RGB: BaseColor, A: AO)", 2D) = "white" {}
        _TextureIntensity ("Texture Intensity", Range(0, 2)) = 1.0
        [Toggle] _Use_AO ("Use AO", Float) = 1
        _AO_Color ("AO Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _AO_Intensity ("AO Intensity", Range(0, 1)) = 0.72
        [Toggle] _Use_Roughness ("Use Roughness", Float) = 1
        _Roughness ("Roughness", Range(0, 10)) = 5.55
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        LOD 100

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float4 color : COLOR;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                float4 color : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                float3 viewDirWS : TEXCOORD4;
                float3 positionWS : TEXCOORD5;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float _TextureIntensity;
            float _Use_AO;
            float4 _AO_Color;
            float _AO_Intensity;
            float _Use_Roughness;
            float _Roughness;

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.uv = input.uv;
                output.uv2 = input.uv2;
                output.color = input.color;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.positionWS = TransformObjectToWorld(input.positionOS);
                output.viewDirWS = GetWorldSpaceViewDir(output.positionWS);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // Sample texture
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half3 baseColor = tex.rgb * _TextureIntensity;
                half aoMask = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv2).a;

                // Invert AO mask and apply as a factor if enabled
                half aoFactor = _Use_AO ? lerp(1.0, aoMask, _AO_Intensity) : 1.0;
                half3 ao = lerp(half3(1, 1, 1), _AO_Color.rgb, 1.0 - aoFactor);

                // Lighting calculations
                half3 normalWS = normalize(input.normalWS);
                Light mainLight = GetMainLight();
                half3 lightDir = normalize(mainLight.direction);
                half NdotL = max(0, dot(normalWS, lightDir));
                half3 diffuse = baseColor * NdotL * mainLight.color * ao;

                // Specular (using vertex color red channel as roughness mask if enabled, controlled by Roughness)
                half3 specularColor = half3(0, 0, 0);
                if (_Use_Roughness)
                {
                    half3 viewDir = normalize(input.viewDirWS);
                    half3 halfDir = normalize(lightDir + viewDir);
                    half NdotH = max(0, dot(normalWS, halfDir));
                    half roughnessMask = input.color.r;
                    half specular = pow(NdotH, (1.0 / (_Roughness + 0.01)) * 128.0) * roughnessMask;
                    specularColor = specular * mainLight.color;
                }

                // Combine lighting
                half3 finalColor = diffuse + specularColor;

                // Additional lights
                uint numAdditionalLights = GetAdditionalLightsCount();
                for (uint i = 0; i < numAdditionalLights; ++i)
                {
                    Light light = GetAdditionalLight(i, input.positionWS);
                    lightDir = normalize(light.direction);
                    NdotL = max(0, dot(normalWS, lightDir));
                    diffuse = baseColor * NdotL * light.color * ao;
                    specularColor = half3(0, 0, 0);
                    if (_Use_Roughness)
                    {
                        half3 viewDir = normalize(input.viewDirWS);
                        half3 halfDir = normalize(lightDir + viewDir);
                        half NdotH = max(0, dot(normalWS, halfDir));
                        half roughnessMask = input.color.r;
                        half specular = pow(NdotH, (1.0 / (_Roughness + 0.01)) * 128.0) * roughnessMask;
                        specularColor = specular * light.color;
                    }
                    finalColor += diffuse + specularColor;
                }

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
}