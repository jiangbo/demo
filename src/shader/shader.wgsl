struct PosAndColor {
    @builtin(position) pos : vec4f,
    @location(0) color : vec4f
};

@vertex
fn vs_main(@builtin(vertex_index) VertexIndex : u32) -> PosAndColor {
    let pos = array(
        vec2f( 0.5,  0.5),
        vec2f( 0.5, -0.5),
        vec2f(-0.5, -0.5),
        vec2f(-0.5, -0.5),
        vec2f(-0.5,  0.5),
        vec2f( 0.5,  0.5)
    );

    let pos4f = vec4f(pos[VertexIndex], 0.0, 1.0);

    return PosAndColor(pos4f, vec4f(0.9, 0.5, 0.7, 1.0));
}

@fragment
fn fs_main(in: PosAndColor) -> @location(0) vec4f {
    return in.color;
}