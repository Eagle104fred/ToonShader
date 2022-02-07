
            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            uniform float4 _BaseColor;
            //v.2.0.5
            uniform float4 _Color;
            uniform fixed _Use_BaseAs1st;
            uniform fixed _Use_1stAs2nd;
            //
            uniform fixed _Is_LightColor_Base;
            uniform sampler2D _1st_ShadeMap; uniform float4 _1st_ShadeMap_ST;
            uniform float4 _1st_ShadeColor;
            uniform fixed _Is_LightColor_1st_Shade;
            uniform sampler2D _2nd_ShadeMap; uniform float4 _2nd_ShadeMap_ST;
            uniform float4 _2nd_ShadeColor;
            uniform fixed _Is_LightColor_2nd_Shade;
     
            uniform float _Is_NormalMapToBase;
            uniform float _Set_SystemShadowsToBase;
            uniform float _Tweak_SystemShadowsLevel;
            uniform float _BaseColor_Step;
            uniform float _BaseShade_Feather;
            uniform sampler2D _Set_1st_ShadePosition; uniform float4 _Set_1st_ShadePosition_ST;
            uniform float _ShadeColor_Step;
            uniform float _1st2nd_Shades_Feather;
            uniform sampler2D _Set_2nd_ShadePosition; uniform float4 _Set_2nd_ShadePosition_ST;


            //高光
            uniform float _Is_LightColor_HighColor;
            uniform float4 _HighColor;
            uniform sampler2D _HighColor_Tex; uniform float4 _HighColor_Tex_ST;
            uniform sampler2D _Set_HighColorMask; uniform float4 _Set_HighColorMask_ST;
            uniform float _HighColor_Power;
            uniform fixed _Is_NormalMapToHighColor;
            uniform float _Tweak_HighColorMaskLevel;
            uniform fixed _Is_SpecularToHighColor;
            //天使环
            uniform float _Is_AngelRing;
            uniform float _AngelRingExponent;
            //RimLight
            uniform float _Is_RimLight;
            uniform float4 _RimLightColor; 
            uniform float _RimLight_Power;
            uniform float _RimLight_InsideMask;
            uniform float _Is_UseTweakMatCapOnShadow;
            uniform float _Is_Filter_HiCutPointLightColor;
            uniform float _Is_LightColor_RimLight;
            uniform float _Is_NormalMapToRimLight;

            //法线贴图
            uniform float _BumpScale;
            uniform float _BumpScaleMatcap;
            uniform sampler2D _NormalMap; uniform float4 _NormalMap_ST;

            //Emissive
            uniform float _Rotate_MatCapUV;
            uniform float4 _Emissive_Color;
            uniform float4 _ColorShift;
            uniform float _ColorShift_Speed;
            uniform fixed _Is_ColorShift;
            uniform float4 _ViewShift;
            uniform fixed _Is_ViewShift;
            uniform float3 emissive;

            //环境光
            uniform float _Unlit_Intensity;


            ///////////function///////////
            //环境光球鞋函数 
            float3 DecodeLightProbe(float3 N)
            {
                return ShadeSH9(float4(N,1));
            }
            //头发高光(天使环)
            float HairSpecular(float3 halfDir,float3 t,float exponent)
            {
                float3 dotTH = dot(t,halfDir);
                float sinTH = max(0.01,sqrt(1-pow(dotTH,2)));
                float dirAtten = smoothstep(-1,0,dotTH);
                return dirAtten*pow(sinTH,exponent);
            
            }

            
            uniform float _GI_Intensity;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 texcoord0 : TEXCOORD0;
            };
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                //用于构造切线坐标
                float3 normalDir : TEXCOORD2;
                float3 tangentDir : TEXCOORD3;
                float3 bitangentDir : TEXCOORD4;
                //判断左手系还是右手系
                float mirrorFlag : TEXCOORD5;
                //光照贴图
                LIGHTING_COORDS(6,7)
                //雾化贴图
                UNITY_FOG_COORDS(8)
            };
            v2f vert (a2v v) {
                v2f o = (v2f)0;
                o.uv0 = v.texcoord0;
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);//用于构造切线坐标
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                float3 lightColor = _LightColor0.rgb;
                o.pos = UnityObjectToClipPos( v.vertex );
                //v.2.0.7 鏡の中判定（右手座標系か、左手座標系かの判定）o.mirrorFlag = -1 なら鏡の中.
                float3 crossFwd = cross(UNITY_MATRIX_V[0], UNITY_MATRIX_V[1]);//view矩阵的朝向forward
                o.mirrorFlag = dot(crossFwd, UNITY_MATRIX_V[2]) < 0 ? 1 : -1;//判断左手系还是右手系
                //
                UNITY_TRANSFER_FOG(o,o.pos);
	            TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
            float4 frag(v2f i, fixed facing : VFACE) : SV_TARGET {
                i.normalDir = normalize(i.normalDir);
                float2 Set_UV0 = i.uv0;
                //带_NormalMap_var.xyz解析的unpack函数
                float3 _NormalMap_var = UnpackScaleNormal(tex2D(_NormalMap,TRANSFORM_TEX(Set_UV0, _NormalMap)), _BumpScale);
                float3 normalLocal = _NormalMap_var.rgb;
                //定义TBN矩阵用于解码normalMap(切线空间变换到模型空间)
                float3x3 tangentTransform = float3x3( i.tangentDir, i.bitangentDir, i.normalDir);
                float3 normalDirection = normalize(mul( normalLocal, tangentTransform ));
                float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);

                float4 _MainTex_var = tex2D(_MainTex,TRANSFORM_TEX(Set_UV0, _MainTex));//取出主uv

                //计算光线的衰减
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.posWorld.xyz);
                //UNITY_MATRIX_V[0].xyz摄像机x轴在世界空间下的值UNITY_MATRIX_V[1].xyz --> 摄像机y轴在世界空间下的值UNITY_MATRIX_V[2].xyz --> 摄像机z轴在世界空间下的值
                float3 defaultLightDirection = normalize(UNITY_MATRIX_V[2].xyz + UNITY_MATRIX_V[1].xyz);
                float3 defaultLightColor = saturate(max(half3(0.05,0.05,0.05)*_Unlit_Intensity,max(ShadeSH9(half4(0.0, 0.0, 0.0, 1.0)),ShadeSH9(half4(0.0, -1.0, 0.0, 1.0)).rgb)*_Unlit_Intensity));
                //世界光源的方向
                //防止光线垂直时模型过黑
                float3 lightDirection = normalize(lerp(defaultLightDirection,_WorldSpaceLightPos0.xyz,any(_WorldSpaceLightPos0.xyz)));
                //获取光照的颜色
                float3 lightColor = max(defaultLightColor,_LightColor0.rgb);

////DoubleShadow            
                _Color = _BaseColor;//主贴图颜色
                //设置一号影和二号影
                float3 Set_LightColor = lightColor.rgb;
                //是否加入光线颜色(lerp充当if)
                float3 Set_BaseColor = lerp( (_BaseColor.rgb*_MainTex_var.rgb), ((_BaseColor.rgb*_MainTex_var.rgb)*Set_LightColor), _Is_LightColor_Base );
                //TRANSFORM_TEX(用uv和材质的材质球的tiling和offset做运算确保缩放正确)
                //判断使用主uv代替一号影uv
                float4 _1st_ShadeMap_var = lerp(tex2D(_1st_ShadeMap,TRANSFORM_TEX(Set_UV0, _1st_ShadeMap)),_MainTex_var,_Use_BaseAs1st);
                //是否加入光线颜色
                float3 Set_1st_ShadeColor = lerp( (_1st_ShadeColor.rgb*_1st_ShadeMap_var.rgb), ((_1st_ShadeColor.rgb*_1st_ShadeMap_var.rgb)*Set_LightColor), _Is_LightColor_1st_Shade );
                //v.2.0.5
                //判断使用一号影uv代替二号影uv
                float4 _2nd_ShadeMap_var = lerp(tex2D(_2nd_ShadeMap,TRANSFORM_TEX(Set_UV0, _2nd_ShadeMap)),_1st_ShadeMap_var,_Use_1stAs2nd);
                //是否加入光线颜色
                float3 Set_2nd_ShadeColor = lerp( (_2nd_ShadeColor.rgb*_2nd_ShadeMap_var.rgb), ((_2nd_ShadeColor.rgb*_2nd_ShadeMap_var.rgb)*Set_LightColor), _Is_LightColor_2nd_Shade );
                //NdotL(判断是否使用法线贴图)
                float _HalfLambert_var = 0.5*dot(lerp(i.normalDir,normalDirection,_Is_NormalMapToBase),lightDirection)+0.5;//halfLambert操作防止模型背面太暗
                //取出阴影区域的主贴图
                //float4 _Set_2nd_ShadePosition_var = tex2D(_Set_2nd_ShadePosition,TRANSFORM_TEX(Set_UV0, _Set_2nd_ShadePosition));
                //float4 _Set_1st_ShadePosition_var = tex2D(_Set_1st_ShadePosition,TRANSFORM_TEX(Set_UV0, _Set_1st_ShadePosition));
                //控制光照最小值
                //Minmimum value is same as the Minimum Feather's value with the Minimum Step's value as threshold.
                float _SystemShadowsLevel_var = (attenuation*0.5)+0.5+_Tweak_SystemShadowsLevel > 0.001 ? (attenuation*0.5)+0.5+_Tweak_SystemShadowsLevel : 0.0001;
                //判断是否使用光照衰减系统
                //设定一号影的范围分子决定阴影的范围, 分母控制渐变的效果实际上float Set_FinalShadowMask = saturate(1.0 + ((_HalfLambert_var - _BaseColor_Step) * -0.1) / _BaseShade_Feather);
                float Set_FinalShadowMask = saturate(1.0 + ( (lerp( _HalfLambert_var, _HalfLambert_var*saturate(_SystemShadowsLevel_var), _Set_SystemShadowsToBase ) - (_BaseColor_Step-_BaseShade_Feather)) * ( - 1.0) ) / (_BaseColor_Step - (_BaseColor_Step-_BaseShade_Feather)));
	            //float Set_FinalShadowMask = saturate(1.0 + ((_HalfLambert_var - _BaseColor_Step) * -0.1) / _BaseShade_Feather);

                //Composition: 3 Basic Colors as Set_FinalBaseColor
                //设置二号影的范围
                float3 Set_FinalBaseColor = lerp(Set_BaseColor,lerp(Set_1st_ShadeColor,Set_2nd_ShadeColor,saturate((1.0 + ( (_HalfLambert_var - (_ShadeColor_Step-_1st2nd_Shades_Feather)) * ( - 1.0) ) / (_ShadeColor_Step - (_ShadeColor_Step-_1st2nd_Shades_Feather))))),Set_FinalShadowMask); // Final Color
                //float3 Set_FinalBaseColor = lerp(Set_BaseColor,lerp(Set_1st_ShadeColor,Set_2nd_ShadeColor,saturate((1.0 + ( (_HalfLambert_var - _ShadeColor_Step) * - 1.0 ) / _1st2nd_Shades_Feather))),Set_FinalShadowMask); // 
                float3 finalColor = Set_FinalBaseColor;// Final Composition before Emissive

////Speculate
                //半角
                float3 halfDirection = normalize(viewDirection+lightDirection);
                //v.2.0.6: Add HighColor if _Is_Filter_HiCutPointLightColor is False
                //高光贴图
                float4 _Set_HighColorMask_var = tex2D(_Set_HighColorMask,TRANSFORM_TEX(Set_UV0, _Set_HighColorMask));
                //bulin-phong 高光
                float _Specular_var = 0.5*dot(halfDirection,lerp( i.normalDir, normalDirection, _Is_NormalMapToHighColor ))+0.5; //  Specular                
                _Specular_var=lerp(_Specular_var,HairSpecular(halfDirection,i.bitangentDir,_AngelRingExponent),_Is_AngelRing);
                
                float _TweakHighColorMask_var = (saturate((_Set_HighColorMask_var.g+_Tweak_HighColorMaskLevel))*lerp( (1.0 - step(_Specular_var,(1.0 - pow(_HighColor_Power,5)))), pow(_Specular_var,exp2(lerp(11,1,_HighColor_Power))), _Is_SpecularToHighColor ));
                float4 _HighColor_Tex_var = tex2D(_HighColor_Tex,TRANSFORM_TEX(Set_UV0, _HighColor_Tex));
                //高光强度是否受光强影响
                float3 _HighColor_var = (lerp( (_HighColor_Tex_var.rgb*_HighColor.rgb), ((_HighColor_Tex_var.rgb*_HighColor.rgb)*Set_LightColor), _Is_LightColor_HighColor )*_TweakHighColorMask_var);
                float3 Set_HighColor=lerp(_HighColor_var,_HighColor_var,_Is_AngelRing);
                

                float3 _Is_LightColor_RimLight_var = lerp( _RimLightColor.rgb, (_RimLightColor.rgb*Set_LightColor), _Is_LightColor_RimLight );
                //计算Rim的区域
                float _RimArea_var = (1.0 - dot(lerp( i.normalDir, normalDirection, _Is_NormalMapToRimLight ),viewDirection));
                float _RimLightPower_var = pow(_RimArea_var,exp2(lerp(3.0,0.0,_RimLight_Power)));
                //Rim遮罩
                float _Rimlight_InsideMask_var = saturate( (( (_RimLightPower_var - _RimLight_InsideMask) ) / (1.0 - _RimLight_InsideMask)) );
                
                float3 Set_RimLight=_Is_LightColor_RimLight_var*_Rimlight_InsideMask_var;
                //判断RimLight是否启用
                float3 _RimLight_var = lerp( Set_HighColor, (Set_HighColor+Set_RimLight), _Is_RimLight );
                finalColor  += _HighColor_var*(1.0 - Set_FinalShadowMask)+_RimLight_var;
                //finalColor = finalColor + lerp(lerp( _HighColor_var, (_HighColor_var*((1.0 - Set_FinalShadowMask)+(Set_FinalShadowMask*_TweakHighColorOnShadow))), _Is_UseTweakHighColorOnShadow ),float3(0,0,0),_Is_Filter_HiCutPointLightColor);

                //Emissive   
                float4 _time_var = _Time;
                float _colorShift_Speed_var = 1.0 - cos(_time_var.g*_ColorShift_Speed);
                float viewShift_var = smoothstep( 0.0, 1.0, max(0,dot(normalDirection,viewDirection)));
                float4 colorShift_Color = lerp(_Emissive_Color, lerp(_Emissive_Color, _ColorShift, _colorShift_Speed_var), _Is_ColorShift);
                float4 viewShift_Color = lerp(_ViewShift, colorShift_Color, viewShift_var);
                float4 emissive_Color = lerp(colorShift_Color, viewShift_Color, _Is_ViewShift);
                emissive = emissive_Color.rgb;

                //GI_Intensity with Intensity Multiplier Filter
                //环境光配置(球鞋)
                float3 envLightColor = DecodeLightProbe(0) < float3(1,1,1) ? DecodeLightProbe(0) : float3(1,1,1);
                float envLightIntensity = 0.299*envLightColor.r + 0.587*envLightColor.g + 0.114*envLightColor.b <1 ? (0.299*envLightColor.r + 0.587*envLightColor.g + 0.114*envLightColor.b) : 1;

                finalColor =  saturate(finalColor) + (envLightColor*envLightIntensity*_GI_Intensity*smoothstep(1,0,envLightIntensity/2)) + emissive;


//
                //Final Composition
                finalColor =  saturate(finalColor) + (envLightColor*envLightIntensity*_GI_Intensity*smoothstep(1,0,envLightIntensity/2));

	            float4 finalRGBA = float4(finalColor, 1);


                //启用雾化效果
                UNITY_APPLY_FOG(i.fogCoord, finalRGBA);
                return finalRGBA;
            }
