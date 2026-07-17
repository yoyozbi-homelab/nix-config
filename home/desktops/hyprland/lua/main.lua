-- Hyprland v0.55+ native Lua configuration
-- Entry point: loaded via require("conf/main") from the HM-generated hyprland.lua

hl.config({
  debug = {
    disable_logs = false,
  },

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
    ["col.active_border"]         = "rgb(44475a)",
    ["col.inactive_border"]       = "rgb(282a36)",
    ["col.nogroup_border"]        = "rgb(282a36)",
    ["col.nogroup_border_active"] = "rgb(44475a)",
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

  group = {
    groupbar = {
      col_textlock = "rgba(ffffff7f)",
    },
  },

  dwindle = {
    preserve_split = true,
  },

  master = {
    new_on_top = true,
  },
})

-- Monitor: auto-detect best resolution
-- TODO: verify exact hl.monitor() signature on target host
hl.monitor(",highres,auto,auto")

-- Bezier curve + animations
hl.bezier("myBezier", 0.05, 0.9, 0.1, 1.05)
hl.animation({ leaf = "windows",    enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default",  style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

-- Environment variables
-- TODO: verify hl.env() vs hl.config({ env = ... }) on target host
hl.env("TERMINAL",                         "ghostty")
hl.env("EDITOR",                           "nvim")
hl.env("BROWSER",                          "zen")
hl.env("__GL_VRR_ALLOWED",                 "1")
hl.env("GDK_BACKEND",                      "wayland,x11,*")
hl.env("QT_QPA_PLATFORM",                  "wayland;xcb")
hl.env("SDL_VIDEODRIVER",                  "wayland")
hl.env("CLUTTER_BACKEND",                  "wayland")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE",      "1")
hl.env("XDG_CURRENT_DESKTOP",             "Hyprland")
hl.env("XDG_SESSION_DESKTOP",             "Hyprland")
hl.env("XDG_SESSION_TYPE",                "wayland")
hl.env("WEBKIT_DISABLE_COMPOSITING_MODE", "1")

require("conf/binds")
require("conf/rules")
require("conf/autostart")
