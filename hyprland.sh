#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# Update system first
echo "Updating system..."
pacman -Syu --noconfirm

# Install yay if not installed
if ! command -v yay &> /dev/null; then
    echo "Installing yay..."
    pacman -S --needed --noconfirm git base-devel
    sudo -u $SUDO_USER bash -c 'cd /tmp && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm'
fi

# Install required packages
echo "Installing required packages..."
pacman -S --noconfirm \
    hyprland \
    sddm \
    waybar \
    swaylock-effects \
    kitty \
    rofi \
    google-chrome \
    hyprpaper \
    code \
    gedit \
    vlc \
    nautilus \
    pulseaudio \
    pulseaudio-alsa \
    pavucontrol \
    gnome-system-monitor \
    blueman \
    network-manager-applet \
    libnotify \
    power-profiles-daemon \
    jq \
    wget \
    curl \
    imagemagick \
    grim \
    slurp \
    wl-clipboard \
    brightnessctl \
    bluez \
    bluez-utils \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-jetbrains-mono \
    ttf-font-awesome \
    polkit-gnome \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    qt5-wayland \
    qt6-wayland \
    python-pywal \
    python-pip \
    material-icons

# Install additional AUR packages
sudo -u $SUDO_USER yay -S --noconfirm \
    material-design-icons \
    rofi-power-menu \
    hyprpicker

# Enable services
echo "Enabling services..."
systemctl enable sddm
systemctl enable bluetooth
systemctl enable power-profiles-daemon

# Install SDDM Astronaut theme (it will handle its own configuration)
echo "Installing SDDM Astronaut theme..."
sudo -u $SUDO_USER bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"'

# Create user directories
echo "Creating user directories..."
sudo -u $SUDO_USER xdg-user-dirs-update

# Configure Hyprland
echo "Configuring Hyprland..."
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
HYPRLAND_CONFIG_DIR="$USER_HOME/.config/hypr"
WAYBAR_CONFIG_DIR="$USER_HOME/.config/waybar"
ROFI_CONFIG_DIR="$USER_HOME/.config/rofi"
KITTY_CONFIG_DIR="$USER_HOME/.config/kitty"
WAL_CONFIG_DIR="$USER_HOME/.config/wal"
NAUTILUS_SCRIPTS_DIR="$USER_HOME/.local/share/nautilus/scripts"

mkdir -p "$HYPRLAND_CONFIG_DIR"
mkdir -p "$WAYBAR_CONFIG_DIR"
mkdir -p "$ROFI_CONFIG_DIR"
mkdir -p "$KITTY_CONFIG_DIR"
mkdir -p "$WAL_CONFIG_DIR/templates"
mkdir -p "$NAUTILUS_SCRIPTS_DIR"
mkdir -p "$USER_HOME/Pictures/wallpapers"

# Set ownership of config directories
chown -R $SUDO_USER:$SUDO_USER "$USER_HOME/.config"
chown -R $SUDO_USER:$SUDO_USER "$USER_HOME/.local"

# Create Hyprland config
cat > "$HYPRLAND_CONFIG_DIR/hyprland.conf" << 'EOL'
# Monitor configuration
monitor=,preferred,auto,1

# Autostart
exec-once = $HOME/.config/hypr/scripts/wallpaper.sh init
exec-once = waybar
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = swayidle -w timeout 300 'swaylock -f -c 000000' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'

# Input configuration
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =
    repeat_rate = 25
    repeat_delay = 600
    numlock_by_default = true
    left_handed = false
    follow_mouse = 1
    float_switch_override_focus = 0
    touchpad {
        natural_scroll = yes
        disable_while_typing = true
        clickfinger_behavior = true
        tap-to-click = true
    }
}

# General configuration
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
    resize_on_border = true
}

# Decoration configuration
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
        new_optimizations = true
    }
    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = yes
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Layout configuration
dwindle {
    pseudotile = yes
    preserve_split = yes
}

master {
    new_is_master = true
}

# Window rules
windowrule = float, ^(kitty)$
windowrule = center, ^(kitty)$
windowrule = size 800 500, ^(kitty)$
windowrule = float, ^(gnome-system-monitor)$
windowrule = center, ^(gnome-system-monitor)$
windowrule = float, ^(pavucontrol)$
windowrule = center, ^(pavucontrol)$
windowrule = float, ^(blueman-manager)$
windowrule = center, ^(blueman-manager)$
windowrule = float, ^(nm-connection-editor)$
windowrule = center, ^(nm-connection-editor)$

# Keybindings
$mainMod = SUPER

# Applications
bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, B, exec, google-chrome-stable
bind = $mainMod, E, exec, nautilus
bind = $mainMod, C, exec, code
bind = $mainMod, G, exec, gedit
bind = $mainMod, V, exec, vlc
bind = $mainMod, R, exec, rofi -show drun
bind = $mainMod, M, exec, gnome-system-monitor

# Window management
bind = $mainMod, Q, killactive,
bind = $mainMod, F, fullscreen,
bind = $mainMod, Space, togglefloating,
bind = $mainMod, P, pseudo, # dwindle
bind = $mainMod, S, togglesplit, # dwindle

# Move focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scroll through workspaces
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# Screenshots
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy
bind = $mainMod, Print, exec, grim - | wl-copy

# Media controls (fixed scroll direction)
bind = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
bind = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%
bind = , XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle
bind = , XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle
bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
bindle = , XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%
bindle = , XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%
bindle = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bindle = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Power menu
bind = $mainMod, Escape, exec, rofi -show power-menu -modi power-menu:rofi-power-menu

# Wallpaper controls
bind = $mainMod SHIFT, W, exec, $HOME/.config/hypr/scripts/wallpaper.sh change

# Lock screen
bind = $mainMod, L, exec, swaylock -f -c 000000

# Exit Hyprland
bind = $mainMod SHIFT, Q, exit,
EOL

# Create wallpaper script with multiple sources and Material You theming
cat > "$HYPRLAND_CONFIG_DIR/scripts/wallpaper.sh" << 'EOL'
#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
mkdir -p "$WALLPAPER_DIR"

# List of wallpaper sources (multiple providers)
SOURCES=(
    "https://source.unsplash.com/random/3840x2160/?nature"
    "https://source.unsplash.com/random/3840x2160/?landscape"
    "https://source.unsplash.com/random/3840x2160/?city"
    "https://source.unsplash.com/random/3840x2160/?space"
    "https://source.unsplash.com/random/3840x2160/?abstract"
    "https://picsum.photos/3840/2160"
    "https://random.imagecdn.app/3840/2160"
    "https://wallhaven.cc/random"
)

# Function to check internet connection
check_internet() {
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        return 1
    fi
    return 0
}

# Function to try downloading from multiple sources
download_wallpaper() {
    if ! check_internet; then
        echo "No internet connection. Using local wallpapers."
        return 1
    fi

    # Try each source until one succeeds
    for source in "${SOURCES[@]}"; do
        local filename="wallpaper_$(date +%s).jpg"
        local filepath="$WALLPAPER_DIR/$filename"
        
        echo "Trying source: $source"
        if wget -q --tries=3 --timeout=10 "$source" -O "$filepath"; then
            # Verify the downloaded file is actually an image
            if file "$filepath" | grep -q "image data"; then
                echo "$filepath"
                return 0
            else
                rm -f "$filepath"
            fi
        fi
    done
    
    return 1
}

# Function to set wallpaper and apply Material You theming
set_wallpaper() {
    local wallpaper=$1
    
    if [[ -f "$wallpaper" ]]; then
        # Set wallpaper with hyprpaper
        hyprctl hyprpaper preload "$wallpaper"
        hyprctl hyprpaper wallpaper "eDP-1,$wallpaper"
        hyprctl hyprpaper unload all
        
        # Generate Material You colors using pywal
        wal -i "$wallpaper" -n -q
        
        # Reload waybar to apply new colors
        if pgrep -x "waybar" > /dev/null; then
            killall -q waybar
            waybar &> /dev/null & disown
        fi
        
        # Update kitty colors
        if pgrep -x "kitty" > /dev/null; then
            kitty @ set-colors --all --configured ~/.cache/wal/colors-kitty.conf
        fi
    fi
}

# Main function
main() {
    local action=${1:-"change"}
    
    if [[ "$action" == "init" ]]; then
        # On startup, try to load the most recent wallpaper
        local recent_wallpaper=$(ls -t "$WALLPAPER_DIR"/*.jpg 2>/dev/null | head -n 1)
        if [[ -n "$recent_wallpaper" ]]; then
            set_wallpaper "$recent_wallpaper"
        else
            # No local wallpapers, try to download
            new_wallpaper=$(download_wallpaper)
            if [[ -n "$new_wallpaper" ]]; then
                set_wallpaper "$new_wallpaper"
            fi
        fi
    elif [[ "$action" == "change" ]]; then
        # Try to download new wallpaper
        new_wallpaper=$(download_wallpaper)
        
        if [[ -n "$new_wallpaper" ]]; then
            # Set new wallpaper
            set_wallpaper "$new_wallpaper"
            
            # Clean up old wallpapers (keep last 10)
            ls -t "$WALLPAPER_DIR"/*.jpg 2>/dev/null | tail -n +11 | xargs rm -f
        else
            # Download failed, use random local wallpaper if available
            local_wallpapers=("$WALLPAPER_DIR"/*.jpg)
            if [[ ${#local_wallpapers[@]} -gt 0 ]]; then
                random_wallpaper=${local_wallpapers[$RANDOM % ${#local_wallpapers[@]}]}
                set_wallpaper "$random_wallpaper"
            fi
        fi
    fi
}

main "$@"
EOL

# Make wallpaper script executable
chmod +x "$HYPRLAND_CONFIG_DIR/scripts/wallpaper.sh"

# Create Material You templates for Waybar
cat > "$WAL_CONFIG_DIR/templates/waybar.css" << 'EOL'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono", "Material Design Icons", "Font Awesome", sans-serif;
    font-size: 12px;
    min-height: 0;
}

window#waybar {
    background: {{background}};
    color: {{foreground}};
    border-bottom: 1px solid {{color2}};
}

#workspaces button {
    padding: 0 5px;
    background: transparent;
    color: {{foreground}};
    border-bottom: 3px solid transparent;
}

#workspaces button.focused {
    background: {{color1}};
    border-bottom: 3px solid {{foreground}};
}

#workspaces button.urgent {
    background: {{color5}};
}

#clock, #battery, #cpu, #memory, #temperature, #backlight, #network, #pulseaudio, #tray, #mode, #idle_inhibitor, #custom-launcher, #custom-powermenu {
    padding: 0 6px;
    margin: 0 2px;
}

#clock {
    background-color: {{color1}};
    color: {{background}};
}

#battery {
    background-color: {{color2}};
    color: {{background}};
}

#battery.charging {
    background-color: {{color4}};
    color: {{background}};
}

@keyframes blink {
    to {
        background-color: {{color3}};
        color: {{background}};
    }
}

#battery.critical:not(.charging) {
    background: {{color5}};
    color: {{background}};
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#cpu {
    background: {{color3}};
    color: {{background}};
}

#memory {
    background: {{color4}};
    color: {{background}};
}

#backlight {
    background: {{color5}};
    color: {{background}};
}

#network {
    background: {{color6}};
    color: {{background}};
}

#network.disconnected {
    background: {{color5}};
    color: {{background}};
}

#pulseaudio {
    background: {{color7}};
    color: {{background}};
}

#pulseaudio.muted {
    background: {{color8}};
    color: {{background}};
}

#temperature {
    background: {{color9}};
    color: {{background}};
}

#temperature.critical {
    background: {{color5}};
    color: {{background}};
}

#tray {
    background-color: {{color1}};
}

#idle_inhibitor {
    background-color: {{color2}};
}

#custom-launcher {
    background: {{color4}};
    padding: 0 12px;
    margin-left: 6px;
    color: {{background}};
}

#custom-powermenu {
    background: {{color5}};
    padding: 0 12px;
    margin-right: 6px;
    color: {{background}};
}
EOL

# Create Waybar config with Material Design Icons
cat > "$WAYBAR_CONFIG_DIR/config" << 'EOL'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["custom/launcher", "hyprland/workspaces"],
    "modules-center": ["hyprland/window"],
    "modules-right": [
        "tray",
        "network",
        "pulseaudio",
        "cpu",
        "memory",
        "temperature",
        "disk",
        "clock",
        "custom/powermenu"
    ],
    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "format-icons": {
            "1": "󰎤",
            "2": "󰎧",
            "3": "󰎪",
            "4": "󰎭",
            "5": "󰎱",
            "6": "󰎳",
            "7": "󰎶",
            "8": "󰎹",
            "9": "󰎼",
            "10": "󰎿",
            "urgent": "󱃧",
            "active": "󰮯",
            "default": "󰊠"
        }
    },
    "hyprland/window": {
        "format": "{}",
        "max-length": 50
    },
    "tray": {
        "spacing": 10
    },
    "clock": {
        "format": "󰥔 {:%H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "interval": 1
    },
    "cpu": {
        "format": "󰍛 {usage}%",
        "interval": 1
    },
    "memory": {
        "format": "󰍛 {percentage}%",
        "interval": 1
    },
    "temperature": {
        "thermal-zone": 0,
        "hwmon-path": "/sys/class/hwmon/hwmon2/temp1_input",
        "format": "󰔄 {temperatureC}°C",
        "critical-threshold": 80
    },
    "disk": {
        "format": "󰋊 {percentage_used}%",
        "path": "/",
        "interval": 30
    },
    "network": {
        "format-wifi": "󰖩 {essid} ({signalStrength}%)",
        "format-ethernet": "󰈁 {ipaddr}/{cidr}",
        "format-disconnected": "󰖪 Disconnected",
        "interval": 1
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰖁 Muted",
        "format-icons": {
            "headphones": "󰋋",
            "handsfree": "󰋎",
            "headset": "󰋎",
            "phone": "󰋎",
            "portable": "󰋎",
            "car": "󰄋",
            "default": ["󰕿", "󰖀", "󰕾"]
        },
        "scroll-step": 5,
        "on-click": "pavucontrol",
        "on-click-right": "pactl set-sink-mute @DEFAULT_SINK@ toggle"
    },
    "backlight": {
        "device": "intel_backlight",
        "format": "{icon} {percent}%",
        "format-icons": ["󰃞", "󰃟", "󰃠"],
        "on-scroll-up": "brightnessctl set +5%",
        "on-scroll-down": "brightnessctl set 5%-"
    },
    "custom/launcher": {
        "format": "󰣇",
        "on-click": "rofi -show drun",
        "tooltip": false
    },
    "custom/powermenu": {
        "format": "󰐥",
        "on-click": "rofi -show power-menu -modi power-menu:rofi-power-menu",
        "tooltip": false
    }
}
EOL

# Create Rofi config
mkdir -p "$ROFI_CONFIG_DIR"
cat > "$ROFI_CONFIG_DIR/config.rasi" << 'EOL'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Material-Design-Icons";
    display-drun: "󰣇";
    drun-display-format: "{name}";
    sidebar-mode: false;
    lines: 10;
    font: "Material Design Icons, JetBrains Mono 12";
    location: 0;
    width: 30%;
    padding: 20;
    background: @background;
    background-color: @background;
    foreground: @foreground;
    border-color: @color1;
    selected-normal-foreground: @background;
    selected-normal-background: @color4;
    selected-active-foreground: @background;
    selected-active-background: @color5;
    selected-urgent-foreground: @background;
    selected-urgent-background: @color3;
    alternate-normal-background: @background;
    normal-background: @background;
    normal-foreground: @foreground;
    active-background: @color1;
    active-foreground: @foreground;
    urgent-background: @color5;
    urgent-foreground: @foreground;
    alternate-normal-foreground: @foreground;
    alternate-active-background: @color1;
    alternate-active-foreground: @foreground;
    alternate-urgent-background: @color5;
    alternate-urgent-foreground: @foreground;
    spacing: 2;
}

@theme "/dev/null"

element-text, element-icon {
    background-color: inherit;
    text-color: inherit;
}

window {
    background-color: @background;
    border: 1;
    padding: 5;
}

mainbox {
    border: 0;
    padding: 0;
}

message {
    border: 1px dash 0px 0px;
    border-color: @color1;
    padding: 1px;
}

textbox {
    text-color: @foreground;
}

listview {
    fixed-height: 0;
    border: 1px dash 0px 0px;
    border-color: @color1;
    spacing: 2px;
    scrollbar: false;
    padding: 2px 0px 0px;
}

element {
    border: 0;
    padding: 1px;
}

element normal.normal {
    background-color: @color0;
    text-color: @foreground;
}

element normal.urgent {
    background-color: @color5;
    text-color: @foreground;
}

element normal.active {
    background-color: @color1;
    text-color: @foreground;
}

element selected.normal {
    background-color: @color4;
    text-color: @background;
}

element selected.urgent {
    background-color: @color3;
    text-color: @background;
}

element selected.active {
    background-color: @color5;
    text-color: @background;
}

element alternate.normal {
    background-color: @color0;
    text-color: @foreground;
}

element alternate.urgent {
    background-color: @color5;
    text-color: @foreground;
}

element alternate.active {
    background-color: @color1;
    text-color: @foreground;
}

scrollbar {
    width: 4px;
    border: 0;
    handle-width: 8px;
    padding: 0;
}

mode-switcher {
    border: 1px dash 0px 0px;
    border-color: @color1;
}

button {
    padding: 5px;
    text-color: @foreground;
    background-color: @color0;
}

button selected {
    text-color: @background;
    background-color: @color4;
}

inputbar {
    spacing: 0;
    text-color: @foreground;
    padding: 1px;
}

prompt {
    background-color: @color4;
    padding: 6px;
    text-color: @background;
}
EOL

# Create Kitty config that will use pywal colors
cat > "$KITTY_CONFIG_DIR/kitty.conf" << 'EOL'
font_family JetBrains Mono
font_size 11.0
bold_font auto
italic_font auto
bold_italic_font auto
background_opacity 0.9
window_padding_width 5
confirm_os_window_close 0
enable_audio_bell no

# This will be overridden by pywal
include ~/.cache/wal/colors-kitty.conf
EOL

# Configure Nautilus to open Kitty
cat > "$NAUTILUS_SCRIPTS_DIR/Open in Kitty" << 'EOL'
#!/bin/bash
kitty --working-directory="$NAUTILUS_SCRIPT_CURRENT_URI"
EOL
chmod +x "$NAUTILUS_SCRIPTS_DIR/Open in Kitty"

# Set permissions
chown -R $SUDO_USER:$SUDO_USER "$USER_HOME/.config"
chown -R $SUDO_USER:$SUDO_USER "$USER_HOME/.local"

# Initialize wallpaper
sudo -u $SUDO_USER "$HYPRLAND_CONFIG_DIR/scripts/wallpaper.sh" init

echo "Installation complete! Reboot your system to start Hyprland."