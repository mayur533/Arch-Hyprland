#!/bin/bash

# Configuration
LOG_FILE="hyprland_install_$(date +%Y%m%d_%H%M%S).log"
MISSING_PACKAGES_LOG="missing_packages.log"

# Initialize logs
echo "Hyprland Installation Log - $(date)" > $LOG_FILE
echo "Missing packages will be logged here" > $MISSING_PACKAGES_LOG

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Function to check package availability
check_package() {
    local pkg=$1
    local repo=$2
    
    if [ "$repo" == "aur" ]; then
        if ! yay -Si "$pkg" &>> $LOG_FILE; then
            log "Package not found in AUR: $pkg"
            echo "$pkg (AUR)" >> $MISSING_PACKAGES_LOG
            return 1
        fi
    else
        if ! pacman -Si "$pkg" &>> $LOG_FILE; then
            log "Package not found in official repos: $pkg"
            echo "$pkg (Official)" >> $MISSING_PACKAGES_LOG
            return 1
        fi
    fi
    return 0
}

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    log "This script should not be run as root. It will ask for sudo when needed."
    exit 1
fi

# Update system first
log "Updating system..."
sudo pacman -Syu --noconfirm 2>&1 | tee -a $LOG_FILE
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "Failed to update system"
    exit 1
fi

# Install yay if not installed
if ! command -v yay &>/dev/null; then
    log "Installing yay..."
    sudo pacman -S --needed --noconfirm base-devel git 2>&1 | tee -a $LOG_FILE || {
        log "Failed to install yay dependencies"
        exit 1
    }
    git clone https://aur.archlinux.org/yay.git /tmp/yay 2>&1 | tee -a $LOG_FILE || {
        log "Failed to clone yay"
        exit 1
    }
    cd /tmp/yay || exit 1
    makepkg -si --noconfirm 2>&1 | tee -a $LOG_FILE || {
        log "Failed to build yay"
        exit 1
    }
    cd ~ || exit 1
    rm -rf /tmp/yay
fi

# Package lists (excluding unavailable packages)
OFFICIAL_PACKAGES=(
    zsh
    hyprland hyprlock hyprpaper kitty waybar
    networkmanager network-manager-applet
    bluez bluez-utils blueman
    rofi sddm gnome-keyring
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    qt5-wayland qt6-wayland wl-clipboard
    grim slurp polkit-gnome brightnessctl
    playerctl
    papirus-icon-theme
    ttf-dejavu ttf-liberation ttf-font-awesome
    ttf-jetbrains-mono noto-fonts
    noto-fonts-emoji noto-fonts-cjk
    pavucontrol gnome-system-monitor
    vlc gedit fastfetch cava btop
    power-profiles-daemon
    intel-media-driver libva-intel-driver
    gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly
)

AUR_PACKAGES=(
    google-chrome visual-studio-code-bin
    zsh-theme-powerlevel10k-git
)

# Verify package availability
log "Checking package availability..."
for pkg in "${OFFICIAL_PACKAGES[@]}"; do
    check_package "$pkg" "official"
done

for pkg in "${AUR_PACKAGES[@]}"; do
    check_package "$pkg" "aur"
done

# Install official packages
log "Installing official packages..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}" 2>&1 | tee -a $LOG_FILE
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "Some official packages failed to install - check $LOG_FILE"
fi

# Install AUR packages
log "Installing AUR packages..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}" 2>&1 | tee -a $LOG_FILE
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    log "Some AUR packages failed to install - check $LOG_FILE"
fi

# Enable services
log "Enabling services..."
sudo systemctl enable --now NetworkManager 2>&1 | tee -a $LOG_FILE
sudo systemctl enable --now bluetooth 2>&1 | tee -a $LOG_FILE
sudo systemctl enable --now sddm 2>&1 | tee -a $LOG_FILE
sudo systemctl enable --now power-profiles-daemon 2>&1 | tee -a $LOG_FILE

# Configure Oh My Zsh with p10k
if command -v zsh &>/dev/null; then
    log "Configuring Oh My Zsh..."
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1 | tee -a $LOG_FILE
        echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >> ~/.zshrc
        log "Powerlevel10k will configure itself on first zsh launch"
    fi

    if [ "$SHELL" != "$(which zsh)" ]; then
        log "Setting zsh as default shell..."
        chsh -s $(which zsh) 2>&1 | tee -a $LOG_FILE
    fi
else
    log "Warning: zsh not found - skipping shell configuration"
fi

# Final summary
log "Installation complete!"
if [ -s $MISSING_PACKAGES_LOG ]; then
    log "Some packages were not found in repositories:"
    cat $MISSING_PACKAGES_LOG | tee -a $LOG_FILE
    log "Check $MISSING_PACKAGES_LOG for missing packages to install manually"
fi

log "Recommended next steps:"
log "1. Restart your computer"
log "2. Powerlevel10k will configure itself when you first open terminal"
log "3. Set up Bluetooth with: blueman-manager"
log "4. Configure gnome-keyring manually if needed"
log "5. For video acceleration, ensure these environment variables are set:"
log "   export LIBVA_DRIVER_NAME=iHD"
log "   export VDPAU_DRIVER=va_gl"

log "Full installation log available at: $LOG_FILE"
