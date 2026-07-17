{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  users.groups.nix = { };
  users.users.nix = {
    group = "nix";
    extraGroups = [
      "keys"
    ];
    hashedPassword = null;
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILUhAz/A2G0feoUU1BvE0p01BBvJ7BV7cU7RmACrLp7Z yohan@laptop-nix"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCxyEiLq0hQp+PifFXDmgkU/vqzlMxZqZQF85VV97Nvi6BB+92RBZ32QT07efR5myDfiin+othilKdVJb9f+2eicdsfD8W4bKvPN8YuL54qvR8/gyrV3iF2QR0yboWk4GzX5wRp08xMQDAFi0mOGpU0y2HqNvR7Vx8eHR5sYWFIHDLAXMjhIAXXePSY5u93u4xtOdNJlQB3XCadYc4cOt5GpIUvtqMiG5udxWVx1ADVgFeuxvMLcTKxyrDUhbGVYjH48kLC0lh/PUpL0kt/+sSJ2kY5fD8Ye8yNUiQkvSIhV1+P28hXggagX0NH3DTiy4DzrBfVvLvcIrmK9wvF6R8a89eyqUUk92A4MmJc1OvEB63mNWMZDANW3Q1fFMWUz5ua9rvkIyiyhf8eVc9M4iWW45bs4YMl6dbG1mDGLlWUPAhfesfa68ZAIX2MgGJfHwXQk9KjUUvzde5Vsi5cmR4EDRz80d5pTuw1OaxWOjYT35QDXwFpF3MHKB+8RXgTLIE= yohan@fedora"
      ''cert-authority,principals="nix" ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHiyPdA+pJygUyma8dBb3ZgWbv+A5If4cE6iZESoH59LQGvy7N1cA+ERvX1b+BK5owbsuuOgRb1JBEJLjnIzmmY= open-ssh-ca@cloudflareaccess.org''
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "nix" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
        }
      ];
    }
  ];
}
