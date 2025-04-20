{ config, pkgs, lib, ... }:

let
  # Pink/Black theme settings
  customGnomeSettings = builtins.toJSON {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Catppuccin-Mocha-Pink";
      icon-theme = "Papirus-Dark";
      cursor-theme = "Catppuccin-Mocha-Pink-Cursors";
      font-name = "JetBrainsMono Nerd Font 11";
      document-font-name = "JetBrainsMono Nerd Font 11";
      monospace-font-name = "JetBrainsMono Nerd Font Mono 11";
    };
    
    "org/gnome/desktop/background" = {
      picture-uri = "file:///usr/share/backgrounds/pink-wallpaper.jpg";
      picture-uri-dark = "file:///usr/share/backgrounds/pink-wallpaper.jpg";
      picture-options = "zoom";
    };
    
    "org/gnome/desktop/screensaver" = {
      picture-uri = "file:///usr/share/backgrounds/pink-wallpaper.jpg";
      picture-options = "zoom";
    };
    
    "org/gnome/shell" = {
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Terminal.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Settings.desktop"
      ];
      disable-user-extensions = false;
      enabled-extensions = [
        "user-theme@gnome-shell-extensions.gcampax.github.com"
      ];
    };
    
    "org/gnome/shell/extensions/user-theme" = {
      name = "Catppuccin-Mocha-Pink";
    };
    
    "org/gnome/desktop/wm/preferences" = {
      button-layout = "appmenu:minimize,maximize,close";
      theme = "Catppuccin-Mocha-Pink";
    };
    
    "org/gnome/mutter" = {
      center-new-windows = true;
      dynamic-workspaces = true;
      edge-tiling = true;
    };
    
    "org/gnome/desktop/peripherals/mouse" = {
      accel-profile = "flat";
      speed = 0.0;
    };
    
    "org/gnome/desktop/peripherals/touchpad" = {
      tap-to-click = true;
      two-finger-scrolling-enabled = true;
    };
    
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-type = "nothing";
    };
    
    "org/gnome/terminal/legacy/profiles:" = {
      default = "b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
      list = ["b1dcc9dd-5262-4d8d-a863-c897e6d979b9"];
    };
    
    "org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
      background-color = "rgb(30, 30, 46)";
      foreground-color = "rgb(245, 194, 231)";
      bold-color = "rgb(245, 194, 231)";
      cursor-background-color = "rgb(245, 194, 231)";
      cursor-foreground-color = "rgb(30, 30, 46)";
      use-theme-colors = false;
      palette = [
        "rgb(17, 17, 27)" "rgb(243, 139, 168)" "rgb(166, 227, 161)" 
        "rgb(249, 226, 175)" "rgb(137, 180, 250)" "rgb(245, 194, 231)" 
        "rgb(148, 226, 213)" "rgb(205, 214, 244)" "rgb(88, 91, 112)" 
        "rgb(243, 139, 168)" "rgb(166, 227, 161)" "rgb(249, 226, 175)" 
        "rgb(137, 180, 250)" "rgb(245, 194, 231)" "rgb(148, 226, 213)" 
        "rgb(205, 214, 244)"
      ];
      scrollbar-policy = "never";
      font = "JetBrainsMono Nerd Font Mono 12";
      use-system-font = false;
    };
  };
  
  # Script to apply GNOME settings
  applyGnomeSettings = pkgs.writeShellScriptBin "apply-gnome-settings" ''
    set -e
    
    # Create settings file
    SETTINGS_FILE="/tmp/gnome-settings.json"
    echo '${customGnomeSettings}' > $SETTINGS_FILE
    
    # Apply settings with gsettings
    ${pkgs.jq}/bin/jq -r 'to_entries[] | .key as $section | .value | to_entries[] | [$section, .key, .value] | @sh' $SETTINGS_FILE | 
    while read -r section key value; do
      # Remove quotes added by @sh
      section=$(echo $section | tr -d "'")
      key=$(echo $key | tr -d "'")
      value=$(echo $value | tr -d "'" | sed 's/^"//' | sed 's/"$//')
      
      # Handle arrays
      if [[ $value == \[* ]]; then
        ${pkgs.gnome.gnome-shell}/bin/gsettings set "$section" "$key" "$value"
      else
        ${pkgs.gnome.gnome-shell}/bin/gsettings set "$section" "$key" "$value"
      fi
    done
    
    echo "GNOME settings applied successfully!"
    
    # Clean up
    rm $SETTINGS_FILE
  '';
  
  # Pink wallpaper
  pinkWallpaper = pkgs.fetchurl {
  url = "https://images.pexels.com/photos/3075993/pexels-photo-3075993.jpeg";
  sha256 = "sha256-/D8Mq8R/Jss9EOZ74qs8p+ShoUcB6z8z7EPCFxK8pbA=";
};
  
in {
  # Install required packages for GNOME
  environment.systemPackages = with pkgs; [
    # Make our scripts available
    applyGnomeSettings
    
    # Fonts
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    
    # GNOME theming
    gnomeExtensions.user-themes
    gnome.gnome-tweaks
    gnome.dconf-editor
    
    # Theme packages
    catppuccin-gtk
    catppuccin-cursors
    papirus-icon-theme
    
    # Standard GNOME applications
    gnome.nautilus
    gnome.gnome-terminal
    gnome.gnome-system-monitor
    gnome.gnome-calculator
    gnome.gnome-calendar
    gnome.gnome-control-center
  ];
  
  # Enable GNOME extensions
  services.gnome.gnome-browser-connector.enable = true;
  
  # Install the pink wallpaper
  system.activationScripts.gnomeWallpaper = ''
    mkdir -p /usr/share/backgrounds/
    cp ${pinkWallpaper} /usr/share/backgrounds/pink-wallpaper.jpg
    chmod 644 /usr/share/backgrounds/pink-wallpaper.jpg
  '';
  
  # Run our settings script for each user login
  # This will create a systemd user service to apply our theme settings
  systemd.user.services.gnome-theme-setup = {
    description = "Apply GNOME theme settings";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${applyGnomeSettings}/bin/apply-gnome-settings";
      RemainAfterExit = true;
    };
  };
}
