Shader "Custom/TerrainSurface"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        CGPROGRAM
        #pragma surface surf Lambert vertex:vert

        //sampler2D _MainTex;
        fixed4 _Color;

        struct Input
        {
            //float2 uv_MainTex;
            float3 worldPos;
            float3 position;
            float3 worldNormal;
        };

        void vert(inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);
            o.position = v.vertex.xyz;
        }

        float AngleBetweenVectors(float3 vectorA, float3 vectorB)
        {
            float dotProduct = dot(vectorA, vectorB);
            float magnitudeA = length(vectorA);
            float magnitudeB = length(vectorB);
            float cosineTheta = dotProduct / (magnitudeA * magnitudeB);

            // Clamp cosine value to [-1, 1] to avoid NaN in acos
            cosineTheta = clamp(cosineTheta, -1.0, 1.0);
            float angleRadians = acos(cosineTheta);

            // float angleDegrees = degrees(angleRadians);
            return angleRadians;
        }

        void surf (Input IN, inout SurfaceOutput o)
        {
            float distance = length(IN.position);
            fixed _MaxDistance = 1.3;//change
            fixed _MinDistance = 0.3;

            float normalizedDistance = saturate((distance - _MinDistance) / (_MaxDistance - _MinDistance));

            // Compute the color based on the distance
            fixed4 col = lerp(_Color, fixed4(0, 0, 0, 1), 1 - pow(normalizedDistance, 2));

            float slope = AngleBetweenVectors(normalize(IN.worldNormal), normalize(IN.worldPos));

            float maxHeight = 1.1;
            float minHeight = 0.96;

            float grassLevel = slope + 1 + (4/pow((maxHeight-minHeight),2)*(distance-minHeight)*(distance-maxHeight));

            if (grassLevel < 1.3)
            {
                col *= fixed4(0.24, 0.74, 0.31, 1);
            }
            else
            {
                col *= fixed4(0.42, 0.35, 0.29, 1);
            }

            //fixed4 texColor = tex2D(_MainTex, IN.uv_MainTex);
            o.Albedo = col.rgb;
            o.Alpha = col.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
