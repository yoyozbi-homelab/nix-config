_: {
  networking = {
    networkmanager = {
      enable = true;
      # insertNameservers = ["1.1.1.1" "1.0.0.1"];
      wifi = {
        #backend = "iwd";
        powersave = true;
      };
    };
    #wireless.iwd.package = pkgs.iwd;
  };
}
