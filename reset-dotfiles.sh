#!/bin/bash

set -e  # Exit on any error

DOTFILES_DIR="$HOME/.dotfiles"

echo "Restoring original configuration files and directories..."

# Function to restore a directory
restore_dir() {
    local symlink_path="$HOME/$1"
    local backup_path="$DOTFILES_DIR/$1"

    if [ -L "$symlink_path" ]; then
        rm "$symlink_path"
        if [ -d "$backup_path" ]; then
            mv "$backup_path" "$symlink_path"
        fi
    fi
}

# Function to restore a file
restore_file() {
    local symlink_path="$HOME/$1"
    local backup_path="$DOTFILES_DIR/shell/$1"

    if [ -L "$symlink_path" ]; then
        rm "$symlink_path"
        if [ -f "$backup_path" ]; then
            mv "$backup_path" "$symlink_path"
        fi
    fi
}


# Restore GNOME Settings
echo "🔄 Restoring GNOME Settings (only writable keys)..."

LOGIN_USER=$(logname)

if [ -f "$DOTFILES_DIR/gnome-settings.dconf" ]; then
    # Extract writable keys only
    TMP_FILTERED_SETTINGS="/tmp/filtered-gnome-settings.dconf"
    grep -E '^/org/gnome/' "$DOTFILES_DIR/gnome-settings.dconf" > "$TMP_FILTERED_SETTINGS"

    if sudo -u "$LOGIN_USER" dconf load / < "$TMP_FILTERED_SETTINGS" 2>/tmp/dconf_reset_error.log; then
        echo "✅ GNOME settings restored."
    else
        echo "⚠️ Some settings failed to apply. Check /tmp/dconf_reset_error.log for details."
    fi

    rm "$TMP_FILTERED_SETTINGS"
else
    echo "❌ No GNOME settings backup found to restore."
fi


# Restore GNOME Extensions
restore_dir ".local/share/gnome-shell/extensions"

# Restore Themes and Icons
restore_dir ".themes"
restore_dir ".icons"

# Restore .config folder
restore_dir ".config"

# Restore Shell Configuration Files
for file in .bashrc .zshrc .bash_history .bash_profile; do
    restore_file "$file"
done

echo "Restoration complete! Your system is back to its original state."

