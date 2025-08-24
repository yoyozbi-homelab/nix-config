{ pkgs, ... }:
{
  services = {
    netdata = {
      enable = true;
      package = pkgs.unstable.netdataCloud;
      config = {
        global = {
          "memory mode" = "ram";
          "debug log" = "none";
          "access log" = "none";
          "error log" = "syslog";
        };
      };
      configDir = {
      };
    };
  };
  environment.systemPackages = with pkgs; [
    netdataCloud
    git
  ];
}
