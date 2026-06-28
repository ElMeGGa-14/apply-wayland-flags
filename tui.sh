#!/bin/bash
# apply-wayland-flags-tui - Terminal UI for managing Wayland flags
# Launched from the application menu or terminal.

FLAGS_SCRIPT="${HOME}/.local/bin/apply-wayland-flags"

USE_FALLBACK=false

detect_dialog() {
    if command -v dialog &>/dev/null; then
        DIALOG="dialog"
        return 0
    fi
    if command -v whiptail &>/dev/null; then
        DIALOG="whiptail"
        return 0
    fi
    USE_FALLBACK=true
    return 1
}

msgbox() {
    if $USE_FALLBACK; then
        echo ""
        echo "$1"
        echo ""
        read -r -p "Presiona Enter para continuar..."
        echo
        return
    fi
    case "$DIALOG" in
        dialog) dialog --ok-label "$2" --msgbox "$1" 0 0 ;;
        whiptail) whiptail --ok-button "$2" --msgbox "$1" 0 0 ;;
    esac
}

yesno() {
    if $USE_FALLBACK; then
        local answer
        echo ""
        echo "$1"
        echo ""
        read -r -p "Yes/No [y/N]: " answer
        [[ "$answer" =~ ^[YySs] ]]
        return
    fi
    case "$DIALOG" in
        dialog) dialog --yes-label "Yes" --no-label "No" --yesno "$1" 0 0 ;;
        whiptail) whiptail --yes-button "Yes" --no-button "No" --yesno "$1" 0 0 ;;
    esac
}

infobox() {
    if $USE_FALLBACK; then
        echo "$1"
        return
    fi
    case "$DIALOG" in
        dialog) dialog --infobox "$1" 0 0 ;;
        whiptail) whiptail --infobox "$1" 0 0 ;;
    esac
}

main_menu() {
    local choice
    while true; do
        if $USE_FALLBACK; then
            echo ""
            echo "======================================"
            echo "  Wayland Flags Manager"
            echo "======================================"
            echo "  Manage fractional scaling flags for"
            echo "  Electron/Chromium apps"
            echo "======================================"
            echo ""
            echo "  1) Apply flags now (full rescan)"
            echo "  2) Show currently monitored apps"
            echo "  3) Check for updates"
            echo "  4) View project on GitHub"
            echo "  5) Exit"
            echo ""
            if ! read -r -p "Select option [1-5]: " choice; then
                break
            fi
        else
            choice=$("$DIALOG" --clear --title "Wayland Flags Manager" \
                --menu "Manage fractional scaling flags for Electron/Chromium apps" 0 0 5 \
                "1" "Apply flags now (full rescan)" \
                "2" "Show currently monitored apps" \
                "3" "Check for updates" \
                "4" "View project on GitHub" \
                "5" "Exit" \
                3>&1 1>&2 2>&3)
        fi
        case "$choice" in
            1) run_scan ;;
            2) show_status ;;
            3) check_updates ;;
            4) open_github ;;
            5) break ;;
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

check_updates() {
    local output
    output=$("$FLAGS_SCRIPT" --no-check-update --check-update 2>&1)
    if [[ -z "$output" ]]; then
        msgbox "You have the latest version." "OK"
        return
    fi
    if yesno "$output\n\nDo you want to update now?"; then
        local result
        result=$("$FLAGS_SCRIPT" --no-check-update --update 2>&1)
        msgbox "$result" "OK"
    fi
}

detect_dialog

if [[ ! -x "$FLAGS_SCRIPT" ]]; then
    msgbox "Main script not found at:\n$FLAGS_SCRIPT\n\nRun the main installer first." "Exit"
    exit 1
fi

auto_check_updates() {
    local result
    result=$("$FLAGS_SCRIPT" --no-check-update --check-update 2>&1)
    if [[ -n "$result" ]]; then
        msgbox "$result" "OK"
    fi
}
auto_check_updates

if [[ $# -eq 0 ]]; then
    main_menu
else
    "$FLAGS_SCRIPT" "$@"
fi
