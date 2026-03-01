#!/bin/bash

chosen=$(ls ~/scripts | rofi -dmenu -p "Scripts")
[ -z "$chosen" ] && exit
bash ~/scripts/"$chosen"
