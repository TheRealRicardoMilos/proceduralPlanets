Shader "PeerPlay/RayMarch"
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
            static const float3 ambienceLightColorCloud = float3(0.1, 0.1, 0.2);
            static const float3 lightColor = float3(1.0, 0.95, 0.9);//float3(1.0, 0.9, 0.7);
            static const float3 ambienceLightColorWater = float3(0.05, 0.1, 0.3)/2;
            static const float PI = 3.14159265f;
            static const float WaterDensity = 0.002;


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

                //float Sphere2 = sdSphere(p - sphere1.xyz+ float3(5,5,5), sphere1.w);
                

                
                return Sphere1;//min(Sphere1,Sphere2);
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
                return 1;//worleyNoise(position);
            }
            // 3D Simplex Noise function in HLSL

            float hash( float n ) {
                return frac(sin(n)*43758.5453);
            }
            
            float noise( float3 x ) {
                // The noise function returns a value in the range -1.0f -> 1.0f
                float3 p = floor(x);
                float3 f = frac(x);
            
                f = f*f*(3.0-2.0*f);
                float n = p.x + p.y*57.0 + 113.0*p.z;
            
                return lerp(lerp(lerp( hash(n+0.0), hash(n+1.0),f.x),
                    lerp( hash(n+57.0), hash(n+58.0),f.x),f.y),
                    lerp(lerp( hash(n+113.0), hash(n+114.0),f.x),
                    lerp( hash(n+170.0), hash(n+171.0),f.x),f.y),f.z);
            }


            float density(float3 p,float d)
            {
                return clamp(-d+1,0,4)*0.01;
            }

            float4 blendColors(float4 f, float4 b) {
                if (f.a >= 1.0) {
                    return f;
                }
                
                float a = f.a + b.a * (1.0 - f.a);
                float3 rgb = (f.rgb * f.a + b.rgb * b.a * (1.0 - f.a)) / a;
                
                return float4(rgb, a);
            }

            float henyeyGreenstein(float cosAngle, float g=0.6) //g is scattering amount
            {
                return (1.0 / (4.0 * PI)) * ((1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cosAngle, 1.5));
            }

            float raymarchToLight(float3 ro, float3 rd)
            {
                const float min_step = 0.2;
                float t = 0; //distance traveled
                float distanceInCloud = 0;
                const int max_iteration = 64;

                for (int i=0; i < max_iteration; i++)
                {
                    float3 p = ro + rd *t;
                    float dLight = distance(p,lightPosition);
                    float d = min(distanceField(p),dLight);
                    if (dLight < min_step)
                    {
                        break;
                    }
                    if (d < min_step) // hit
                    {

                        //shading
                        distanceInCloud += min_step * density(p,d);

                        //progress ray
                        t += min_step;
                    }
                    else
                    {

                        //progress ray
                        t += d;
                    }
                    
                    
                }
                float absorption = distanceInCloud * 0.9;
                fixed transmitance = pow(10,-absorption);

                return transmitance; //brightness
            }

            fixed4 raymarchingGas(float3 ro, float3 rd, float depth) //ray origin, ray direction
            {

                fixed4 result = fixed4(0,0,0,0);
                const int max_iteration = 64;
                float t = 0; //distance traveled
                const float min_step = 0.1;
                float distanceInCloud = 0;
                

                for (int i=0; i < max_iteration; i++)
                {
                    if(t > maxDistance || t >= depth)
                    {
                        break;
                    }

                    float3 p = ro + rd *t;
                    //check hit in distancefield
                    float d = distanceField(p);

                    if (d < min_step) // hit
                    {
                        //shading

                        float3 lightDirection = normalize(lightPosition-p);
                        float value = raymarchToLight(p,lightDirection) * (1 + henyeyGreenstein(dot(lightDirection,rd)));
                        float3 lin = ambienceLightColorCloud + lightColor * value;
                        float den = density(p,d);
                        fixed4 color = fixed4(lin,den);
                        
                        result = blendColors(result,color);

                        //progress ray
                        t += min_step;
                    }
                    else
                    {
                        //progress ray
                        t += d;
                    }
                }

                return result;
            }

            fixed3 background(float3 rd)
            {
                float dotProduct = dot(rd, float3(0.0, 1.0, 0.0));
                float angleRadians = acos(dotProduct);

                if(angleRadians > PI/2){
                    return fixed3(0.4,0.38,0.36);
                }
                return fixed3(0.56,0.66,0.89);

                //return fixed3(0.1,0.1,0.1) + fixed3(0.56,0.66,0.89) * angleRadians;
            }
            
            fixed4 raymarchingReflection(float3 ro, float3 rd,const float max_iteration,const float _maxDistance) //ray origin, ray direction
            {                
                fixed4 result = fixed4(0,0,0,0);
                 
                float t = 0; //distance traveled
                const float min_step = 0.1;
                float distanceInCloud = 0;
                bool isCollide = false;
                

                for (int i=0; i < max_iteration; i++)
                {
                    if(t > _maxDistance)
                    {
                        break;
                    }

                    float3 p = ro + rd *t;
                    //check hit in distancefield
                    float objectDistance = distanceField(p);
                    float lightDistance = distance(p,lightPosition) - 1;

                    if (lightDistance < 0)
                    {
                        result = blendColors(result,fixed4(lightColor,1));
                        break;

                    }
                    float d = min(objectDistance,lightDistance);

                    if (d < min_step) // hit
                    {
                        /*if (!isCollide && i != 0)
                        {
                            //reflection
                            reflectionDirection = reflect(rd,getNormal1(p));
                            reflection = raymarchingReflection(p,reflectionDirection);
                            isCollide = true;
                        }*/
                        
                        //shading

                        float3 lightDirection = normalize(lightPosition-p);
                        float value = raymarchToLight(p,lightDirection) * (1 + henyeyGreenstein(dot(lightDirection,rd)));
                        float3 lin = ambienceLightColorWater + lightColor * value;
                        fixed4 color = fixed4(lin,WaterDensity);
                        
                        result = blendColors(result,color);

                        //progress ray
                        t += min_step;
                    }
                    else
                    {
                        isCollide = false;
                        //progress ray
                        t += d;
                        
                    }
                }

                return blendColors(result,fixed4(background(rd),1));
            }

            float3 refractionDirection(float3 incident, float3 normal, float incidentIndex, float refractedIndex)
            {
                return normalize(incidentIndex/refractedIndex * cross(normal, cross(-normal, incident)) - normal * sqrt(1 - dot(cross(normal, incident)*(incidentIndex/refractedIndex*incidentIndex/refractedIndex), cross(normal, incident))));
            }

            fixed4 raymarching(float3 ro, float3 rd, float depth) //ray origin, ray direction
            {

                fixed4 result = fixed4(0,0,0,0);
                const int max_iteration = 250;
                float t = 0; //distance traveled
                const float min_step = 0.1;
                float distanceInCloud = 0;
                bool isCollide = false;
                float currentMaxDistance = maxDistance;
                float refractionIndex = 1.33;
                float incidentIndex = 1.0;
                

                for (int i=0; i < max_iteration; i++)
                {
                    if(t > currentMaxDistance || t >= depth)
                    {
                        
                        break;
                    }

                    float3 p = ro + rd *t;
                    //check hit in distancefield
                    float objectDistance = distanceField(p);
                    float lightDistance = distance(p,lightPosition) - 2;

                    if (lightDistance < min_step)
                    {
                        result = blendColors(fixed4(result.rgb,pow(result.a,3)),fixed4(lightColor,1));
                        break;
                        
                    }
                    float d = min(objectDistance,lightDistance);

                    if (d < min_step) // hit
                    {
                        if (!isCollide && i != 0)//on surface
                        {
                            float3 normal = getNormal1(p);

                            //reflection
                            
                            float3 reflectionDirection = reflect(rd,normal);
                            fixed4 reflection = raymarchingReflection(p,reflectionDirection,max_iteration-i,currentMaxDistance-t)*0.5;
                            result += reflection;
                            

                            //refraction
                            ro = p;
                            rd = refractionDirection(rd,normal,incidentIndex,refractionIndex);
                            currentMaxDistance -= t;
                            t = 0;

                            isCollide = true;
                        }
                        
                        //shading

                        float3 lightDirection = normalize(lightPosition-p);
                        float value = raymarchToLight(p,lightDirection) * (1 + henyeyGreenstein(dot(lightDirection,rd)));
                        float3 lin = ambienceLightColorWater + lightColor * value *0.5;                    
                        fixed4 color = fixed4(lin,WaterDensity);
                        
                        result = blendColors(result,color);

                        //progress ray
                        t += min_step;
                    }
                    else
                    {
                        if(isCollide)//off surface
                        {
                            
                            //refraction
                            float3 normal = getNormal1(p);
                            ro = p;
                            rd = refractionDirection(rd,-normal,refractionIndex,incidentIndex);
                            currentMaxDistance -= t;
                            t = 0;

                            isCollide = false;
                        }
                        
                        //progress ray
                        t += d;
                        
                    }
                }

                return blendColors(result,fixed4(background(rd),1));
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