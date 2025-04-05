#!/bin/bash

set -e

# Define dotfiles directory
DOTFILES_DIR="$HOME/.dotfiles"

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

# Create Necessary Directories
mkdir -p "$DOTFILES_DIR/.local/share/gnome-shell/"
mkdir -p "$DOTFILES_DIR/.themes"
mkdir -p "$DOTFILES_DIR/.icons"
mkdir -p "$DOTFILES_DIR/shell"
mkdir -p "$DOTFILES_DIR/.fonts"

# Function to move and symlink folders
move_and_symlink() {
    local src="$HOME/$1"
    local dest="$DOTFILES_DIR/$1"

    if [ -d "$src" ]; then
        echo "📁 Backing up $1..."
        mv "$src" "$dest"
        ln -sf "$dest" "$src"
    fi
}

# Backup full .config and GNOME extensions
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

# Move GNOME Settings
echo "💾 Backing up GNOME Settings..."
dconf dump / > "$DOTFILES_DIR/gnome-settings.dconf"

# Themes and Icons
move_and_symlink ".themes"
move_and_symlink ".icons"
move_and_symlink ".fonts"


# Shell configuration files
for file in .bashrc .zshrc .bash_history .bash_profile; do
    if [ -f "$HOME/$file" ]; then
        echo "🔗 Backing up $file..."
        mv "$HOME/$file" "$DOTFILES_DIR/shell/"
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

# Git operations
echo "🔄 Committing changes..."
dotfiles add .
dotfiles commit -m "Updated dotfiles backup on $(date)"
dotfiles branch -M linux

echo "✅ Dotfiles setup completed!"
echo "💡 If not done yet, add your remote:"
echo "git remote add origin <your-repo-url>"
echo "git push origin linux"

