struct Globals {
    float2 resolution;
    float time;
    uint frame;
};

struct Camera {
    float3 position;
    int _pad1_0;
    row_major float4x4 proj;
    row_major float4x4 view;
    row_major float4x4 inv_proj;
};

struct MeshInfo {
    uint vertex_offset;
    uint vertex_count;
    uint base_index;
    uint index_count;
};

struct Instance {
    row_major float4x4 transform;
    uint mesh_id;
    uint material_id;
    float2 padding;
};

struct Material {
    float4 base_color;
    uint albedo;
    uint normal;
    uint metallic_roughness;
    uint emissive;
};

struct DrawIndexedIndirect {
    uint vertex_count;
    uint instance_count;
    uint base_index;
    int vertex_offset;
    uint base_instance;
};

struct VertexInput {
    uint instance_index : SV_InstanceID;
    float3 position : LOC0;
    float3 normal : LOC1;
    float2 tex_coords : LOC2;
};

struct VertexOutput {
    float4 clip_position : SV_Position;
    float3 position : LOC0;
    float3 normal : LOC1;
    float2 uv : LOC3;
    nointerpolation uint material_id : LOC4;
};

static const float3 LIGTH_POS = float3(15.0, 10.5, 15.0);

cbuffer un : register(b0) { Globals un; }
cbuffer camera : register(b0, space1) { Camera camera; }
SamplerState tex_sampler : register(s1, space2);
ByteAddressBuffer meshes : register(t0, space3);
ByteAddressBuffer instances : register(t0, space4);
ByteAddressBuffer materials : register(t0, space5);

struct VertexOutput_vs_main {
    float3 position : LOC0;
    float3 normal : LOC1;
    float2 uv : LOC3;
    nointerpolation uint material_id : LOC4;
    float4 clip_position : SV_Position;
};

struct FragmentInput_fs_main {
    float3 position_1 : LOC0;
    float3 normal_1 : LOC1;
    float2 uv_1 : LOC3;
    nointerpolation uint material_id_1 : LOC4;
    float4 clip_position_1 : SV_Position;
};

float3x3 mat4_to_mat3_(float4x4 m)
{
    return float3x3(m[0].xyz, m[1].xyz, m[2].xyz);
}

Instance ConstructInstance(float4x4 arg0, uint arg1, uint arg2, float2 arg3) {
    Instance ret = (Instance)0;
    ret.transform = arg0;
    ret.mesh_id = arg1;
    ret.material_id = arg2;
    ret.padding = arg3;
    return ret;
}

VertexOutput_vs_main vs_main(VertexInput in_)
{
    VertexOutput out_ = (VertexOutput)0;

    Instance instance = ConstructInstance(float4x4(asfloat(instances.Load4(in_.instance_index*80+0+0)), asfloat(instances.Load4(in_.instance_index*80+0+16)), asfloat(instances.Load4(in_.instance_index*80+0+32)), asfloat(instances.Load4(in_.instance_index*80+0+48))), asuint(instances.Load(in_.instance_index*80+64)), asuint(instances.Load(in_.instance_index*80+68)), asfloat(instances.Load2(in_.instance_index*80+72)));
    float4 world_pos = mul(float4(in_.position, 1.0), instance.transform);
    float4x4 _expr12 = camera.view;
    float4 view_pos = mul(world_pos, _expr12);
    float4x4 _expr18 = camera.proj;
    out_.clip_position = mul(view_pos, _expr18);
    out_.position = (view_pos.xyz / (view_pos.w).xxx);
    const float3x3 _e27 = mat4_to_mat3_(instance.transform);
    out_.normal = mul(in_.normal, _e27);
    out_.uv = in_.tex_coords;
    out_.material_id = instance.material_id;
    VertexOutput _expr34 = out_;
    const VertexOutput vertexoutput = _expr34;
    const VertexOutput_vs_main vertexoutput_1 = { vertexoutput.position, vertexoutput.normal, vertexoutput.uv, vertexoutput.material_id, vertexoutput.clip_position };
    return vertexoutput_1;
}

Material ConstructMaterial(float4 arg0, uint arg1, uint arg2, uint arg3, uint arg4) {
    Material ret = (Material)0;
    ret.base_color = arg0;
    ret.albedo = arg1;
    ret.normal = arg2;
    ret.metallic_roughness = arg3;
    ret.emissive = arg4;
    return ret;
}

float4 fs_main(FragmentInput_fs_main fragmentinput_fs_main) : SV_Target0
{
    VertexOutput in_1 = { fragmentinput_fs_main.clip_position_1, fragmentinput_fs_main.position_1, fragmentinput_fs_main.normal_1, fragmentinput_fs_main.uv_1, fragmentinput_fs_main.material_id_1 };
    float3 color = (float3)0;

    Material material = ConstructMaterial(asfloat(materials.Load4(in_1.material_id*32+0)), asuint(materials.Load(in_1.material_id*32+16)), asuint(materials.Load(in_1.material_id*32+20)), asuint(materials.Load(in_1.material_id*32+24)), asuint(materials.Load(in_1.material_id*32+28)));
    float3 nor = normalize(in_1.normal);
    color = material.base_color.xyz;
    return float4((nor * 0.7), 1.0);
}
