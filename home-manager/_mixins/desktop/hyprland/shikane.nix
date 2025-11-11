{ ... }:
{
  services.shikane = {
    enable = true;
    settings = {
      profile = [
        {
          name = "builtin monitor only";
          output = [
            {
              search = "n=eDP-1";
              enable = true;
              mode = {
                width = 1920;
                height = 1200;
                refresh = 60;
              };
              position = {
                x = 0;
                y = 0;
              };
              scale = 1;
            }
          ];
        }
        {
          name = "docked";
          output = [
            {
              search = "s=L7LMDW002550";
              enable = true;
              mode = {
                width = 2560;
                height = 1440;
                refresh = 144;
              };
              position = {
                x = 1080;
                y = 0;
              };
            }
            {
              search = "s=KBEH41A001124";
              enable = true;
              mode = {
                width = 1920;
                height = 1080;
                refresh = 60;
              };
              position = {
                x = 0;
                y = 0;
              };
              transform = "270";
            }
            {
              search = "n=eDP-1";
              enable = true;
              mode = {
                width = 1920;
                height = 1200;
                refresh = 60;
              };
              position = {
                x = 1080;
                y = 1440;
              };
              scale = 1;
            }
          ];
        }
        {
          name = "closed-docked";
          output = [
            {
              search = "s=L7LMDW002550";
              enable = true;
              mode = {
                width = 2560;
                height = 1440;
                refresh = 144;
              };
              position = {
                x = 1080;
                y = 0;
              };
            }
            {
              search = "s=KBEH41A001124";
              enable = true;
              mode = {
                width = 1920;
                height = 1080;
                refresh = 60;
              };
              position = {
                x = 0;
                y = 0;
              };
              transform = "270";
            }
            {
              search = "n=eDP-1";
              enable = false;
            }
          ];
        }
        {
          name = "NE310";
          output = [
            {
              search = "m=DELL P2422H";
              enable = true;
              mode = {
                width = 1920;
                height = 1080;
                refresh = 60;
              };
              position = {
                x = 0;
                y = 0;
              };
              scale = 1;
            }
            {
              search = "n=eDP-1";
              enable = true;
              mode = {
                width = 1920;
                height = 1200;
                refresh = 60;
              };
              position = {
                x = 0;
                y = 1080;
              };
              scale = 1.25;
            }
          ];
        }
        {
          name = "BIBLIO";
          output = [
            {
              search = "m=HP E24i G4";
              enable = true;
              mode = {
                width = 1920;
                height = 1200;
                refresh = 59.95;
              };
              position = {
                x = 0;
                y = 0;
              };
              scale = 1;
            }
            {
              search = "n=eDP-1";
              enable = true;
              mode = {
                width = 1920;
                height = 1200;
                refresh = 60;
              };
              position = {
                x = 0;
                y = 1200;
              };
              scale = 1;
            }

          ];
        }
      ];
    };
  };
}
