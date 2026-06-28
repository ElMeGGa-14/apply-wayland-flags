#!/bin/bash
# apply-wayland-flags-tui - Terminal UI for managing Wayland flags
# Launched from the application menu or terminal.

FLAGS_SCRIPT="${HOME}/.local/bin/apply-wayland-flags"

detect_dialog() {
    if command -v dialog &>/dev/null; then
        DIALOG="dialog"
        return 0
    fi
    if command -v whiptail &>/dev/null; then
        DIALOG="whiptail"
        return 0
    fi
    return 1
}

msgbox() {
    case "$DIALOG" in
        dialog) dialog --ok-label "$2" --msgbox "$1" 0 0 ;;
        whiptail) whiptail --ok-button "$2" --msgbox "$1" 0 0 ;;
    esac
}

yesno() {
    case "$DIALOG" in
        dialog) dialog --yes-label "Yes" --no-label "No" --yesno "$1" 0 0 ;;
        whiptail) whiptail --yes-button "Yes" --no-button "No" --yesno "$1" 0 0 ;;
    esac
}

infobox() {
    case "$DIALOG" in
        dialog) dialog --infobox "$1" 0 0 ;;
        whiptail) whiptail --infobox "$1" 0 0 ;;
    esac
}

main_menu() {
    local choice
    while true; do
        choice=$("$DIALOG" --clear --title "Wayland Flags Manager" \
            --menu "Manage fractional scaling flags for Electron/Chromium apps" 0 0 4 \
            "1" "Apply flags now (full rescan)" \
            "2" "Show currently monitored apps" \
            "3" "View project on GitHub" \
            "4" "Exit" \
            3>&1 1>&2 2>&3)
        case "$choice" in
            1) run_scan ;;
            2) show_status ;;
            3) open_github ;;
            4) break ;;
        esac
    done
    clear
}

run_scan() {
    infobox "Scanning for Electron/Chromium applications..."
    output=$("$FLAGS_SCRIPT" --full 2>&1)
    msgbox "$output" "OK"
}

show_status() {
    if [[ ! -d "$HOME/.local/share/applications" ]]; then
        msgbox "No overrides found. Run 'Apply flags' first." "OK"
        return
    fi
    local files=("$HOME"/.local/share/applications/*.desktop)
    if [[ ${#files[@]} -eq 0 ]] || [[ ! -f "${files[0]}" ]]; then
        msgbox "No overrides found. Run 'Apply flags' first." "OK"
        return
    fi
    local list=""
    for f in "${files[@]}"; do
        list+="  $(basename "$f" .desktop)\n"
    done
    msgbox "Monitored applications:\n${list}" "OK"
}

open_github() {
    if command -v xdg-open &>/dev/null; then
        xdg-open "https://github.com/ElMeGGa-14/apply-wayland-flags" &>/dev/null &
        msgbox "Opening GitHub repository in your browser..." "OK"
    else
        msgbox "Open https://github.com/ElMeGGa-14/apply-wayland-flags in your browser." "OK"
    fi
}

if ! detect_dialog; then
    echo "Error: 'dialog' or 'whiptail' is required for the TUI."
    echo "Install with: sudo pacman -S dialog  (or apt install dialog, dnf install dialog)"
    exit 1
fi

if [[ ! -x "$FLAGS_SCRIPT" ]]; then
    msgbox "Main script not found at:\n$FLAGS_SCRIPT\n\nRun the main installer first." "Exit"
    exit 1
fi

if [[ $# -eq 0 ]]; then
    main_menu
else
    "$FLAGS_SCRIPT" "$@"
fi
