const std = @import("std");

const platform = @import("./platform_impl/platform_impl.zig");

pub const NativeKeyCode = union(enum) {
    unidentified: void,
    android: u32,
    macos: u16,
    windows: u16,
    xkb: u32,
};

pub const NativeKey = union(enum) {
    unidentified: void,
    android: u32,
    macos: u16,
    windows: u16,
    xkb: u32,
    web: []u8,
};

pub const KeyCode = union(enum) {
    unidentified: NativeKeyCode,
    backquote: void,
    backslash: void,
    bracket_left: void,
    bracket_right: void,
    comma: void,
    d0: void,
    d1: void,
    d2: void,
    d3: void,
    d4: void,
    d5: void,
    d6: void,
    d7: void,
    d8: void,
    d9: void,
    equal: void,
    international_backslash: void,
    international_ro: void,
    international_yen: void,
    a: void,
    b: void,
    c: void,
    d: void,
    e: void,
    f: void,
    g: void,
    h: void,
    i: void,
    j: void,
    k: void,
    l: void,
    m: void,
    n: void,
    o: void,
    p: void,
    q: void,
    r: void,
    s: void,
    t: void,
    u: void,
    v: void,
    w: void,
    x: void,
    y: void,
    z: void,
    minus: void,
    period: void,
    quote: void,
    semicolon: void,
    slash: void,
    alt_left: void,
    alt_right: void,
    backspace: void,
    caps_lock: void,
    context_menu: void,
    control_left: void,
    control_right: void,
    enter: void,
    super_left: void,
    super_right: void,
    shift_left: void,
    shift_right: void,
    space: void,
    tab: void,
    convert: void,
    kana: void,
    lang_1: void,
    lang_2: void,
    lang_3: void,
    lang_4: void,
    lang_5: void,
    non_convert: void,
    delete: void,
    end: void,
    help: void,
    home: void,
    insert: void,
    page_down: void,
    page_up: void,
    arrow_down: void,
    arrow_left: void,
    arrow_right: void,
    arrow_up: void,
    num_lock: void,
    numpad_0: void,
    numpad_1: void,
    numpad_2: void,
    numpad_3: void,
    numpad_4: void,
    numpad_5: void,
    numpad_6: void,
    numpad_7: void,
    numpad_8: void,
    numpad_9: void,
    numpad_add: void,
    numpad_backspace: void,
    numpad_clear: void,
    numpad_clear_entry: void,
    numpad_comma: void,
    numpad_decimal: void,
    numpad_divide: void,
    numpad_enter: void,
    numpad_equal: void,
    numpad_hash: void,
    numpad_memory_add: void,
    numpad_memory_clear: void,
    numpad_memory_recall: void,
    numpad_memory_store: void,
    numpad_memory_subtract: void,
    numpad_multiply: void,
    numpad_paren_left: void,
    numpad_paren_right: void,
    numpad_star: void,
    numpad_subtract: void,
    escape: void,
    @"fn": void,
    fn_lock: void,
    print_screen: void,
    scroll_lock: void,
    pause: void,
    browser_back: void,
    browser_favorites: void,
    browser_forward: void,
    browser_home: void,
    browser_refresh: void,
    browser_search: void,
    browser_stop: void,
    eject: void,
    launch_app_1: void,
    launch_app_2: void,
    launch_mail: void,
    media_play_pause: void,
    media_select: void,
    media_stop: void,
    media_track_next: void,
    media_track_previous: void,
    power: void,
    sleep: void,
    audio_volume_down: void,
    audio_volume_mute: void,
    audio_volume_up: void,
    wake: void,
    meta: void,
    hyper: void,
    turbo: void,
    @"resume": void,
    @"suspend": void,
    again: void,
    copy: void,
    cut: void,
    find: void,
    open: void,
    paste: void,
    props: void,
    select: void,
    undo: void,
    hiragana: void,
    katakana: void,
    f1: void,
    f2: void,
    f3: void,
    f4: void,
    f5: void,
    f6: void,
    f7: void,
    f8: void,
    f9: void,
    f10: void,
    f11: void,
    f12: void,
    f13: void,
    f14: void,
    f15: void,
    f16: void,
    f17: void,
    f18: void,
    f19: void,
    f20: void,
    f21: void,
    f22: void,
    f23: void,
    f24: void,
    f25: void,
    f26: void,
    f27: void,
    f28: void,
    f29: void,
    f30: void,
    f31: void,
    f32: void,
    f33: void,
    f34: void,
    f35: void,
};

pub const Key = union(enum) {
    character: []u8,
    unidentified: NativeKey,
    dead: ?u32,
    alt: void,
    alt_graph: void,
    caps_lock: void,
    control: void,
    @"fn": void,
    fn_lock: void,
    num_lock: void,
    scroll_lock: void,
    shift: void,
    symbol: void,
    symbol_lock: void,
    meta: void,
    hyper: void,
    super: void,
    enter: void,
    tab: void,
    space: void,
    arrow_down: void,
    arrow_left: void,
    arrow_right: void,
    arrow_up: void,
    end: void,
    home: void,
    page_down: void,
    page_up: void,
    backspace: void,
    clear: void,
    copy: void,
    cr_sel: void,
    cut: void,
    delete: void,
    erase_eof: void,
    ex_sel: void,
    insert: void,
    paste: void,
    redo: void,
    undo: void,
    accept: void,
    again: void,
    attn: void,
    cancel: void,
    context_menu: void,
    escape: void,
    execute: void,
    find: void,
    help: void,
    pause: void,
    play: void,
    props: void,
    select: void,
    zoom_in: void,
    zoom_out: void,
    brightness_down: void,
    brightness_up: void,
    eject: void,
    log_off: void,
    power: void,
    power_off: void,
    print_screen: void,
    hibernate: void,
    standby: void,
    wake_up: void,
    all_candidates: void,
    alphanumeric: void,
    code_input: void,
    compose: void,
    convert: void,
    final_mode: void,
    group_first: void,
    group_last: void,
    group_next: void,
    group_previous: void,
    mode_change: void,
    next_candidate: void,
    non_convert: void,
    previous_candidate: void,
    process: void,
    single_candidate: void,
    hangul_mode: void,
    hanja_mode: void,
    junja_mode: void,
    eisu: void,
    hankaku: void,
    hiragana: void,
    hiragana_katakana: void,
    kana_mode: void,
    kanji_mode: void,
    katakana: void,
    romaji: void,
    zenkaku: void,
    zenkaku_hankaku: void,
    soft_1: void,
    soft_2: void,
    soft_3: void,
    soft_4: void,
    channel_down: void,
    channel_up: void,
    close: void,
    mail_forward: void,
    mail_reply: void,
    mail_send: void,
    media_close: void,
    media_fast_forward: void,
    media_pause: void,
    media_play: void,
    media_play_pause: void,
    media_record: void,
    media_rewind: void,
    media_track_next: void,
    media_track_previous: void,
    new: void,
    open: void,
    print: void,
    save: void,
    spell_check: void,
    key11: void,
    key12: void,
    audio_balance_left: void,
    audio_balance_right: void,
    audio_bass_boost_down: void,
    audio_bass_boost_toggle: void,
    audio_bass_boost_up: void,
    audio_fader_front: void,
    audio_fader_rear: void,
    audio_surround_mode_next: void,
    audio_treble_down: void,
    audio_treble_up: void,
    audio_volume_down: void,
    audio_volume_up: void,
    audio_volume_mute: void,
    microphone_toggle: void,
    microphone_volume_down: void,
    microphone_volume_up: void,
    microphone_volume_mute: void,
    speech_correction_list: void,
    speech_input_toggle: void,
    launch_application_1: void,
    launch_application_2: void,
    launch_calendar: void,
    launch_contacts: void,
    launch_mail: void,
    launch_media_player: void,
    launch_music_player: void,
    launch_phone: void,
    launch_screen_saver: void,
    launch_spreadsheet: void,
    launch_web_browser: void,
    launch_web_cam: void,
    launch_word_processor: void,
    browser_back: void,
    browser_favorites: void,
    browser_forward: void,
    browser_home: void,
    browser_refresh: void,
    browser_search: void,
    browser_stop: void,
    app_switch: void,
    call: void,
    camera: void,
    camera_focus: void,
    end_call: void,
    go_back: void,
    go_home: void,
    headset_hook: void,
    last_number_redial: void,
    notification: void,
    manner_mode: void,
    voice_dial: void,
    tv: void,
    tv3d_mode: void,
    tv_antenna_cable: void,
    tv_audio_description: void,
    tv_audio_description_mix_down: void,
    tv_audio_description_mix_up: void,
    tv_contents_menu: void,
    tv_data_service: void,
    tv_input: void,
    tv_input_component_1: void,
    tv_input_component_2: void,
    tv_input_composite_1: void,
    tv_input_composite_2: void,
    tv_input_hdmi_1: void,
    tv_input_hdmi_2: void,
    tv_input_hdmi_3: void,
    tv_input_hdmi_4: void,
    tv_input_vga_1: void,
    tv_media_context: void,
    tv_network: void,
    tv_number_entry: void,
    tv_power: void,
    tv_radio_service: void,
    tv_satellite: void,
    tv_satellite_bs: void,
    tv_satellite_cs: void,
    tv_satellite_toggle: void,
    tv_terrestrial_analog: void,
    tv_terrestrial_digital: void,
    tv_timer: void,
    avr_input: void,
    avr_power: void,
    color_f0_red: void,
    color_f1_green: void,
    color_f2_yellow: void,
    color_f3_blue: void,
    color_f4_grey: void,
    color_f5_brown: void,
    closed_caption_toggle: void,
    dimmer: void,
    display_swap: void,
    dvr: void,
    exit: void,
    favorite_clear_0: void,
    favorite_clear_1: void,
    favorite_clear_2: void,
    favorite_clear_3: void,
    favorite_recall_0: void,
    favorite_recall_1: void,
    favorite_recall_2: void,
    favorite_recall_3: void,
    favorite_store_0: void,
    favorite_store_1: void,
    favorite_store_2: void,
    favorite_store_3: void,
    guide: void,
    guide_next_day: void,
    guide_previous_day: void,
    info: void,
    instant_replay: void,
    link: void,
    list_program: void,
    live_content: void,
    lock: void,
    media_apps: void,
    media_audio_track: void,
    media_last: void,
    media_skip_backward: void,
    media_skip_forward: void,
    media_step_backward: void,
    media_step_forward: void,
    media_top_menu: void,
    navigate_in: void,
    navigate_next: void,
    navigate_out: void,
    navigate_previous: void,
    next_favorites: void,
    next_user_profile: void,
    on_demand: void,
    pairing: void,
    pin_p_down: void,
    pin_p_move: void,
    pin_p_toggle: void,
    pin_p_up: void,
    play_speed_down: void,
    play_speed_reset: void,
    play_speed_up: void,
    random_toggle: void,
    rc_low_battery: void,
    record_speed_next: void,
    rf_bypass: void,
    scan_channels_toggle: void,
    screen_mode_next: void,
    settings: void,
    split_screen_toggle: void,
    stb_input: void,
    stb_power: void,
    subtitle: void,
    teletext: void,
    video_mode_next: void,
    wink: void,
    zoom_toggle: void,
    f1: void,
    f2: void,
    f3: void,
    f4: void,
    f5: void,
    f6: void,
    f7: void,
    f8: void,
    f9: void,
    f10: void,
    f11: void,
    f12: void,
    f13: void,
    f14: void,
    f15: void,
    f16: void,
    f17: void,
    f18: void,
    f19: void,
    f20: void,
    f21: void,
    f22: void,
    f23: void,
    f24: void,
    f25: void,
    f26: void,
    f27: void,
    f28: void,
    f29: void,
    f30: void,
    f31: void,
    f32: void,
    f33: void,
    f34: void,
    f35: void,

    pub fn toText(key: Key) ?[]const u8 {
        switch (key) {
            .character => return key.character,
            .enter => return "\r",
            .backspace => return "\x08",
            .tab => return "\t",
            .space => return " ",
            .escape => return "\x1b",
            else => return null,
        }
    }
};

pub const KeyLocation = enum {
    left,
    right,
    numpad,
};

pub const ModifiersState = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
};

pub const ModifiersKeys = enum(u8) {
    lshift = 0b0000_0001,
    rshift = 0b0000_0010,
    lctrl = 0b0000_0100,
    rctrl = 0b0000_1000,
    lalt = 0b0001_0000,
    ralt = 0b0010_0000,
    lsuper = 0b0100_0000,
    rsuper = 0b1000_0000,
};

pub const ModifiersKeyState = enum {
    pressed,
    unknown,
};
