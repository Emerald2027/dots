#!/usr/bin/env bash
current=$(hyprctl getoption general:layout | awk '/str:/{print $2}')
if [ "$current" = "dwindle" ]; then
    hyprctl keyword general:layout master
    notify-send -a "Hyprland" "layout: master"
else
    hyprctl keyword general:layout dwindle
    notify-send -a "Hyprland" "layout: dwindle"

fi
