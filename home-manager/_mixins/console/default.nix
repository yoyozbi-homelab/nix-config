{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in
{
  fonts = {
    fontconfig = {
      enable = true;
    };
  };
  home = {
    file = {
      "${config.xdg.configHome}/yazi/keymap.toml".text = builtins.readFile ./yazi-keymap.toml;
      "${config.xdg.configHome}/yazi/theme.toml".text = builtins.readFile ./yazi-theme.toml;

      "${config.xdg.configHome}/nvim/lua" = {
        source = ./nvim-config/lua;
        recursive = true;
      };
      "${config.xdg.configHome}/nvim/init.lua".text = builtins.readFile ./nvim-config/init.lua;
    };

    packages =
      with pkgs;
      [
        nerd-fonts.fira-code
        nerd-fonts.jetbrains-mono
        nerd-fonts.ubuntu-mono

        iosevka-comfy.comfy
        lua-language-server
        nixd
        fzf
        wl-clipboard

        typst
        tinymist
        luarocks

        # lsp
        tree-sitter
        eslint_d
        stylua
        ruff
        php82Packages.php-codesniffer
        php82Extensions.xdebug
        php82Extensions.pcov
        bun
        master.neovide
        lazygit
        thefuck
        fira
        fira-go
        ubuntu_font_family
        work-sans
        asciicam # Terminal webcam
        asciinema-agg # Convert asciinema to .gif
        asciinema # Terminal recorder
        bandwhich # Modern Unix `iftop`
        bmon # Modern Unix `iftop`
        chafa # Terminal image viewer
        chroma # Code syntax highlighter
        clinfo # Terminal OpenCL info
        cpufetch # Terminal CPU info
        curlie # Terminal HTTP client
        difftastic # Modern Unix `diff`
        dogdns # Modern Unix `dig`
        dotacat # Modern Unix lolcat
        dua # Modern Unix `du`
        duf # Modern Unix `df`
        du-dust # Modern Unix `du`
        editorconfig-core-c # EditorConfig Core
        entr # Modern Unix `watch`
        fastfetch # Modern Unix system info
        fd # Modern Unix `find`
        frogmouth # Terminal mardown viewer
        glow # Terminal Markdown renderer
        gping # Modern Unix `ping`
        h # Modern Unix autojump for git projects
        hexyl # Modern Unix `hexedit`
        hr # Terminal horizontal rule
        httpie # Terminal HTTP client
        hyperfine # Terminal benchmarking
        iperf3 # Terminal network benchmarking
        jpegoptim # Terminal JPEG optimizer
        jiq # Modern Unix `jq`
        lima-bin # Terminal VM manager
        mdp # Terminal Markdown presenter
        mtr # Modern Unix `traceroute`
        neo-cowsay # Terminal ASCII cows
        netdiscover # Modern Unix `arp`
        nixpkgs-review # Nix code review
        nix-prefetch-scripts # Nix code fetcher
        nurl # Nix URL fetcher
        nyancat # Terminal rainbow spewing feline
        onefetch # Terminal git project info
        optipng # Terminal PNG optimizer
        procs # Modern Unix `ps`
        quilt # Terminal patch manager
        rclone # Modern Unix `rsync`
        sd # Modern Unix `sed`
        speedtest-go # Terminal speedtest.net
        terminal-parrot # Terminal ASCII parrot
        tldr # Modern Unix `man`
        tokei # Modern Unix `wc` for code
        ueberzugpp # Terminal image viewer integration
        upterm # Terminal sharing
        wget2 # Terminal HTTP client
        wthrr # Modern Unix weather
        wormhole-william # Terminal file transfer
        yq-go # Terminal `jq` for YAML

        nodejs_20
      ]
      ++ lib.optionals isLinux [
        figlet # Terminal ASCII banners
        iw # Terminal WiFi info
        libva-utils # Terminal VAAPI info
        lurk # Modern Unix `strace`
        python310Packages.gpustat # Terminal GPU info
        ramfetch # Terminal system info
        vdpauinfo # Terminal VDPAU info
        wavemon # Terminal WiFi monitor
        zsync # Terminal file sync; FTBFS on aarch64-darwin
      ];
  };
  programs = {
    bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        batgrep
        batwatch
        prettybat
      ];
      config = {
        style = "plain";
      };
    };

    bottom = {
      enable = true;
      settings = {
        colors = {
          high_battery_color = "green";
          medium_battery_color = "yellow";
          low_battery_color = "red";
        };
        disk_filter = {
          is_list_ignored = true;
          list = [ "/dev/loop" ];
          regex = true;
          case_sensitive = false;
          whole_word = false;
        };
        flags = {
          dot_marker = false;
          enable_gpu_memory = true;
          group_processes = true;
          hide_table_gap = true;
          mem_as_value = true;
          tree = true;
        };
      };
    };

    dircolors = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      nix-direnv = {
        enable = true;
      };
    };

    eza = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
      git = true;
      icons = "auto";
    };

    zsh = {
      enable = true;
      shellAliases = {
        build-home = "pushd $(pwd) && home-manager build --flake $HOME/nix-config && popd";
        switch-home = "pushd $(pwd) && home-manager switch -b backup --flake $HOME/nix-config && popd";
        #ll = "ls -l";
        update = "pushd $(pwd) && cd $HOME/nix-config && nix flake update && sudo nixos-rebuild switch --flake . && popd";
        brg = "batgrep";
        cat = "bat --paging=never";
        dmesg = "dmesg --human --color=always";
        htop = "btm --basic --tree --hide_table_gap --dot_marker";
        top = "btm --basic --tree --hide_table_gap --dot_marker";
        ip = "ip --color --brief";
        less = "bat";
        more = "bat";
        checkip = "curl -s ifconfig.me/ip";
        tree = "eza --tree";
        delete-old-branch = "git fetch -p && for branch in $(git for-each-ref --format '%(refname) %(upstream:track)' refs/heads | awk '$2 == \"[gone]\" {sub(\"refs/heads/\", \"\", $1); print $1}'); do git branch -D $branch; done";
      };
      initContent = ''
        fastfetch
      '';
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "thefuck"
        ];
        theme = "robbyrussell";
      };
    };

    git = {
      enable = true;
      aliases = {
        fucked = "reset --hard";
        graph = "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
      lfs = {
        enable = true;
      };
      extraConfig = {
        core = {
          pager = "bat";
        };
        push = {
          default = "matching";
          autoSetupRemote = true;
        };
        pull = {
          rebase = true;
        };
        init = {
          defaultBranch = "main";
        };
      };
    };

    gpg.enable = true;
    home-manager.enable = true;
    ripgrep = {
      enable = true;
      arguments = [
        "--colors=line:style:bold"
        "--max-columns-preview"
        "--smart-case"
      ];
    };

    yazi = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
      settings = {
        manager = {
          show_hidden = false;
          show_symlink = true;
          sort_by = "natural";
          sort_dir_first = true;
          sort_sensitive = false;
          sort_reverse = false;
        };
      };
    };
    neovim = {
      enable = true;
      defaultEditor = true;
      package = pkgs.unstable.neovim-unwrapped;
    };

    tmux = {
      enable = true;
      shell = "${pkgs.zsh}/bin/zsh";
      terminal = "tmux-256color";
      historyLimit = 10000;
      plugins = with pkgs; [
        tmuxPlugins.sensible
        tmuxPlugins.vim-tmux-navigator
        {
          plugin = tmuxPlugins.catppuccin;
          extraConfig = "set -g @catppuccin_flavour 'mocha'";
        }
        tmuxPlugins.yank
      ];
      extraConfig = ''
        set -g mouse on

        unbind C-b
        set -g prefix C-Space
        bind C-Space send-prefix

        # Vim style pane selection
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Start windows and panes at 1, not 0
        set -g base-index 1
        set -g pane-base-index 1
        set-window-option -g pane-base-index 1
        set-option -g renumber-windows on

        # Use Alt-arrow keys without prefix key to switch panes
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D

        # Shift arrow to switch windows
        bind -n S-Left  previous-window
        bind -n S-Right next-window

        # Shift Alt vim keys to switch windows
        bind -n M-H previous-window
        bind -n M-L next-window

        # set vi-mode
        set-window-option -g mode-keys vi
        # keybindings
        bind-key -T copy-mode-vi v send-keys -X begin-selection
        bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
        bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

        bind '"' split-window -v -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"
      '';
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = lib.mkIf isLinux "sd-switch";

  xdg = {
    enable = isLinux;
    userDirs = {
      enable = isLinux;
      createDirectories = lib.mkDefault true;
    };
  };
}
