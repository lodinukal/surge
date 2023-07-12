pub const WindowHandle = u32;
pub const DisplayHandle = u32;

pub const SystemTheme = enum(u8) {
    unknown = 0,
    light = 1,
    dark = 2,
};

pub const DisplayMode = struct {
    handle: DisplayHandle,
    format: u32,
    width: u32,
    height: u32,
    pixel_density: f32,
    refresh_rate: f32,
    driver_data: *u8 = null,
};
