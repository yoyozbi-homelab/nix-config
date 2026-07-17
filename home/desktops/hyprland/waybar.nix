{ pkgs,... }:
{
  home.packages = with pkgs; [
    pamixer
    pulsemixer
    bluetuith
    kitty
  ];

  programs = {
    waybar = {
      enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          mod = "dock";
          height = 50;
          modules-left = [
            "clock"
            "hyprland/workspaces"
          ];
          modules-center = [
            "hyprland/window"
          ];
          modules-right = [
            "network"
            "bluetooth"
            "battery"
            "cpu"
            "memory"
            "pulseaudio"
            "tray"
          ];
          "hyprland/window" = {
            format = { };
          };
          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
            sort-by-number = true;
            on-click = "activate";
          };
          tray = {
            icon-size = 18;
            spacing = 10;
          };
          clock = {
            format = " {:%I:%M %p   %a, %b %e}";
            tooltip-format = "<big>%{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };
          battery = {
            states = {
              good = 95;
              warning = 30;
              critical = 20;
            };
            format = "{icon} {capacity}%";
            format-charging = " {capacity}%";
            format-plugged = " {capacity}%";
            format-alt = "{time} {icon}";
            format-icons = [
              "󰂎"
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
          };
          pulseaudio = {
            format = "{icon} {volume}%";
            tooltip = false;
            format-muted = " Muted";
            #"on-click": "pamixer -t",
            on-click = "kitty --class floating -e pulsemixer";
            on-scroll-up = "pamixer -i 5";
            on-scroll-down = "pamixer -d 5";
            scroll-step = 5;
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
          };
          cpu = {
            format = "  {usage} %";
            tooltip-format = "{icon}: {avg_frequency}";
          };
          memory = {
            format = "RAM: {percentage} %";
            tooltip-format = "{used:0.1f}GiB used \n {avail:0.1f}GiB left";
          };
          network = {
            # interface = "wlp2*"; // (Optional) To force the use of this interface
            format-wifi = "  {signalStrength}%";
            format-ethernet = "󰈀  {bandwidthTotalOctets}";
            tooltip-format = "{essid} - {ipaddr}/{cidr} - {ifname} via {gwaddr}";
            format-linked = "{ifname} (No IP)";
            format-disconnected = "Disconnected ⚠";
            # format-alt = "{ifname}:{essid} {ipaddr}/{cidr}";
            on-click = "kitty --class floating -e nmtui";
          };
          bluetooth = {
            format = " {status}";
            format-disabled = ""; # an empty format will hide the module
            format-connected = " {num_connections}";
            tooltip-format = "{device_alias}";
            tooltip-format-connected = " {device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}";
            on-click = "kitty --class floating -e bluetuith";
          };
        };
      };

      style = ''
        * {
            border: none;
            border-radius: 0;
            font-family: "JetBrainsMono Nerd Font";
            font-weight: bold;
            font-size: 16px;
            min-height: 0;
        }

        window#waybar {
            background: rgba(21, 18, 27, 0);
            color: #cdd6f4;
        }

        tooltip {
            background: #1e1e2e;
            border-radius: 10px;
            border-width: 2px;
            border-style: solid;
            border-color: #11111b;
        }

        #workspaces button {
            padding: 5px;
            color: #313244;
            margin-right: 5px;
        }

        #workspaces button.active {
            color: #a6adc8;
        }

        #workspaces button.focused {
            color: #a6adc8;
            background: #eba0ac;
            border-radius: 10px;
        }

        #workspaces button.urgent {
            color: #11111b;
            background: #a6e3a1;
            border-radius: 10px;
        }

        #workspaces button:hover {
            background: #11111b;
            color: #cdd6f4;
            border-radius: 10px;
        }

        #custom-power_profile,
        #custom-weather,
        #window,
        #clock,
        #battery,
        #cpu,
        #memory,
        #pulseaudio,
        #network,
        #bluetooth,
        #workspaces,
        #tray {
            background: #1e1e2e;
            opacity: 0.8;
            padding: 0px 10px;
            margin: 3px 0px;
            margin-top: 10px;
            border: 1px solid #181825;
        }


        #tray {
            border-radius: 10px;
            margin-right: 10px;
        }

        #workspaces {
            background: #1e1e2e;
            border-radius: 10px;
            margin-left: 10px;
            padding-right: 0px;
            padding-left: 5px;
        }

        #window {
            border-radius: 10px;
            margin-left: 60px;
            margin-right: 60px;
        }

        #clock {
            color: #fab387;
            border-radius: 10px 10px 10px 10px;
            margin-left: 10px;
            border-right: 0px;
        }

        #network {
            color: #f9e2af;
            border-radius: 10px 0px 0px 10px;
            border-left: 0px;
            border-right: 0px;
        }

        #bluetooth {
            color: #89b4fa;
            border-radius: 0px 10px 10px 0px;
            margin-right: 10px
        } 

        #pulseaudio {
            color: #89b4fa;
            border-radius: 10px 10px 10px 10px;
            margin-right: 10px;
        }


        #battery {
            color: #a6e3a1;
            border-radius: 10px 0px 0px 10px;
            border-left: 0px;
        }

        #memory {
            margin-right: 10px;
            border-radius: 0px 10px 10px 0px;
        }
      '';
    };
  };
}
