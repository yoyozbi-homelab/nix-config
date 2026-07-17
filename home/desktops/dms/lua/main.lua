-- Hyprland v0.55+ Lua config — DankMaterialShell (DMS) desktop variant
-- __is_vm and __polkit_path are injected by Nix via extraConfig in dms/default.nix
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
		-- DMS reports "Background blur: Not supported" unless the compositor has
		-- blur enabled; DMS then blurs behind its own panels/popups.
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
			range = 20,
			render_power = 3,
			color = "rgba(00000099)",
		},
	},

	dwindle = {
		preserve_split = true,
	},

	cursor = {
		no_hardware_cursors = true,
	},
})

-- DMS blurs

hl.layer_rule({
	match = { namespace = "dms:control-center" },
	animation = "slide right",
})

hl.layer_rule({
	match = { namespace = "dms:workspace-overview" },
	animation = "slide top",
})
-- You can find all available animations here: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/#animation-tree

-- Blur
-- You can use match.namespace with regex to target multiple layers
hl.layer_rule({
	match = { namespace = "dms:(color-picker|clipboard|spotlight|settings)" },
	blur = true,
	ignore_alpha = 0,
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

-- DankMaterialShell IPC (replaces wofi / hyprlock / wlogout)
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("dms ipc call control-center toggle"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind(mod .. " + COMMA", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("dms ipc call lock lock"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))

hl.bind(mod .. " + Q", hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("dolphin"))

-- Window management
hl.bind(mod .. " + SHIFT + X", hl.dsp.window.close())
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

-- XF86 media keys via DMS IPC (repeating)
-- TODO: verify { repeating = true } flag name on target host
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment 3"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement 3"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment 5"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 5"), { repeating = true })

-- Startup (once, at Hyprland start)
-- __polkit_path is injected by Nix via extraConfig so we get the correct store path
hl.on("hyprland.start", function()
	hl.exec_cmd("dms run -d")
	hl.exec_cmd(__polkit_path)
	--hl.exec_cmd("hypridle")
	if __is_vm then
		hl.exec_cmd("sleep 3 && notify-send 'You are running in a VM'")
	end
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("sleep 1 && nm-applet")
end)
