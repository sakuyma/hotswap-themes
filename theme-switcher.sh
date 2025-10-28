#!/bin/bash

THEMES_DIR="$HOME/.themes"
CONFIG_DIR="$HOME/.config"

if [ ! -d "$THEMES_DIR" ]; then
    exit 1
fi

themes=($(find "$THEMES_DIR" -maxdepth 1 -type d -printf "%f\n" | tail -n +2))

selected_theme=$(printf "%s\n" "${themes[@]}" | rofi -dmenu -p "🎨 Select theme:" -config ~/.config/rofi/theme-switcher.rasi)

if [ -z "$selected_theme" ]; then
    exit 0
fi

# Function to read theme config
read_theme_config() {
    local theme_path="$1"
    local config_file="$theme_path/theme.conf"
    
    # Default values
    local gtk_theme="$selected_theme"
    local icon_theme="$selected_theme"
    local cursor_theme="$selected_theme"
    local font_name="Noto Sans 10"
    local wallpaper=""
    
    if [ -f "$config_file" ]; then
        while IFS='=' read -r key value; do
            # Remove quotes and spaces
            key=$(echo "$key" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"\(.*\)"$/\1/; s/^'"'"'\(.*\)'"'"'$/\1/')
            
            case "$key" in
                gtk_theme)
                    gtk_theme="$value"
                    ;;
                icon_theme)
                    icon_theme="$value"
                    ;;
                cursor_theme)
                    cursor_theme="$value"
                    ;;
                font_name)
                    font_name="$value"
                    ;;
                wallpaper)
                    wallpaper="$value"
                    ;;
            esac
        done < "$config_file"
    fi
    
    echo "$gtk_theme|$icon_theme|$cursor_theme|$font_name|$wallpaper"
}

apply_theme() {
    local theme="$1"
    local theme_path="$THEMES_DIR/$theme"
    
    # Read theme configuration
    IFS='|' read -r gtk_theme icon_theme cursor_theme font_name wallpaper <<< "$(read_theme_config "$theme_path")"
    
    echo "Applying: GTK=$gtk_theme, Icons=$icon_theme, Cursors=$cursor_theme, Font=$font_name"
    
    # Copy each theme subdirectory to corresponding config folder
    if [ -d "$theme_path" ]; then
        for app_dir in "$theme_path"/*; do
            if [ -d "$app_dir" ] && [ "$(basename "$app_dir")" != "theme.conf" ]; then
                local app_name=$(basename "$app_dir")
                local target_dir="$CONFIG_DIR/$app_name"
                
                mkdir -p "$target_dir"
                cp -r "$app_dir"/* "$target_dir/" 2>/dev/null
            fi
        done
    fi
    
    # Update GTK settings
    if command -v nwg-look >/dev/null 2>&1; then
        nwg-look -a
    fi
    
    # Apply themes via gsettings
    if command -v gsettings >/dev/null 2>&1; then
        # GTK theme
        gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null
        
        # Icon theme
        gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null
        
        # Cursor theme
        gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" 2>/dev/null
        
        # Font
        gsettings set org.gnome.desktop.interface font-name "$font_name" 2>/dev/null
    fi
    
    # Alternative method for non-GNOME environments
    if command -v xfconf-query >/dev/null 2>&1; then
        xfconf-query -c xsettings -p /Net/ThemeName -s "$gtk_theme" 2>/dev/null
        xfconf-query -c xsettings -p /Net/IconThemeName -s "$icon_theme" 2>/dev/null
        xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "$cursor_theme" 2>/dev/null
    fi
    
    # Update icon cache
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        # Update cache for home directory
        if [ -d "$HOME/.icons/$icon_theme" ]; then
            gtk-update-icon-cache -f "$HOME/.icons/$icon_theme" 2>/dev/null
        fi
        # Update cache for system icons
        if [ -d "/usr/share/icons/$icon_theme" ]; then
            sudo gtk-update-icon-cache -f "/usr/share/icons/$icon_theme" 2>/dev/null || true
        fi
    fi
    
    # Wallpaper handling
    if [ -n "$wallpaper" ] && [ -f "$theme_path/$wallpaper" ]; then
        swww img "$theme_path/$wallpaper" --transition-type any --transition-fps 60 >/dev/null 2>&1
    elif [ -f "$theme_path/wallpaper.jpg" ]; then
        swww img "$theme_path/wallpaper.jpg" --transition-type any --transition-fps 60 >/dev/null 2>&1
    elif [ -f "$theme_path/wallpaper.png" ]; then
        swww img "$theme_path/wallpaper.png" --transition-type any --transition-fps 60 >/dev/null 2>&1
    fi
    
    # Restart waybar
    if pgrep waybar > /dev/null; then
        pkill waybar >/dev/null 2>&1
        sleep 0.1
    fi
    waybar >/dev/null 2>&1 &
    
    # Restart dunst
    if pgrep dunst > /dev/null; then
        pkill dunst >/dev/null 2>&1
        sleep 0.1
    fi
    dunst >/dev/null 2>&1 &
    
    # Theme change notification
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Theme Changed" "Theme '$selected_theme' applied\n• GTK: $gtk_theme\n• Icons: $icon_theme\n• Cursors: $cursor_theme\n• Font: $font_name"
    fi
    
    echo "✅ Theme applied: $selected_theme"
    echo "   GTK: $gtk_theme"
    echo "   Icons: $icon_theme"
    echo "   Cursors: $cursor_theme"
    echo "   Font: $font_name"
}

apply_theme "$selected_theme"
