#!/bin/bash

# --- Script Initialization and Pre-checks ---

# Set error handling: exit on first error, treat unset variables as errors, pipefail
set -euo pipefail

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Get the original user who invoked sudo for proper file ownership
if [ -z "${SUDO_USER:-}" ]; then
    echo "Error: SUDO_USER environment variable not set. Please run with sudo." >&2
    exit 1
fi
REAL_USER="$SUDO_USER"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Verify internet connection
echo "Checking internet connection..."
if ! curl -sSf --head archlinux.org &> /dev/null; then
    echo "Error: No internet connection. Please connect to the internet before running this script." >&2
    exit 1
fi
echo "Internet connection verified."

# --- System Update and Yay Installation ---

echo "Updating system..."
pacman -Syu --noconfirm || { echo "Error: Failed to update system." >&2; exit 1; }

# Install yay if not installed
if ! command -v yay &> /dev/null; then
    echo "Installing yay (AUR helper)..."
    pacman -S --needed --noconfirm git base-devel || { echo "Error: Failed to install git or base-devel." >&2; exit 1; }

    # Use mktemp for secure temporary directory creation, run as REAL_USER
    # This ensures the directory is owned by REAL_USER from the start and writable.
    TEMP_DIR=$(sudo -u "$REAL_USER" mktemp -d -t yay-install-XXXXXXXX)
    echo "Cloning yay into $TEMP_DIR..."
    sudo -u "$REAL_USER" git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay" || { echo "Error: Failed to clone yay repository." >&2; rm -rf "$TEMP_DIR"; exit 1; }
    
    echo "Building and installing yay..."
    # 'makepkg -si --noconfirm' is crucial for unattended installation
    sudo -u "$REAL_USER" bash -c "cd \"$TEMP_DIR/yay\" && makepkg -si --noconfirm" || { echo "Error: Failed to build and install yay." >&2; rm -rf "$TEMP_DIR"; exit 1; }
    
    rm -rf "$TEMP_DIR"
    echo "Yay installed successfully."
else
    echo "Yay is already installed."
fi

# --- Package Installation ---

echo "Installing required packages..."
# Packages generally available in official Arch repositories
PACMAN_PACKAGES=(
    hyprland sddm waybar kitty rofi dunst
    pulseaudio pulseaudio-alsa pavucontrol gnome-system-monitor blueman network-manager-applet libnotify
    jq wget curl imagemagick grim slurp wl-clipboard brightnessctl
    bluez bluez-utils polkit-gnome xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt5-wayland qt6-wayland
    python-pywal python-pip fastfetch # Added fastfetch
    noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono ttf-font-awesome # Font Awesome for icons
    zsh # Added zsh
    nautilus gedit vlc # Re-added applications
)

if ! pacman -S --noconfirm "${PACMAN_PACKAGES[@]}"; then
    echo "Error: Failed to install one or more core packages with pacman." >&2
    exit 1
fi
echo "Core packages installed."

echo "Installing additional AUR packages..."
# Packages commonly found in the AUR (Arch User Repository)
AUR_PACKAGES=(
    google-chrome
    visual-studio-code-bin
    material-design-icons-git # Material Design Icons for Waybar/Rofi
    rofi-power-menu
    hyprpicker
    zsh-theme-powerlevel10k-git # Powerlevel10k Zsh theme
    oh-my-zsh-git # Oh My Zsh, P10k often relies on it
    ttf-meslo-nerd-font-powerlevel10k # Recommended font for Powerlevel10k
)

if ! sudo -u "$REAL_USER" yay -S --noconfirm "${AUR_PACKAGES[@]}"; then
    echo "Error: Failed to install one or more AUR packages with yay." >&2
    exit 1
fi
echo "AUR packages installed."

# --- Service Enablement ---

echo "Enabling services..."
SERVICES=(sddm bluetooth)
for service in "${SERVICES[@]}"; do
    if systemctl enable "$service"; then
        echo "Enabled $service."
    else
        echo "Warning: Failed to enable $service." >&2
    fi
done

# --- User Directories Creation ---

echo "Creating user directories for $REAL_USER..."
sudo -u "$REAL_USER" xdg-user-dirs-update || { echo "Warning: Failed to update xdg user directories." >&2; }

# --- Hyprland Configuration ---

echo "Configuring Hyprland for $REAL_USER..."

# Define configuration directories
HYPRLAND_CONFIG_DIR="$USER_HOME/.config/hypr"
WAYBAR_CONFIG_DIR="$USER_HOME/.config/waybar"
ROFI_CONFIG_DIR="$USER_HOME/.config/rofi"
KITTY_CONFIG_DIR="$USER_HOME/.config/kitty"
WAL_CONFIG_DIR="$USER_HOME/.config/wal"
DUNST_CONFIG_DIR="$USER_HOME/.config/dunst"
NAUTILUS_SCRIPTS_DIR="$USER_HOME/.local/share/nautilus/scripts"
WALLPAPER_DIR="$USER_HOME/Pictures/wallpapers"
ZSH_CONFIG_DIR="$USER_HOME" # .zshrc is in home dir

# Create directories and set ownership immediately
declare -a config_dirs=(
    "$HYPRLAND_CONFIG_DIR/scripts"
    "$WAYBAR_CONFIG_DIR"
    "$ROFI_CONFIG_DIR"
    "$KITTY_CONFIG_DIR"
    "$WAL_CONFIG_DIR/templates"
    "$DUNST_CONFIG_DIR"
    "$NAUTILUS_SCRIPTS_DIR"
    "$WALLPAPER_DIR"
)

for dir in "${config_dirs[@]}"; do
    if mkdir -p "$dir"; then
        chown "$REAL_USER":"$REAL_USER" "$dir"
        echo "Created and set ownership for $dir"
    else
        echo "Error: Failed to create directory $dir." >&2
        exit 1
    fi
done

# Create Hyprland config file
echo "Creating $HYPRLAND_CONFIG_DIR/hyprland.conf..."
cat > "$HYPRLAND_CONFIG_DIR/hyprland.conf" << EOL
# Monitor configuration
monitor=,preferred,auto,1

# Autostart
# Ensure hyprpaper is started cleanly and as a background process
exec-once = killall -q hyprpaper && hyprpaper & disown
# This will handle initial wallpaper setting and pywal theming at Hyprland login
exec-once = \$HOME/.config/hypr/scripts/wallpaper.sh init
exec-once = waybar
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 # For policykit authentication
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = dunst # Notification daemon

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
\$mainMod = SUPER

# Applications
bind = \$mainMod, RETURN, exec, kitty
bind = \$mainMod, B, exec, google-chrome-stable
bind = \$mainMod, E, exec, nautilus
bind = \$mainMod, C, exec, code # Assuming 'code' executable for VS Code
bind = \$mainMod, G, exec, gedit
bind = \$mainMod, V, exec, vlc
bind = \$mainMod, R, exec, rofi -show drun
bind = \$mainMod, M, exec, gnome-system-monitor

# Window management
bind = \$mainMod, Q, killactive,
bind = \$mainMod, F, fullscreen,
bind = \$mainMod, Space, togglefloating,
bind = \$mainMod, P, pseudo, # dwindle
bind = \$mainMod, S, togglesplit, # dwindle

# Move focus
bind = \$mainMod, left, movefocus, l
bind = \$mainMod, right, movefocus, r
bind = \$mainMod, up, movefocus, u
bind = \$mainMod, down, movefocus, d

# Switch workspaces
bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10

# Move active window to workspace
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9
bind = \$mainMod SHIFT, 0, movetoworkspace, 10

# Scroll through workspaces
bind = \$mainMod, mouse_down, workspace, e+1
bind = \$mainMod, mouse_up, workspace, e-1

# Move/resize windows
bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow

# Screenshots
bind = , Print, exec, grim -g "\$(slurp)" - | wl-copy
bind = \$mainMod, Print, exec, grim - | wl-copy

# Media controls
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
bind = \$mainMod, Escape, exec, rofi -show power-menu -modi power-menu:rofi-power-menu

# Wallpaper controls
bind = \$mainMod SHIFT, W, exec, \$HOME/.config/hypr/scripts/wallpaper.sh change

# Exit Hyprland (no direct lock screen binding as sddm handles it)
bind = \$mainMod SHIFT, Q, exit,
EOL
chown "$REAL_USER":"$REAL_USER" "$HYPRLAND_CONFIG_DIR/hyprland.conf"

# Create wallpaper script with multiple sources and Material You theming
echo "Creating $HYPRLAND_CONFIG_DIR/scripts/wallpaper.sh..."
cat > "$HYPRLAND_CONFIG_DIR/wallpaper.sh" << EOL
#!/bin/bash

WALLPAPER_DIR="$WALLPAPER_DIR"

# List of wallpaper sources (multiple providers)
SOURCES=(
    "https://source.unsplash.com/random/3840x2160/?nature"
    "https://source.unsplash.com/random/3840x2160/?landscape"
    "https://source.unsplash.com/random/3840x2160/?city"
    "https://source.unsplash.com/random/3840x2160/?space"
    "https://picsum.photos/3840/2160" # Often more reliable
    "https://random.imagecdn.app/3840/2160" # Another alternative
    "https://source.unsplash.com/random/3840x2160/?abstract"
)

# Function to check internet connection
check_internet() {
    curl -sSf --head archlinux.org &> /dev/null
}

# Function to try downloading from multiple sources
download_wallpaper() {
    if ! check_internet; then
        echo "No internet connection. Cannot download new wallpaper." >&2
        return 1
    fi

    for source in "\${SOURCES[@]}"; do
        local filename="wallpaper_\$(date +%s).jpg"
        local filepath="\$WALLPAPER_DIR/\$filename"
        
        echo "Trying source: \$source"
        # Increased timeout and retries for robustness
        if wget -q --tries=5 --timeout=20 "\$source" -O "\$filepath"; then
            # Verify the downloaded file is actually an image using file command
            if file "\$filepath" | grep -q "image data"; then
                echo "\$filepath"
                return 0
            else
                echo "Downloaded file is not a valid image: \$filepath" >&2
                rm -f "\$filepath"
            fi
        else
            echo "Failed to download from \$source" >&2
        fi
    done
    
    echo "All online sources failed. Cannot download new wallpaper." >&2
    return 1
}

# Function to set wallpaper and apply Material You theming
set_wallpaper() {
    local wallpaper="\$1"
    
    if [[ -f "\$wallpaper" ]]; then
        echo "Setting wallpaper: \$wallpaper"
        # Set wallpaper with hyprpaper
        # IMPORTANT: Replace eDP-1 with your actual monitor name (e.g., HDMI-A-1, DP-1)
        # Use 'hyprctl monitors' in terminal to find your monitor name.
        hyprctl hyprpaper preload "\$wallpaper" 2>/dev/null || echo "Warning: Failed to preload wallpaper." >&2
        hyprctl hyprpaper wallpaper "eDP-1,\$wallpaper" 2>/dev/null || echo "Warning: Failed to set wallpaper." >&2
        hyprctl hyprpaper unload all 2>/dev/null # Unload old wallpapers after setting new one
        
        # Generate Material You colors using pywal
        echo "Generating pywal colors from \$wallpaper..."
        wal -i "\$wallpaper" -n -q --backend wal || echo "Warning: Pywal failed to generate colors." >&2
        
        # Apply generated colors to applications
        # Source Xresources for terminal (Kitty reads this on restart/refresh)
        if [ -f "\$HOME/.cache/wal/colors.Xresources" ]; then
            xrdb -merge "\$HOME/.cache/wal/colors.Xresources" || echo "Warning: Failed to merge Xresources." >&2
        fi
        
        # Reload Waybar to apply new colors (from colors.css template)
        if pgrep -x "waybar" > /dev/null; then
            echo "Reloading Waybar..."
            killall -q waybar
            waybar &> /dev/null & disown
        else
            echo "Waybar not running, skipping reload." >&2
        fi
        
        # Update Kitty colors (kitty.conf references wal template)
        if pgrep -x "kitty" > /dev/null; then
            echo "Updating Kitty colors..."
            kitty @ set-colors --all --configured "\$HOME/.cache/wal/colors-kitty.conf" || echo "Warning: Failed to update Kitty colors." >&2
        else
            echo "Kitty not running, skipping color update." >&2
        fi

        # Rofi will pick up new colors on next launch as it sources colors-rofi-dark.rasi linked from wal template
        echo "Rofi will pick up new colors on next launch."

        # Other applications (Nautilus, Gedit) will pick up GTK changes via xdg-desktop-portal-gtk
    else
        echo "Error: Wallpaper file not found: \$wallpaper" >&2
        return 1
    fi
}

# Main function
main() {
    local action="\${1:-"change"}" # Default action is 'change'

    case "\$action" in
        init)
            # On startup, try to load the most recent wallpaper first
            local recent_wallpaper=\$(ls -t "\$WALLPAPER_DIR"/*.jpg 2>/dev/null | head -n 1)
            if [[ -n "\$recent_wallpaper" ]]; then
                echo "Initializing with recent wallpaper: \$recent_wallpaper"
                set_wallpaper "\$recent_wallpaper"
            else
                echo "No local wallpapers found. Attempting to download for initialization."
                new_wallpaper=\$(download_wallpaper)
                if [[ -n "\$new_wallpaper" ]]; then
                    set_wallpaper "\$new_wallpaper"
                else
                    echo "Could not initialize wallpaper. No local or downloadable wallpapers available." >&2
                fi
            fi
            ;;
        change)
            # Try to download new wallpaper
            new_wallpaper=\$(download_wallpaper)
            
            if [[ -n "\$new_wallpaper" ]]; then
                echo "Changing to new wallpaper: \$new_wallpaper"
                set_wallpaper "\$new_wallpaper"
                
                # Clean up old wallpapers (keep last 10)
                echo "Cleaning up old wallpapers (keeping last 10)..."
                ls -t "\$WALLPAPER_DIR"/*.jpg 2>/dev/null | tail -n +11 | xargs -r rm -f
            else
                echo "Download failed. Using random local wallpaper if available."
                local_wallpapers=(\"\$WALLPAPER_DIR\"/*.jpg)
                if [[ \${#local_wallpapers[@]} -gt 0 && -f "\${local_wallpapers[0]}" ]]; then
                    random_wallpaper=\${local_wallpapers[\$RANDOM % \${#local_wallpapers[@]}]}
                    echo "Using random local wallpaper: \$random_wallpaper"
                    set_wallpaper "\$random_wallpaper"
                else
                    echo "No local wallpapers available to change to." >&2
                G
                fi
            fi
            ;;
        *)
            echo "Usage: \$0 [init|change]" >&2
            exit 1
            ;;
    esac
}

main "\$@"
EOL
chmod +x "$HYPRLAND_CONFIG_DIR/wallpaper.sh" # Fix: changed path from scripts/wallpaper.sh to wallpaper.sh
chown "$REAL_USER":"$REAL_USER" "$HYPRLAND_CONFIG_DIR/wallpaper.sh" # Fix: changed path

# Create Material You templates for Waybar
echo "Creating $WAL_CONFIG_DIR/templates/waybar.css..."
cat > "$WAL_CONFIG_DIR/templates/waybar.css" << EOL
/*
 * Waybar Material You Theme Template
 * Generated by pywal
 */

* {
    border: none;
    border-radius: 0;
    /* Prioritize JetBrains Mono for text, then icons */
    font-family: "JetBrains Mono Nerd Font", "Material Design Icons", "Font Awesome 6 Free", sans-serif;
    font-size: 12px;
    min-height: 0;
    /* Default text color, will be overridden by specific module colors */
    color: {{foreground}}; 
}

window#waybar {
    background: transparent; /* Make Waybar background transparent */
    color: {{foreground}}; /* Default text color */
    border-bottom: 0px solid transparent; /* No bottom border for clean look */
}

/* Modules without background to show only icon/text */
#workspaces,
#clock,
#battery,
#cpu,
#memory,
#temperature,
#backlight,
#network,
#pulseaudio,
#tray,
#mode,
#idle_inhibitor,
#custom-powermenu,
#disk {
    background: transparent;
    padding: 0 8px; /* Slightly more padding for better spacing */
    margin: 0; /* No margin between modules, padding handles spacing */
    color: {{foreground}}; /* Default text color for modules */
}

#workspaces button {
    padding: 0 8px;
    background: transparent;
    color: {{color8}}; /* Light gray for inactive workspaces */
    border-bottom: 0px solid transparent;
}

#workspaces button.active {
    background: transparent;
    color: {{color4}}; /* Accent color for active workspace */
    border-bottom: 0px solid {{color4}}; /* Subtle accent line */
    font-weight: bold;
}

#workspaces button.focused {
    background: transparent;
    color: {{color4}}; /* Accent color for focused workspace */
    border-bottom: 0px solid {{color4}}; /* Subtle accent line */
    font-weight: bold;
}

#workspaces button.urgent {
    background: transparent;
    color: {{color5}}; /* Red for urgent workspace */
    border-bottom: 0px solid {{color5}};
}

/* Specific module text colors (if different from foreground) */
#clock {
    color: {{color1}}; /* Example: Primary accent for clock */
}

#battery {
    color: {{color2}}; /* Example: Secondary accent for battery */
}
#battery.charging {
    color: {{color4}}; /* Green for charging */
}
#battery.critical {
    color: {{color5}}; /* Red for critical battery */
}

#cpu {
    color: {{color3}};
}

#memory {
    color: {{color4}};
}

#backlight {
    color: {{color5}};
}

#network {
    color: {{color6}};
}

#pulseaudio {
    color: {{color7}};
}
#pulseaudio.muted {
    color: {{color8}}; /* Muted color */
}

#temperature {
    color: {{color9}};
}
#temperature.critical {
    color: {{color5}};
}

#tray {
    color: {{color1}}; /* Consistent with launcher */
}

#custom-launcher {
    color: {{color4}}; /* Main accent color */
    padding: 0 12px; /* More padding for launcher button */
    margin-left: 6px;
    font-size: 16px; /* Slightly larger icon */
}

#custom-powermenu {
    color: {{color5}}; /* Red accent for power menu */
    padding: 0 12px;
    margin-right: 6px;
    font-size: 16px; /* Slightly larger icon */
}

/* Tooltips */
#tooltip {
    background: {{background}};
    border: 1px solid {{color4}};
    border-radius: 5px;
    padding: 5px 10px;
    font-size: 12px;
    color: {{foreground}};
}
EOL
chown "$REAL_USER":"$REAL_USER" "$WAL_CONFIG_DIR/templates/waybar.css"

# Create Waybar config with Material Design Icons and proper modules
echo "Creating $WAYBAR_CONFIG_DIR/config..."
cat > "$WAYBAR_CONFIG_DIR/config" << EOL
{
    "layer": "top",
    "position": "top",
    "height": 32, /* Slightly taller for better icon visibility */
    "spacing": 0, /* Spacing handled by module padding in CSS */
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["hyprland/window"],
    "modules-right": [
        "tray",
        "network",
        "pulseaudio",
        "cpu",
        "memory",
        "battery", /* Battery module */
        "temperature",
        "disk",
        "clock",
        "custom/powermenu"
    ],
    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "format-icons": {
            "1": "󰎤", /* Material Design Icons */
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
        "tooltip-format": "<big>{:%Y %B}</big>\\n<tt><small>{calendar}</small></tt>",
        "interval": 1
    },
    "cpu": {
        "format": "󰍛 {usage}%", /* Material Design Icon for CPU */
        "interval": 1
    },
    "memory": {
        "format": "󰍛 {percentage}%", /* Material Design Icon for Memory */
        "interval": 1
    },
    "battery": {
        "format": "{icon} {capacity}%",
        "format-charging": "󰂄 {capacity}%", /* Charging icon */
        "format-plugged": "󰢟 {capacity}%", /* Plugged in (not necessarily charging) */
        "format-alt": "{time} {icon}", /* Show time remaining on alt-click */
        "format-full": "󰁹 {capacity}%", /* Full battery icon */
        "format-icons": ["󰂃", "󰂂", "󰂁", "󰂀", "󰁿", "󰁾", "󰁽", "󰁼", "󰁻", "󰁺"], /* Material Design Icons, low to high */
        "states": {
            "warning": 20, /* Less than or equal to 20% */
            "critical": 10 /* Less than or equal to 10% */
        },
        "interval": 60
    },
    "temperature": {
        "thermal-zone": 0,
        "hwmon-path": "/sys/class/hwmon/hwmon2/temp1_input", /* IMPORTANT: This path might be different on your system. Run 'ls /sys/class/hwmon/' to find your sensor. */
        "format": "󰔄 {temperatureC}°C", /* Material Design Icon for Temperature */
        "critical-threshold": 80
    },
    "disk": {
        "format": "󰋊 {percentage_used}%", /* Material Design Icon for Disk */
        "path": "/",
        "interval": 30
    },
    "network": {
        "format-wifi": "󰖩 {essid} ({signalStrength}%)", /* Wifi icon */
        "format-ethernet": "󰈁 {ipaddr}/{cidr}", /* Ethernet icon */
        "format-disconnected": "󰖪 Disconnected", /* Disconnected icon */
        "interval": 1
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "󰖁 Muted", /* Muted icon */
        "format-icons": {
            "headphones": "󰋋",
            "handsfree": "󰋎",
            "headset": "󰋎",
            "phone": "󰋎",
            "portable": "󰋎",
            "car": "󰄋",
            "default": ["󰕿", "󰖀", "󰕾"] /* Material Design Icons */
        },
        "scroll-step": 5,
        "on-click": "pavucontrol",
        "on-click-right": "pactl set-sink-mute @DEFAULT_SINK@ toggle"
    },
    "backlight": {
        "device": "intel_backlight",
        "format": "{icon} {percent}%",
        "format-icons": ["󰃞", "󰃟", "󰃠"], /* Material Design Icons */
        "on-scroll-up": "brightnessctl set +5%",
        "on-scroll-down": "brightnessctl set 5%-"
    },
    "custom/powermenu": {
        "format": "󰐥", /* Material Design Icon for Power */
        "on-click": "rofi -show power-menu -modi power-menu:rofi-power-menu",
        "tooltip": false
    }
}
EOL
chown "$REAL_USER":"$REAL_USER" "$WAYBAR_CONFIG_DIR/config"

# Create Waybar style.css (separate from config for theming)
echo "Creating $WAYBAR_CONFIG_DIR/style.css..."
cat > "$WAYBAR_CONFIG_DIR/style.css" << EOL
/* This file is generated by pywal's template in ~/.config/wal/templates/waybar.css */
/* Do not edit this file directly. Edit the template instead. */
@import url("\$HOME/.cache/wal/colors.css");
EOL
chown "$REAL_USER":"$REAL_USER" "$WAYBAR_CONFIG_DIR/style.css"


# Create Rofi config that will use pywal colors
echo "Creating $WAL_CONFIG_DIR/templates/rofi.rasi..."
cat > "$WAL_CONFIG_DIR/templates/rofi.rasi" << EOL
/* Rofi Material You Theme Template */
/* Generated by pywal */

configuration {
    modi: "drun,run,window,power-menu"; /* Added power-menu modi */
    show-icons: true;
    icon-theme: "Material-Design-Icons"; /* Use Material Design Icons, instead of Adwaita */
    display-drun: "󰣇"; /* Launcher icon */
    drun-display-format: "{name}";
    sidebar-mode: false;
    lines: 8; /* Fewer lines for a cleaner look */
    font: "JetBrains Mono Nerd Font 12";
    location: 0; /* Center */
    width: 30%;
    padding: 20;
    
    /* Colors from pywal */
    background: @background;
    background-color: @background;
    foreground: @foreground;
    border-color: @color4; /* Accent border */
    
    selected-normal-foreground: @background;
    selected-normal-background: @color4; /* Highlight color */
    
    selected-active-foreground: @background;
    selected-active-background: @color5; /* Another accent */
    
    selected-urgent-foreground: @background;
    selected-urgent-background: @color3; /* Warning/urgent color */
    
    normal-background: @background;
    normal-foreground: @foreground;
    
    active-background: @color1;
    active-foreground: @foreground;
    
    urgent-background: @color5;
    urgent-foreground: @foreground;
    
    alternate-normal-background: @background;
    alternate-normal-foreground: @foreground;
    
    alternate-active-background: @color1;
    alternate-active-foreground: @foreground;
    
    alternate-urgent-background: @color5;
    alternate-urgent-foreground: @foreground;
    
    spacing: 5; /* Increased spacing */
    yoffset: -100; /* Move slightly up from center */
}

/* Base theme */
@theme "/dev/null"

element-text, element-icon {
    background-color: inherit;
    text-color: inherit;
}

window {
    background-color: @background;
    border: 2px; /* Border thickness */
    border-color: @border-color;
    border-radius: 10px; /* Rounded corners for Rofi */
    padding: 20px; /* Internal padding */
}

mainbox {
    border: 0;
    padding: 0;
}

message {
    border: 0px; /* No border for message */
    padding: 1px;
}

textbox {
    text-color: @foreground;
    border: 0px;
    padding: 5px;
}

listview {
    fixed-height: 0;
    border: 0px; /* No border for listview */
    spacing: 5px; /* Spacing between elements */
    scrollbar: false;
    padding: 5px 0px 0px;
}

element {
    border: 0;
    padding: 8px 10px; /* Padding for each entry */
    border-radius: 5px; /* Rounded corners for elements */
}

element normal.normal {
    background-color: @normal-background;
    text-color: @normal-foreground;
}

element normal.urgent {
    background-color: @urgent-background;
    text-color: @urgent-foreground;
}

element normal.active {
    background-color: @active-background;
    text-color: @active-foreground;
}

element selected.normal {
    background-color: @selected-normal-background;
    text-color: @selected-normal-foreground;
}

element selected.urgent {
    background-color: @selected-urgent-background;
    text-color: @selected-urgent-foreground;
}

element selected.active {
    background-color: @selected-active-background;
    text-color: @selected-active-foreground;
}

element alternate.normal {
    background-color: @alternate-normal-background;
    text-color: @alternate-normal-foreground;
}

element alternate.urgent {
    background-color: @alternate-urgent-background;
    text-color: @alternate-urgent-foreground;
}

element alternate.active {
    background-color: @alternate-active-background;
    text-color: @alternate-active-foreground;
}

scrollbar {
    width: 0px; /* Hide scrollbar */
}

mode-switcher {
    border: 0px; /* No border for mode switcher */
    margin-top: 10px;
}

button {
    padding: 8px 15px; /* Button padding */
    text-color: @foreground;
    background-color: @background;
    border: 1px solid @color8; /* Subtle button border */
    border-radius: 5px; /* Rounded buttons */
}

button selected {
    text-color: @background;
    background-color: @color4; /* Selected button color */
    border-color: @color4;
}

inputbar {
    spacing: 10px; /* Spacing for input elements */
    text-color: @foreground;
    padding: 10px;
    background-color: @color0; /* Darker background for input bar */
    border-radius: 5px;
}

prompt {
    background-color: @color4;
    padding: 8px 10px;
    text-color: @background;
    border-radius: 5px;
}
EOL
chown "$REAL_USER":"$REAL_USER" "$WAL_CONFIG_DIR/templates/rofi.rasi"

# Link Rofi config to the wal-generated one
sudo -u "$REAL_USER" ln -sf "$USER_HOME/.cache/wal/colors-rofi-dark.rasi" "$ROFI_CONFIG_DIR/config.rasi" || echo "Warning: Failed to create rofi config symlink." >&2


# Create Kitty config that will use pywal colors and run fastfetch
echo "Creating $KITTY_CONFIG_DIR/kitty.conf..."
cat > "$KITTY_CONFIG_DIR/kitty.conf" << EOL
font_family JetBrains Mono Nerd Font
font_size 11.0
bold_font auto
italic_font auto
bold_italic_font auto
background_opacity 0.8 # Slightly less opaque than before for more blur visibility
window_padding_width 5
confirm_os_window_close 0
enable_audio_bell no
shell zsh -c "fastfetch; zsh" # Run fastfetch then zsh

# This will be overridden by pywal's generated colors
include \$HOME/.cache/wal/colors-kitty.conf
EOL
chown "$REAL_USER":"$REAL_USER" "$KITTY_CONFIG_DIR/kitty.conf"

# Configure Dunst
echo "Creating $DUNST_CONFIG_DIR/dunstrc..."
cat > "$DUNST_CONFIG_DIR/dunstrc" << EOL
[global]
    # Geometry
    geometry = "300x5-30+20"
    # show notification on top of fullscreen windows
    fullscreen = show

    # Font
    font = JetBrains Mono Nerd Font 10
    line_height = 0
    markup = full
    format = "<b>%s</b>\\n%b"

    # Frame
    frame_width = 1
    frame_color = "#89B4FA" # Blue accent

    # Icons
    icon_position = left
    icon_theme = Adwaita # Default Adwaita, user can change
    
    # Colors (these will be overridden by pywal, but good defaults)
    background = "#1E1E2E"
    foreground = "#CDD6F4"
    highlight = "#89B4FA"

    # Transparency
    transparency = 10 # Dunst can have its own transparency

    # Timing
    notification_icon_size = 32
    startup_notification = true
    sticky_history = true
    history_length = 20
    shrink = no
    indicate_hidden = yes
    world_readable = yes
    mouse_left_click = close_current
    mouse_right_click = close_all
    mouse_middle_click = do_action

[urgency_low]
    background = "#1E1E2E"
    foreground = "#CDD6F4"
    timeout = 10

[urgency_normal]
    background = "#1E1E2E"
    foreground = "#CDD6F4"
    timeout = 10

[urgency_critical]
    background = "#1E1E2E"
    foreground = "#CDD6F4"
    timeout = 20
    frame_color = "#F38BA8" # Red for critical
EOL
chown "$REAL_USER":"$REAL_USER" "$DUNST_CONFIG_DIR/dunstrc"

# Configure Nautilus to open Kitty
echo "Creating $NAUTILUS_SCRIPTS_DIR/Open in Kitty..."
cat > "$NAUTILUS_SCRIPTS_DIR/Open in Kitty" << EOL
#!/bin/bash
kitty --working-directory="\$NAUTILUS_SCRIPT_CURRENT_URI"
EOL
chmod +x "$NAUTILUS_SCRIPTS_DIR/Open in Kitty"
chown "$REAL_USER":"$REAL_USER" "$NAUTILUS_SCRIPTS_DIR/Open in Kitty"

# Configure Zsh and Powerlevel10k
echo "Configuring Zsh and Powerlevel10k for $REAL_USER..."
# Change default shell to zsh
if ! chsh -s "$(which zsh)" "$REAL_USER"; then
    echo "Warning: Failed to change default shell for $REAL_USER to zsh. You may need to do this manually: chsh -s \$(which zsh) $REAL_USER" >&2
fi

# Set Powerlevel10k theme in .zshrc
# Check if .zshrc exists, create if not
if [ ! -f "$ZSH_CONFIG_DIR/.zshrc" ]; then
    echo "# .zshrc - Auto-generated by Hyprland setup script" | sudo -u "$REAL_USER" tee "$ZSH_CONFIG_DIR/.zshrc" > /dev/null
fi

# Ensure Oh My Zsh is sourced before P10k
if ! sudo -u "$REAL_USER" grep -q "source \$ZSH/oh-my-zsh.sh" "$ZSH_CONFIG_DIR/.zshrc"; then
    echo 'export ZSH="$HOME/.oh-my-zsh"' | sudo -u "$REAL_USER" tee -a "$ZSH_CONFIG_DIR/.zshrc" > /dev/null
    echo 'source "$ZSH/oh-my-zsh.sh"' | sudo -u "$REAL_USER" tee -a "$ZSH_CONFIG_DIR/.zshrc" > /dev/null
fi

# Set Powerlevel10k theme
# Use sed -i to replace if ZSH_THEME exists, otherwise append
sudo -u "$REAL_USER" sed -i '/^ZSH_THEME=/cZSH_THEME="powerlevel10k\/powerlevel10k"' "$ZSH_CONFIG_DIR/.zshrc" || \
sudo -u "$REAL_USER" bash -c 'echo "ZSH_THEME=\"powerlevel10k/powerlevel10k\"" >> ~/.zshrc'

# Add powerlevel10k sourcing if not present and ensure it's at the end
if ! sudo -u "$REAL_USER" grep -q "source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme" "$ZSH_CONFIG_DIR/.zshrc"; then
    echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' | sudo -u "$REAL_USER" tee -a "$ZSH_CONFIG_DIR/.zshrc" > /dev/null
fi

chown "$REAL_USER":"$REAL_USER" "$ZSH_CONFIG_DIR/.zshrc"


# --- Final Steps ---

echo "--- Installation Complete ---"
echo "Hyprland and its components have been installed and configured."
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Reboot your system: sudo reboot"
echo "2. After reboot, at the SDDM login screen, select 'Hyprland' session."
echo "3. Once in Hyprland, open a terminal (Kitty)."
echo "   - You might be prompted by Powerlevel10k to run 'p10k configure'. Follow the wizard to set up your Zsh prompt."
echo "   - **CRITICAL:** Run 'hyprctl monitors' in your terminal and note your primary monitor's name (e.g., eDP-1, HDMI-A-1)."
echo "   - **Then, manually edit ~/.config/hypr/wallpaper.sh** and change 'eDP-1' to your actual monitor name. Pay attention to the path, it's directly in ~/.config/hypr/"
echo "   - You can re-run '~/.config/hypr/wallpaper.sh init' to apply the wallpaper correctly with your monitor name and pywal colors."
echo "   - **Waybar Temperature:** You might need to adjust 'hwmon-path' in ~/.config/waybar/config if the temperature module doesn't show data. Run 'ls -l /sys/class/hwmon/hwmon*/temp*_input' to find the correct path for your system."
echo "4. Explore your new Hyprland setup! Your Waybar, Rofi, and Kitty should be themed dynamically."
echo "5. If you encounter issues, check the logs (journalctl -u sddm, journalctl -e, journalctl --user -u hyprland.service -f)."
