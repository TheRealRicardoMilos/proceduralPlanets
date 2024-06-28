Shader "PeerPlay/RayMarch2"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            #include "UnityCG.cginc"
            uniform sampler2D _CameraDepthTexture;
            sampler2D _MainTex;
            uniform float4x4 CamFrustum, CamToWorld;
            uniform float maxDistance;
            uniform float4 sphere1;
            uniform float3 lightPosition;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                half index = v.vertex.z;
                v.vertex.z = 0;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.ray = CamFrustum[(int)index].xyz;

                o.ray /= abs(o.ray.z);

                o.ray = mul(CamToWorld, o.ray);

                return o;
            }

            float sdSphere(float3 p, float s)
            {
                return length(p) - s;
            }


            float distanceField(float3 p)
            {
                float Sphere1 = sdSphere(p - sphere1.xyz, sphere1.w);

                
                return Sphere1;
            }

            float3 getNormal1(float3 p)
            {
                const float2 offset = float2(0.001,0.0);
                float3 n = float3(
                    distanceField(p + offset.xyy) - distanceField(p - offset.xyy),
                    distanceField(p + offset.yxy) - distanceField(p - offset.yxy),
                    distanceField(p + offset.yyx) - distanceField(p - offset.yyx));
                return normalize(n);
            }
            


            // 1x1 chunk -> random position in this chunk
            float3 hash33(float3 p3) {
                float3 p = frac(p3 * float3(0.1031, 0.11369, 0.13787));
                p += dot(p, p.yxz + 19.19);
                return -1.0 + 2.0 * frac(float3((p.x + p.y) * p.z, (p.x + p.z) * p.y, (p.y + p.z) * p.x));
            }


            
            float worleyNoise(float3 position)
            {
                int3 chunk = int3(floor(position));

                //min distance of neighbour chunks
                float d = 3;
                for (int z= -1; z <= 1; z++) {
                    for (int y= -1; y <= 1; y++) {
                        for (int x= -1; x <= 1; x++) {
                            int3 newChunk = chunk + int3(x,y,z);
                            d = min(distance(hash33(newChunk) + newChunk,position),d);
                        }
                    }
                }
                return 1 - d/1.73205080757; // normalize
            }

            float cloudNoise(float3 position)
            {
                return worleyNoise(position);
            }

            cbuffer Constants : register(b0) {
                float uTime;
                float2 uResolution;
            }

            Texture2D uNoise : register(t0);
            SamplerState samLinear : register(s0);




            float noise(float3 x) {
                float3 p = floor(x);
                float3 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);

                float2 uv = (p.xy + float2(37.0, 239.0) * p.z) + f.xy;
                float2 tex = uNoise.SampleLevel(samLinear, (uv + 0.5) / 256.0, 0.0).yx;

                return lerp(tex.x, tex.y, f.z) * 2.0 - 1.0;
            }

            float fbm(float3 p) {
                float3 q = p + uTime * 0.5 * float3(1.0, -0.2, -1.0);
                float g = noise(q);

                float f = 0.0;
                float scale = 0.5;
                float factor = 2.02;

                for (int i = 0; i < 6; i++) {
                    f += scale * noise(q);
                    q *= factor;
                    factor += 0.21;
                    scale *= 0.5;
                }

                return f;
            }

            float scene(float3 p) {
                float distance = sdSphere(p - sphere1.xyz, sphere1.w);
                float f = fbm(p);
                return clamp(-distance + clamp(f,0,1),0,1);
            }

            float4 raymarching(float3 rayOrigin, float3 rayDirection,float idk) {
                float depth = 0;
                float min_step = 0.1;
                float maxDistance = 100;
                float3 p = rayOrigin + depth * rayDirection;
                float3 lightDirection = normalize(lightPosition-rayOrigin);

                float4 res = float4(0.0, 0.0, 0.0, 0.0);
                

                for (int i = 0; i < 100; i++) {

                    float d = distanceField(p);

                    if(depth > maxDistance)
                    {
                        res = fixed4(rayDirection,0);
                        break;
                    }

                    if (d < min_step) // hit
                    {
                        
                        float density = scene(p);

                        if (density > 0) {
                        
                            float diffuse = clamp((scene(p) - scene(p + 0.3 * lightDirection)) / 0.3, 0.0, 1.0);
                            float3 lin = float3(0.60, 0.60, 0.75) * 1.1 + 0.8 * float3(1.0, 0.6, 0.3) * diffuse;
                            float4 color = float4(lerp(float3(1.0, 1.0, 1.0), float3(0.0, 0.0, 0.0), density), density);
                            color.rgb *= lin;
                            color.rgb *= color.a;
                            
                            res += color * (1.0 - res.a);
                            
                        }
                        
                        depth += min_step;
                    }
                    else
                    {
                        
                        depth += min_step;
                    }
                    p = rayOrigin + depth * rayDirection;
                }

                return res;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
                depth *= length (i.ray);
                fixed3 col = tex2D(_MainTex, i.uv);
                float3 rayDirection = normalize(i.ray.xyz);
                float3 rayOrigin = _WorldSpaceCameraPos;
                fixed4 result = raymarching(rayOrigin,rayDirection,depth);
                return fixed4(col * (1.0 - result.w) + result.xyz * result.w,1.0);
            }
            ENDCG
        }
    }
}
