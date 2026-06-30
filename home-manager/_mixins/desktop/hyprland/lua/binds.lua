-- Keybindings

local mod = "SUPER"

-- Application launchers
hl.bind(mod .. " + Q",         hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + E",         hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + SPACE",     hl.dsp.exec_cmd("wofi"))
hl.bind(mod .. " + L",         hl.dsp.exec_cmd("~/.config/hypr/scripts/lock.sh"))
hl.bind(mod .. " + M",         hl.dsp.exec_cmd("wlogout --protocol layer-shell"))
hl.bind(mod .. " + S",         hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist list | wofi --dmenu | cliphist decode | wl-copy"))

-- Window management
hl.bind(mod .. " + SHIFT + X", hl.dsp.window.close())
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",         hl.dsp.pseudo())
hl.bind(mod .. " + F",         hl.dsp.fullscreen({ mode = 1 }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.fullscreen({ mode = 0 }))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exit())

-- Focus movement
hl.bind(mod .. " + left",  hl.dsp.window.focus({ direction = "l" }))
hl.bind(mod .. " + right", hl.dsp.window.focus({ direction = "r" }))
hl.bind(mod .. " + up",    hl.dsp.window.focus({ direction = "u" }))
hl.bind(mod .. " + down",  hl.dsp.window.focus({ direction = "d" }))

-- Workspace switching and window movement (1-9)
for i = 1, 9 do
  hl.bind(mod .. " + " .. i,         hl.dsp.workspace.switch({ id = i }))
  hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i), follow = false }))
end
-- Workspace 10 (key 0)
hl.bind(mod .. " + 0",         hl.dsp.workspace.switch({ id = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "10", follow = false }))

-- Workspace scroll with mouse wheel
hl.bind(mod .. " + mouse_down", hl.dsp.workspace.switch({ relative = 1 }))
hl.bind(mod .. " + mouse_up",   hl.dsp.workspace.switch({ relative = -1 }))

-- Mouse window manipulation
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Hardware / media keys (no modifier)
hl.bind("211", hl.dsp.exec_cmd("asusctl profile -n; pkill -SIGRTMIN+8 waybar"))
hl.bind("121", hl.dsp.exec_cmd("pamixer -t"))
hl.bind("122", hl.dsp.exec_cmd("pamixer -d 5"))
hl.bind("123", hl.dsp.exec_cmd("pamixer -i 5"))
hl.bind("232", hl.dsp.exec_cmd("brightnessctl set 10%-"))
hl.bind("233", hl.dsp.exec_cmd("brightnessctl set 10%+"))

-- Lid switch
-- TODO: verify switch trigger flag name on target host (may be { switch = true } or different)
hl.bind(",switch:on:Lid Switch",  hl.dsp.exec_cmd("~/.config/hypr/scripts/lid-close.sh"), { switch = true })
hl.bind(",switch:off:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/scripts/lid-open.sh"),  { switch = true })
