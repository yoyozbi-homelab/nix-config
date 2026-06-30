-- Hyprland v0.55+ Lua config — noctalia desktop variant
-- __is_vm and __polkit_path are injected by Nix via extraConfig in noctalia/default.nix

hl.config({
  input = {
    kb_layout  = "ch",
    kb_variant = "fr",
    follow_mouse = 1,
    sensitivity  = 0,
    touchpad = {
      natural_scroll    = true,
      clickfinger_behavior = 1,
    },
  },

  general = {
    gaps_in    = 2,
    gaps_out   = 10,
    border_size = 2,
    layout = "dwindle",
  },

  xwayland = {
    enabled            = true,
    force_zero_scaling = true,
  },

  misc = {
    disable_hyprland_logo   = false,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms  = true,
  },

  decoration = {
    rounding = 10,
    shadow = {
      enabled      = true,
      range        = 60,
      render_power = 3,
      offset       = "1 2",
      color        = "rgba(1E202966)",
    },
  },

  dwindle = {
    preserve_split = true,
  },

  cursor = {
    no_hardware_cursors = true,
  },
})

-- Monitor and VM-specific overrides
-- __is_vm is a boolean Lua variable injected from Nix at build time
if __is_vm then
  hl.monitor("VIRTUAL-1,1920x1080@60,0x0,1")
  hl.env("WLR_NO_HARDWARE_CURSORS", "1")
else
  hl.monitor(",highres,auto,auto")
end

-- Animations
hl.bezier("myBezier", 0.05, 0.9, 0.1, 1.05)
hl.animation({ leaf = "windows",    enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default",  style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

-- Environment variables
hl.env("TERMINAL",                    "ghostty")
hl.env("EDITOR",                      "nvim")
hl.env("GDK_BACKEND",                 "wayland,x11,*")
hl.env("QT_QPA_PLATFORM",             "wayland;xcb")
hl.env("SDL_VIDEODRIVER",             "wayland")
hl.env("CLUTTER_BACKEND",             "wayland")
hl.env("XDG_CURRENT_DESKTOP",        "Hyprland")
hl.env("XDG_SESSION_DESKTOP",        "Hyprland")
hl.env("XDG_SESSION_TYPE",           "wayland")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

-- Keybindings
local mod = "SUPER"

-- Noctalia IPC launchers (replaces wofi / hyprlock / wlogout)
hl.bind(mod .. " + SPACE",     hl.dsp.exec_cmd("noctalia ipc call launcher toggle"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("noctalia ipc call controlCenter toggle"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd("noctalia ipc call lockScreen lock"))

hl.bind(mod .. " + Q",         hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + E",         hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- Window management
hl.bind(mod .. " + SHIFT + X", hl.dsp.window.close())
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",         hl.dsp.pseudo())
hl.bind(mod .. " + F",         hl.dsp.fullscreen({ mode = 1 }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.fullscreen({ mode = 0 }))

-- Focus movement
hl.bind(mod .. " + left",  hl.dsp.window.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.window.focus({ direction = "r" }))
hl.bind(mod .. " + up",    hl.dsp.window.focus({ direction = "u" }))
hl.bind(mod .. " + down",  hl.dsp.window.focus({ direction = "d" }))

-- Workspace switching (1-9)
for i = 1, 9 do
  hl.bind(mod .. " + " .. i,         hl.dsp.workspace.switch({ id = i }))
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = false }))
end
hl.bind(mod .. " + 0",         hl.dsp.workspace.switch({ id = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10", follow = false }))

-- Mouse manipulation
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- XF86 media keys via noctalia IPC (repeating)
-- TODO: verify { repeating = true } flag name on target host
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("noctalia ipc call volume increase"),    { repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("noctalia ipc call volume decrease"),    { repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("noctalia ipc call volume muteOutput"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("noctalia ipc call brightness increase"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia ipc call brightness decrease"), { repeating = true })

-- Startup (once, at Hyprland start)
-- __polkit_path is injected by Nix via extraConfig so we get the correct store path
hl.on("hyprland.start", function()
  hl.exec_cmd("sleep 0.5 && noctalia")
  hl.exec_cmd(__polkit_path)
  hl.exec_cmd("hypridle")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("sleep 1 && nm-applet")
end)
