#!/bin/bash

set -e

# Define dotfiles directory
DOTFILES_DIR="$HOME/.dotfiles"

# Exit if .dotfiles folder does not exist
if [ ! -d "$DOTFILES_DIR" ]; then
    echo "❌ Error: '$DOTFILES_DIR' directory does not exist."
    echo "➡️ Please create the .dotfiles directory before running this script."
    exit 1
fi

echo "🔧 Initializing Dotfiles Repository..."

# Initialize Git Repo Only if It Doesn't Exist
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    git init "$DOTFILES_DIR"
fi

# Set up Git wrapper function
dotfiles() {
    /usr/bin/git --git-dir="$DOTFILES_DIR/.git" --work-tree="$HOME" "$@"
}

dotfiles config --local status.showUntrackedFiles no

# Create necessary directories
mkdir -p "$DOTFILES_DIR/.local/share/gnome-shell/extensions"
mkdir -p "$DOTFILES_DIR/.fonts"
mkdir -p "$DOTFILES_DIR/.themes"
mkdir -p "$DOTFILES_DIR/.icons"
mkdir -p "$DOTFILES_DIR/shell"

# Function to move and symlink folders, only if not already managed
move_and_symlink() {
    local relative_path="$1"
    local src="$HOME/$relative_path"
    local dest="$DOTFILES_DIR/$relative_path"

    # Skip if already symlinked into DOTFILES_DIR
    if [[ "$src" -ef "$dest" ]]; then
        echo "🟡 $relative_path already managed by dotfiles, skipping."
        return
    fi

    if [ -e "$src" ]; then
        echo "📁 Backing up $relative_path..."

        if [ -e "$dest" ]; then
            echo "🟡 Backup of $relative_path already exists in dotfiles. Skipping move."
        else
            mv "$src" "$dest"
        fi

        if [ -L "$src" ]; then
            echo "🔗 Symlink for $relative_path already exists. Skipping."
        elif [ -e "$src" ]; then
            mv "$src" "${src}.backup_$(date +%s)"
            echo "📝 Renamed existing $relative_path to preserve it."
        fi

        ln -sf "$dest" "$src"
    fi
}

# Backup full .config and GNOME extensions directories only if not symlinked
move_and_symlink ".config"
move_and_symlink ".local/share/gnome-shell/extensions"


# Check if dconf-cli is installed
if ! command -v dconf &> /dev/null; then
    echo "❌ dconf-cli not found! Installing..."
    if command -v dnf &> /dev/null; then
        sudo dnf install dconf-cli
    elif command -v apt &> /dev/null; then
        sudo apt-get install dconf-cli
    elif command -v pacman &> /dev/null; then
        sudo pacman -S dconf-cli
    else
        echo "❌ Package manager not supported. Please install dconf-cli manually."
        exit 1
    fi
fi


# Backup GNOME Settings including extension preferences
echo "💾 Backing up GNOME Settings (including extension preferences)..."
dconf dump /org/gnome/ > "$DOTFILES_DIR/gnome-settings.dconf"

# Backup themes, fonts and icons
move_and_symlink ".themes"
move_and_symlink ".icons"
move_and_symlink ".fonts"

# Backup shell configuration files
for file in .bashrc .zshrc .bash_history .bash_profile; do
    if [ -f "$HOME/$file" ]; then
        echo "🔗 Backing up $file..."

        if [ ! -e "$DOTFILES_DIR/shell/$file" ]; then
            mv "$HOME/$file" "$DOTFILES_DIR/shell/$file"
        fi

        if [ -e "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            mv "$HOME/$file" "$HOME/${file}.backup_$(date +%s)"
        fi

        ln -sf "$DOTFILES_DIR/shell/$file" "$HOME/$file"
    fi
done

# Backup installed packages
echo "📦 Saving installed package list..."
if command -v dnf &> /dev/null; then
    dnf list installed | awk '{print $1}' > "$DOTFILES_DIR/dnf-packages.txt"
elif command -v apt &> /dev/null; then
    dpkg --get-selections > "$DOTFILES_DIR/apt-packages.txt"
elif command -v pacman &> /dev/null; then
    pacman -Qqe > "$DOTFILES_DIR/pacman-packages.txt"
fi

# Commit and Push
echo "[INFO] Committing changes..."
dotfiles add .
dotfiles commit -m "Automated GNOME and dotfiles backup on $(date)" || echo "[INFO] Nothing to commit."

echo "[INFO] Dotfiles backup completed successfully!"
echo "To push manually, run:"
echo "git push origin linux"
