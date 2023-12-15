struct PointLight {
    float3 position;
    int _pad1_0;
    float3 color;
    int _end_pad_0;
};

ByteAddressBuffer lights : register(t0);
SamplerState baseColorSampler : register(s0, space1);
Texture2D<float4> baseColorTexture : register(t1, space1);

struct FragmentInput_fragmentMain {
    float3 worldPos_1 : LOC0;
    float3 normal_1 : LOC1;
    float2 uv_1 : LOC2;
};

float4 fragmentMain(FragmentInput_fragmentMain fragmentinput_fragmentmain) : SV_Target0
{
    float3 worldPos = fragmentinput_fragmentmain.worldPos_1;
    float3 normal = fragmentinput_fragmentmain.normal_1;
    float2 uv = fragmentinput_fragmentmain.uv_1;
    int3 surfaceColor = (0).xxx;

    float4 baseColor = baseColorTexture.Sample(baseColorSampler, uv);
    float3 N = normalize(normal);
    return (0.0).xxxx;
}
