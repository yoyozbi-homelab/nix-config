-- Hyprland v0.55+ Lua config — noctalia desktop variant
-- __is_vm and __polkit_path are injected by Nix via extraConfig in noctalia/default.nix
hl.config({
	input = {
		kb_layout = "ch",
		kb_variant = "fr",
		follow_mouse = 1,
		sensitivity = 0,
		touchpad = {
			natural_scroll = true,
			clickfinger_behavior = 1,
		},
	},

	general = {
		gaps_in = 2,
		gaps_out = 10,
		border_size = 2,
		layout = "dwindle",
	},

	xwayland = {
		enabled = true,
		force_zero_scaling = true,
	},

	misc = {
		disable_hyprland_logo = false,
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
	},

	decoration = {
		rounding = 10,
		blur = {
			enabled = true,
			size = 10,
			passes = 4,
			ignore_opacity = true,
			new_optimizations = true,
			xray = false,
			noise = 0.02,
			contrast = 1.1,
			vibrancy = 0.2,
			vibrancy_darkness = 0.3,
		},
		shadow = {
			enabled = true,
			range = 60,
			render_power = 3,
			color = "rgba(1E202966)",
		},
	},

	dwindle = {
		preserve_split = true,
	},

	cursor = {
		no_hardware_cursors = true,
	},
})

-- Noctalia layer rules
hl.layer_rule({
	name = "noctalia",
	match = {
		namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd)$",
	},
	no_anim = true,
	ignore_alpha = 0.5,
	blur = true,
	blur_popups = true,
})

-- Monitor and VM-specific overrides
-- __is_vm is a boolean Lua variable injected from Nix at build time
if __is_vm then
	-- Empty output name is a catch-all rule; the virtio-gpu output name varies
	-- ("Virtual-1" etc.) and is case-sensitive, so matching by name is fragile.
	-- Forcing the mode + scale=1 here prevents Hyprland from picking the huge
	-- preferred mode that makes everything render tiny.
	hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
	hl.env("WLR_NO_HARDWARE_CURSORS", "1")
else
	hl.monitor({ output = "", mode = "auto", position = "auto", scale = 1 })
end

-- Animations
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

-- Environment variables
hl.env("TERMINAL", "ghostty")
hl.env("EDITOR", "nvim")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

-- Keybindings
local mod = "SUPER"

local ipc = "noctalia msg "

-- Core binds
hl.bind(mod .. "+ SPACE", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"))
hl.bind(mod .. "+S", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"))
hl.bind(mod .. "+ COMMA", hl.dsp.exec_cmd(ipc .. "settings-toggle"))
hl.bind("ALT + TAB", hl.dsp.exec_cmd("noctalia msg window-switcher"))
hl.bind(mod .. "+CONTROL + L", hl.dsp.exec_cmd("noctalia msg session lock"))

-- Shortcuts to start programs
hl.bind(mod .. "+RETURN", hl.dsp.exec_cmd("uwsm app -- ghostty"))
hl.bind(mod .. "+ SHIFT + B", hl.dsp.exec_cmd("uwsm app -- zen"))
hl.bind(mod .. "+ SHIFT + RETURN", hl.dsp.exec_cmd("uwsm app -- ghostty -e tmux"))

-- Media keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(ipc .. "volume-up"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(ipc .. "volume-down"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(ipc .. "volume-mute"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(ipc .. "brightness-up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down"))

-- Noctalia Settings
hl.window_rule({
	match = { class = "dev.noctalia.Noctalia" },
	float = true,
	size = { 1080, 920 },
})
-- Window management
hl.bind(mod .. " + W", hl.dsp.window.close())
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }))

-- Focus movement
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Workspace switching (1-9)
for i = 1, 9 do
	hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
	hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = false }))
end
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10", follow = false }))

-- Mouse manipulation
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Startup (once, at Hyprland start)
-- __polkit_path is injected by Nix via extraConfig so we get the correct store path
hl.on("hyprland.start", function()
	hl.exec_cmd("uwsm app -- noctalia")
	hl.exec_cmd("uwsm app -- " .. __polkit_path)
	if __is_vm then
		hl.exec_cmd("sleep 3 && notify-send 'You are running in a VM'")
	end
	hl.exec_cmd("uwsm app -- wl-paste --type text --watch cliphist store")
	hl.exec_cmd("uwsm app -- wl-paste --type image --watch cliphist store")
	hl.exec_cmd("uwsm app -- nm-applet")
end)
