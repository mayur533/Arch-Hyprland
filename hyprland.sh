#!/bin/bash

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "❌ This script should not be run as root. It will ask for sudo when needed."
    exit 1
fi

# Function to install packages with error handling
install_packages() {
    sudo pacman -S --needed --noconfirm "$@" || {
        echo "❌ Failed to install packages: $*"
        exit 1
    }
}

# Function to install AUR packages with error handling
install_aur_packages() {
    yay -S --needed --noconfirm "$@" || {
        echo "❌ Failed to install AUR packages: $*"
        exit 1
    }
}

echo "🔄 Updating system..."
sudo pacman -Syu --noconfirm

# Install yay if not installed
if ! command -v yay &>/dev/null; then
    echo "⬇️ Installing yay..."
    install_packages base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    rm -rf /tmp/yay
fi

# Remove conflicting portals and install correct ones
echo "🔧 Setting up portals..."
sudo pacman -Rns --noconfirm xdg-desktop-portal-gtk || true
install_packages xdg-desktop-portal-hyprland xdg-desktop-portal

# Install required packages from official repo
echo "📦 Installing official packages..."
install_packages hyprland hyprpaper rofi kitty networkmanager bluez bluez-utils \
    pavucontrol gnome-system-monitor vlc gedit gnome-keyring sddm nautilus \
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono ttf-font-awesome gtk-layer-shell \
    wl-clipboard grim slurp polkit-gnome brightnessctl playerctl socat \
    network-manager-applet blueman

# Install AUR packages
echo "📦 Installing AUR packages..."
install_aur_packages google-chrome visual-studio-code-bin waybar-hyprland-git nerd-fonts-jetbrains-mono ttf-font-awesome-6

# Enable required services
echo "✅ Enabling services..."
sudo systemctl enable --now NetworkManager bluetooth sddm

# Configure Hyprland
echo "🛠️ Configuring Hyprland..."
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
[...Hyprland config remains unchanged for brevity...]
EOF

# Download wallpaper
mkdir -p ~/.config/hypr/hyprpaper
cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = ~/.config/hypr/wallpaper.jpg
wallpaper = ,~/.config/hypr/wallpaper.jpg
EOF

curl -Lo ~/.config/hypr/wallpaper.jpg https://wallpapercave.com/wp/wp9566386.jpg

# Configure Waybar
mkdir -p ~/.config/waybar
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["hyprland/workspaces", "custom/media"],
    "modules-center": ["hyprland/window"],
    "modules-right": ["tray", "network", "bluetooth", "pulseaudio", "backlight", "battery", "clock"],

    "hyprland/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "",
            "2": "",
            "3": "",
            "4": "",
            "5": "",
            "6": "",
            "7": "",
            "8": "",
            "9": "",
            "10": ""
        }
    },

    "custom/media": {
        "format": "{}",
        "max-length": 30,
        "exec": "$HOME/.config/waybar/mediaplayer.sh 2> /dev/null",
        "on-click": "playerctl play-pause",
        "on-click-right": "playerctl next",
        "on-scroll-up": "playerctl previous",
        "on-scroll-down": "playerctl next",
        "escape": true
    },

    "hyprland/window": {
        "max-length": 50,
        "format": "{} "
    },

    "tray": {
        "spacing": 10,
        "icon-size": 16
    },

    "network": {
        "format-wifi": " {signalStrength}%",
        "format-ethernet": "",
        "format-disconnected": "󰌙",
        "tooltip-format": "{ifname}: {ipaddr}/{cidr}",
        "on-click": "nm-connection-editor"
    },

    "bluetooth": {
        "format": " {status}",
        "format-connected": "",
        "format-disabled": "󰂲",
        "on-click": "blueman-manager"
    },

    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "",
        "format-icons": {
            "headphones": "",
            "default": ["", ""]
        },
        "on-click": "pavucontrol"
    },

    "backlight": {
        "format": "{icon} {percent}%",
        "format-icons": ["", "", "", ""],
        "on-scroll-up": "brightnessctl set +5%",
        "on-scroll-down": "brightnessctl set 5%-"
    },

    "battery": {
        "states": {
            "good": 90,
            "warning": 50,
            "critical": 20
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["󰁺", "󰁼", "󰁽", "󰁿", "󰂁"]
    },

    "clock": {
        "format": " {:%I:%M %p}  {:%d/%m}",
        "tooltip-format": "{:%A, %B %d, %Y (%I:%M %p)}"
    }
}
EOF

# Waybar media script
cat > ~/.config/waybar/mediaplayer.sh << 'EOF'
#!/bin/sh
player_status=$(playerctl status 2>/dev/null)
if [ "$player_status" = "Playing" ]; then
    echo " $(playerctl metadata artist) - $(playerctl metadata title)"
elif [ "$player_status" = "Paused" ]; then
    echo " $(playerctl metadata artist) - $(playerctl metadata title)"
else
    echo ""
fi
EOF
chmod +x ~/.config/waybar/mediaplayer.sh

# Waybar style
cat > ~/.config/waybar/style.css << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free", sans-serif;
    font-size: 12px;
    min-height: 0;
}

window#waybar {
    background: rgba(43, 48, 59, 0.9);
    color: white;
    border-bottom: 1px solid rgba(100, 114, 125, 0.5);
}

#workspaces button {
    padding: 0 5px;
    background: transparent;
    color: white;
    border-bottom: 3px solid transparent;
}

#workspaces button.focused {
    background: #64727D;
    border-bottom: 3px solid white;
}

#workspaces button.urgent {
    background-color: #eb4d4b;
}

#custom-media {
    min-width: 100px;
    padding: 0 10px;
    color: #7bc8a4;
    background: #64727D;
    border-radius: 5px;
    margin: 0 5px;
}

#clock, #battery, #cpu, #memory, #network, #pulseaudio, #tray, #bluetooth, #backlight {
    padding: 0 10px;
    margin: 0 5px;
}

#battery.charging {
    color: #26A65B;
}

#battery.warning:not(.charging) {
    color: #f53c3c;
}

#battery.critical:not(.charging) {
    background: #f53c3c;
    color: white;
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#network.disconnected {
    background: #f53c3c;
}

#pulseaudio.muted {
    color: #f53c3c;
}

#tray {
    background-color: #2980b9;
}

@keyframes blink {
    to {
        background-color: #ffffff;
        color: black;
    }
}
EOF

# Kitty config
mkdir -p ~/.config/kitty
cat > ~/.config/kitty/kitty.conf << 'EOF'
font_family JetBrainsMono Nerd Font
font_size 12
background_opacity 0.9
EOF

# Rofi config
mkdir -p ~/.config/rofi
cat > ~/.config/rofi/config.rasi << 'EOF'
configuration {
    modi: "drun";
    icon-theme: "Papirus";
    show-icons: true;
    terminal: "kitty";
    drun-display-format: "{icon} {name}";
    location: 0;
    disable-history: false;
    sidebar-mode: false;
}
EOF

# Refresh fonts
fc-cache -fv

echo -e "\n✅ All done! Reboot your system to start using Hyprland with Waybar and 12-hour clock format."
