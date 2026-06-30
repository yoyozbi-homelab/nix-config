-- Startup commands (once, at Hyprland start)
-- systemd env import is handled by the home-manager module's systemd integration
hl.on("hyprland.start", function()
  hl.exec_cmd("dunst")
  hl.exec_cmd("/run/current-system/sw/libexec/polkit-kde-authentication-agent-1")
  hl.exec_cmd("shikane -c ~/.config/shikane/config.toml")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("sway-audio-idle-inhibit")
  hl.exec_cmd("sleep 1 && nm-applet")
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("sleep 1 && xwaylandvideobridge")
end)

-- On every config reload: restart waybar and reset wallpaper
-- TODO: verify hl.on("config.reloaded", ...) event name on target host
hl.on("config.reloaded", function()
  hl.exec_cmd("pkill waybar; sleep 0.5 && waybar")
  hl.exec_cmd("swaybg -m fill -i ~/.config/hypr/SLD24_Wallpaper_4K.png")
end)
