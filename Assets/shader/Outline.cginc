
            uniform float4 _LightColor0;
            uniform float4 _BaseColor;
            //v.2.0.7.5
            uniform float _Unlit_Intensity;
            uniform fixed _Is_LightColor_Outline;
            //v.2.0.5
            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform float _Outline_Width;
            uniform float _Farthest_Distance;
            uniform float _Nearest_Distance;
            uniform sampler2D _Outline_Sampler; uniform float4 _Outline_Sampler_ST;
            uniform float4 _Outline_Color;
            uniform fixed _Is_BlendBaseColor;
            


            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT; //与法线相切的切线(通常和纹理坐标方向相同)
                float2 texcoord0 : TEXCOORD0;
            };
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalDir : TEXCOORD1;
                float3 tangentDir : TEXCOORD2;
                float3 bitangentDir : TEXCOORD3;
            };
            v2f vert (a2v v) {
                v2f o = (v2f)0;
                o.uv0 = v.texcoord0;
                float4 objPos = mul ( unity_ObjectToWorld, float4(0,0,0,1) );
                float Set_Outline_Width = (_Outline_Width*0.001*smoothstep( _Farthest_Distance, _Nearest_Distance, distance(objPos.rgb,_WorldSpaceCameraPos) )).r;                     
                
                //Set_Outline_Width=_Outline_Width*0.01;
//法线挤出
#ifdef _OUTLINE_NML
                //UTSOutLine
                //o.pos = UnityObjectToClipPos(float4(v.vertex.xyz + v.normal*Set_Outline_Width,1));

                float3 normalCS = UnityObjectToClipPos(v.normal);

                float2 extendDis = normalize(normalCS.xy)*(Set_Outline_Width);
                float ScaleX = abs(_ScreenParams.x / _ScreenParams.y);
                extendDis.x/=ScaleX;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.pos.xy+=extendDis*o.pos.w;
//顶点挤出
#elif _OUTLINE_POS
                Set_Outline_Width = Set_Outline_Width*2;
                //如果顶点向量与发现的夹角超过90度则取反保证顶点描边的方向是向外的
                float signVar = dot(normalize(v.vertex),normalize(v.normal))<0 ? -1 : 1;
                o.pos = UnityObjectToClipPos(float4(v.vertex.xyz + signVar*normalize(v.vertex)*Set_Outline_Width, 1));
#endif      
                return o;
            }
            float4 frag(v2f i) : SV_Target{


                //float4 objPos = mul ( unity_ObjectToWorld, float4(0,0,0,1) );
                ////天空盒颜色
                //half3 ambientSkyColor = unity_AmbientSky.rgb>0.05 ? unity_AmbientSky.rgb*_Unlit_Intensity : half3(0.05,0.05,0.05)*_Unlit_Intensity;
                //float3 lightColor = _LightColor0.rgb >0.05 ? _LightColor0.rgb : ambientSkyColor.rgb;
                //float lightColorIntensity = (0.299*lightColor.r + 0.587*lightColor.g + 0.114*lightColor.b);
                //lightColor = lightColorIntensity<1 ? lightColor : lightColor/lightColorIntensity;
                ////是否加入光线颜色
                //lightColor = lerp(half3(1.0,1.0,1.0), lightColor, _Is_LightColor_Outline);
                //float2 Set_UV0 = i.uv0;
                //float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(Set_UV0, _MainTex));
                //float3 Set_BaseColor = _BaseColor.rgb*_MainTex_var.rgb;
                ////与贴图颜色融合
                //float3 _Is_BlendBaseColor_var = lerp( _Outline_Color.rgb*lightColor, (_Outline_Color.rgb*Set_BaseColor*Set_BaseColor*lightColor), _Is_BlendBaseColor );

                //float3 Set_Outline_Color = _Is_BlendBaseColor_var;
                return float4(_Outline_Color.rgb,1.0);


            }
