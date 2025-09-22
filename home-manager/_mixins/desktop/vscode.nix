{ pkgs, ... }:
{
  programs = {
    vscode = {
      enable = true;
      profiles.default.extensions = with pkgs.vscode-extensions; [
        bradlc.vscode-tailwindcss
        eamodio.gitlens
        ms-azuretools.vscode-docker
        ms-kubernetes-tools.vscode-kubernetes-tools
        ms-vscode-remote.remote-containers
        github.copilot
        github.copilot-chat
        tamasfe.even-better-toml
        ms-vsliveshare.vsliveshare
        christian-kohler.path-intellisense
        bmewburn.vscode-intelephense-client
        devsense.profiler-php-vscode
        esbenp.prettier-vscode
        rust-lang.rust-analyzer
        bradlc.vscode-tailwindcss
        vscodevim.vim
        vscode-icons-team.vscode-icons
        mkhl.direnv
        ms-toolsai.jupyter
        yoavbls.pretty-ts-errors
        svelte.svelte-vscode
        dart-code.flutter
      ];

      mutableExtensionsDir = true;
      package = pkgs.master.vscode;
    };
  };
}
