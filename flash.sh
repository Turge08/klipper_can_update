#!/bin/bash
#
# Klipper Can Update
# https://github.com/Turge08/klipper_can_update
#

CONFIG_DIR="config"
CONF_FILE="mcus.conf"
KLIPPER_DIR="$HOME/klipper"
PRINTER_CFG_DIR="$HOME/printer_data/config"
SCRIPT_DIR=$(pwd)

# ANSI colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

DEBUG=0

[ -d "$SCRIPT_DIR/$CONFIG_DIR" ] || mkdir -p "$SCRIPT_DIR/$CONFIG_DIR"
[ -f "$SCRIPT_DIR/$CONF_FILE" ] || touch "$SCRIPT_DIR/$CONF_FILE"

# ---------- Common header ----------
print_header() {
    printf "\n%b\n" "${CYAN}===============================================================${RESET}"
    printf "%b\n" "${BOLD} Klipper Can Update - https://github.com/Turge08/klipper_can_update ${RESET}"
    printf "%b\n\n" "${CYAN}===============================================================${RESET}"
}

# ---------- Table rendering ----------
draw_mcu_table() {
    if [ ! -s "$SCRIPT_DIR/$CONF_FILE" ]; then
        printf "\n%b\n\n" "${YELLOW}No MCUs saved yet.${RESET}"
        return
    fi

    printf "%-4s %-20s %-36s\n" "ID" "MCU" "UUID"
    printf "%b\n" "${CYAN}==============================================================${RESET}"

    i=1
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        mcu=$(echo "$line" | sed -n 's/.*"mcu":"\([^"]*\)".*/\1/p')
        uuid=$(echo "$line" | sed -n 's/.*"uuid":"\([^"]*\)".*/\1/p')
        [ -z "$uuid" ] && uuid="${YELLOW}Missing${RESET}"
        printf "%-4s %-20s %-36b\n" "$i" "$mcu" "$uuid"
        i=$((i+1))
    done < "$SCRIPT_DIR/$CONF_FILE"

    printf "%b\n\n" "${CYAN}==============================================================${RESET}"
}

draw_config_table() {
    configs=$(ls "$SCRIPT_DIR/$CONFIG_DIR"/*.config 2>/dev/null | xargs -n1 basename)
    [ -z "$configs" ] && { printf "\n%b\n\n" "${YELLOW}No configs found.${RESET}"; return; }

    printf "%-4s %-22s %s\n" "ID" "Config Name" "Status"
    printf "%b\n" "${CYAN}==========================================================${RESET}"

    i=1
    for c in $configs; do
        cname="${c%.config}"
        if grep -q "\"mcu\":\"$cname\"" "$SCRIPT_DIR/$CONF_FILE"; then
            status="${RED}In Use${RESET}"
        else
            status="${GREEN}Available${RESET}"
        fi
        printf "%-4s %-22s %b\n" "$i" "$cname" "$status"
        eval conf_$i=$c
        i=$((i+1))
    done

    printf "%b\n\n" "${CYAN}==========================================================${RESET}"
}

# ---------- Flash Logic ----------
flash_mcu() {
    config_path="$1"
    uuid="$2"

    [ $DEBUG -eq 1 ] && {
        echo "[DEBUG] config_path: $config_path"
        echo "[DEBUG] uuid: $uuid"
    }

    cd "$KLIPPER_DIR" || return
    make clean
    make -j4 KCONFIG_CONFIG="$config_path"

    if [ $DEBUG -eq 1 ]; then
        echo "[DEBUG] python3 ~/katapult/scripts/flash_can.py -u $uuid"
    fi

    python3 ~/katapult/scripts/flash_can.py -u "$uuid"

    cd "$SCRIPT_DIR" || return

    [ $DEBUG -eq 1 ] && { echo "[DEBUG] Flash complete. Press any key to continue..."; read -r; }
}

update_mcus() {
    clear
    print_header
    printf "%b\n\n" "${BOLD}${GREEN}[ Upgrade Firmware on MCU(s) ]${RESET}"
    draw_mcu_table

    [ ! -s "$SCRIPT_DIR/$CONF_FILE" ] && { sleep 2; return; }

    echo "Enter ID(s) to upgrade (comma-separated) or A for All, B to go back:"
    read -r choice

    case "$choice" in
        B|b) return ;;
        A|a)
            sudo service klipper stop
            i=1
            while IFS= read -r line; do
                config=$(echo "$line" | sed -n 's/.*"mcu":"\([^"]*\)".*/\1/p')
                uuid=$(echo "$line" | sed -n 's/.*"uuid":"\([^"]*\)".*/\1/p')
                flash_mcu "$SCRIPT_DIR/$CONFIG_DIR/$config.config" "$uuid"
                i=$((i+1))
            done < "$SCRIPT_DIR/$CONF_FILE"
            sudo service klipper restart
            ;;
        *)
            sudo service klipper stop
            for id in $(echo "$choice" | tr ',' ' '); do
                line=$(sed -n "${id}p" "$SCRIPT_DIR/$CONF_FILE")
                config=$(echo "$line" | sed -n 's/.*"mcu":"\([^"]*\)".*/\1/p')
                uuid=$(echo "$line" | sed -n 's/.*"uuid":"\([^"]*\)".*/\1/p')
                flash_mcu "$SCRIPT_DIR/$CONFIG_DIR/$config.config" "$uuid"
            done
            sudo service klipper restart
            ;;
    esac
    echo "Firmware upgrade(s) complete."
    sleep 2
}

# ---------- Scan & Add Missing MCUs ----------
scan_missing_mcus() {
    missing_list=()

    while IFS= read -r line; do
        file=$(echo "$line" | cut -d: -f1)
        section=$(echo "$line" | cut -d: -f2-)

        header=$(echo "$section" | tr -d '[]' | xargs)
        set -- $header
        if [ "$1" = "mcu" ] && [ -n "$2" ]; then
            mcuname="$2"
        else
            mcuname="mcu"
        fi

        uuid=$(awk '/^\[mcu/{flag=1;next}/^\[/{flag=0}flag' "$file" \
               | grep -i "^[[:space:]]*canbus_uuid" \
               | grep -v "^[[:space:]]*#" \
               | awk -F: '{print $2}' | xargs)

        if [ $DEBUG -eq 1 ]; then
            echo "[DEBUG] File: $file"
            echo "[DEBUG] MCU Name: $mcuname"
            echo "[DEBUG] UUID: $uuid"
        fi

        clean_mcu=$(echo "$mcuname" | tr -d '\r\n[:space:]')
        clean_uuid=$(echo "$uuid" | tr -d '\r\n[:space:]')

        if [ -n "$clean_mcu" ] && [ -n "$clean_uuid" ]; then
            if ! echo "$clean_uuid" | grep -Eq '^[0-9a-fA-F]{12}$'; then
                continue
            fi
            if grep -q "\"uuid\":\"$clean_uuid\"" "$SCRIPT_DIR/$CONF_FILE"; then
                continue
            fi
            missing_list+=("${clean_mcu}|$clean_uuid|$file")
        fi
    done < <(grep -r "^\[mcu" "$PRINTER_CFG_DIR" --include="*.cfg" 2>/dev/null)

    for entry in "${missing_list[@]}"; do
        mcuname=$(echo "$entry" | cut -d'|' -f1)
        uuid=$(echo "$entry" | cut -d'|' -f2)
        file=$(echo "$entry" | cut -d'|' -f3)
        basename_file=$(basename "$file")

        printf "\n%b\n" "${YELLOW}Found MCU in $basename_file${RESET}"
        printf "%-20s %-36s\n" "MCU" "UUID"
        printf "%b\n" "${CYAN}==============================================================${RESET}"
        printf "%-20s %-36s\n" "$mcuname" "$uuid"
        printf "%b\n" "${CYAN}==============================================================${RESET}"

        configs=$(ls "$SCRIPT_DIR/$CONFIG_DIR"/*.config 2>/dev/null | xargs -n1 basename)
        [ -z "$configs" ] && continue

        i=1
        for c in $configs; do
            cname="${c%.config}"
            printf " ${CYAN}[$i]${RESET} $cname\n"
            eval cfg_$i=$c
            i=$((i+1))
        done
        printf " ${CYAN}[B]${RESET} Back   ${CYAN}[X]${RESET} Exit\n"

        while true; do
            read -p "Select config: " choice
            case "$choice" in
                B|b) break ;;
                X|x) exit 0 ;;
                *)
                    eval chosen=\$cfg_$choice
                    if [ -n "$chosen" ]; then
                        echo "{\"mcu\":\"${chosen%.config}\",\"uuid\":\"$uuid\"}" >> "$SCRIPT_DIR/$CONF_FILE"
                        printf "%b\n" "${GREEN}✔ MCU $mcuname (UUID $uuid) added using config ${chosen%.config}${RESET}"
                        break
                    else
                        echo -e "${RED}Invalid choice. Try again.${RESET}"
                    fi
                    ;;
            esac
        done
    done
}

# ---------- Add MCU Menu ----------
add_mcu_menu() {
    while true; do
        clear
        print_header
        printf "%b\n\n" "${BOLD}${GREEN}[ Add MCU ]${RESET}"
        draw_mcu_table

        scan_missing_mcus

        clear
        print_header
        printf "%b\n\n" "${BOLD}${GREEN}[ Add MCU ]${RESET}"
        draw_mcu_table
        printf "%b\n" "${YELLOW}You can now manually add a new MCU from the available configs:${RESET}"

        mcus=$(ls "$SCRIPT_DIR/$CONFIG_DIR"/*.config 2>/dev/null | xargs -n1 basename)
        [ -z "$mcus" ] && { printf "%b\n" "${YELLOW}No configs found.${RESET}"; sleep 2; return; }

        i=1; for m in $mcus; do printf "%b\n" " ${CYAN}[$i]${RESET} ${m%.config}"; eval mcu_$i=$m; i=$((i+1)); done
        printf "%b\n" " ${CYAN}[B]${RESET} Back   ${CYAN}[X]${RESET} Exit"
        printf "Select: "; read choice
        case "$choice" in B|b) return ;; X|x) exit 0 ;; esac
        eval mcu=\$mcu_$choice; [ -z "$mcu" ] && continue

        while true; do
            printf "Enter UUID (12 hex chars): "
            read uuid
            if ! printf "%s" "$uuid" | grep -Eq '^[0-9a-fA-F]{12}$'; then
                printf "%b\n" "${RED}Invalid UUID. Must be 12 hex characters (0-9, a-f).${RESET}"
                continue
            fi
            if grep -q "\"uuid\":\"$uuid\"" "$SCRIPT_DIR/$CONF_FILE"; then
                printf "%b\n" "${RED}UUID already in use!${RESET}"
                continue
            fi
            break
        done

        echo "{\"mcu\":\"${mcu%.config}\",\"uuid\":\"$uuid\"}" >> "$SCRIPT_DIR/$CONF_FILE"
        printf "%b\n" "${GREEN}✔ MCU ${mcu%.config} (UUID $uuid) added${RESET}"
        return
    done
}

# ---------- Remove MCU Menu ----------
remove_mcu_menu() {
    while true; do
        clear
        print_header
        printf "%b\n\n" "${BOLD}${RED}[ Remove MCU ]${RESET}"
        draw_mcu_table

        [ ! -s "$SCRIPT_DIR/$CONF_FILE" ] && { sleep 2; return; }

        printf "Enter ID to remove (or B to go back): "
        read id
        case "$id" in B|b) return ;; esac

        if [[ "$id" =~ ^[0-9]+$ ]]; then
            sed -i "${id}d" "$SCRIPT_DIR/$CONF_FILE"
            printf "%b\n" "${GREEN}✔ MCU removed.${RESET}"
            sleep 1
        fi
    done
}

# ---------- Maintenance Menu ----------
maintenance_menu() {
    while true; do
        clear
        print_header
        printf "%b\n\n" "${BOLD}${GREEN}[ Maintenance ]${RESET}"
        draw_config_table

        printf " ${CYAN}[A]${RESET} Add Config   ${CYAN}[M]${RESET} Modify Config   ${CYAN}[R]${RESET} Remove Config   ${CYAN}[B]${RESET} Back\n"
        read -p "Select: " opt

        case "$opt" in
            A|a)
                read -p "Enter new config name: " newconf
                if [ -f "$SCRIPT_DIR/$CONFIG_DIR/$newconf.config" ]; then
                    echo "Config already exists."
                else
                    cd "$KLIPPER_DIR" || return
                    make clean
                    make menuconfig KCONFIG_CONFIG="$SCRIPT_DIR/$CONFIG_DIR/$newconf.config"
                    cd "$SCRIPT_DIR" || return
                fi
                ;;
            M|m)
                draw_config_table
                read -p "Enter ID to modify: " id
                eval cfg=\$conf_$id
                [ -z "$cfg" ] && continue
                cd "$KLIPPER_DIR" || return
                make clean
                make menuconfig KCONFIG_CONFIG="$SCRIPT_DIR/$CONFIG_DIR/$cfg"
                cd "$SCRIPT_DIR" || return
                ;;
            R|r)
                draw_config_table
                read -p "Enter ID to remove: " id
                eval cfg=\$conf_$id
                [ -z "$cfg" ] && continue
                if grep -q "\"mcu\":\"${cfg%.config}\"" "$SCRIPT_DIR/$CONF_FILE"; then
                    echo "Cannot remove: Config in use."
                else
                    rm -f "$SCRIPT_DIR/$CONFIG_DIR/$cfg"
                    echo "Config removed."
                fi
                ;;
            B|b) return ;;
        esac
    done
}

# ---------- Main Menu ----------
main_menu() {
    while true; do
        clear
        print_header
        draw_mcu_table

        printf "%b\n" "${CYAN}---------------------------------------------------------------${RESET}"
        printf "%b\n" " ${CYAN}[1]${RESET} Upgrade Firmware on MCU(s)"
        printf "%b\n" " ${CYAN}[2]${RESET} Add MCU"
        printf "%b\n" " ${CYAN}[3]${RESET} Remove MCU"
        printf "%b\n" " ${CYAN}[4]${RESET} Maintenance"
        printf "%b\n" " ${CYAN}[5]${RESET} Debug Mode (Currently: $( [ $DEBUG -eq 1 ] && echo "${GREEN}ON${RESET}" || echo "${RED}OFF${RESET}" ))"
        printf "%b\n" " ${CYAN}[X]${RESET} Exit"
        printf "%b\n" "${CYAN}---------------------------------------------------------------${RESET}"
        printf "Select option: "
        read opt

        case $opt in
            1) update_mcus ;;
            2) add_mcu_menu ;;
            3) remove_mcu_menu ;;
            4) maintenance_menu ;;
            5) DEBUG=$((1-DEBUG)) ;;
            X|x) exit 0 ;;
        esac
    done
}

main_menu
