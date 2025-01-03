#!/bin/sh


./urban-tycoons &
game_pid=$!

get_property_value() {
    local property_name="$1"
    local output="$2"
    echo "$output" | grep "$property_name" | awk '{print $NF}'
}

i=10
while [ $i -gt 0 ]; do
    echo "$i"
    i=$(($i - 1))
    sleep 1
done

wid="$(xdotool search --pid "$game_pid")"
info="$(xwininfo -id "$wid")"
x="$(get_property_value "Absolute upper-left X" "$info")"
y="$(get_property_value "Absolute upper-left Y" "$info")"
width="$(get_property_value "Width" "$info")"
height="$(get_property_value "Height" "$info")"

ffmpeg -f x11grab -video_size "$width"x"$height" -framerate 60 -i :0.0+"$x","$y" -an -y output.mp4 &
ffmpeg_pid=$!

while true; do
    if ! ps -p $game_pid > /dev/null; then
        kill $ffmpeg_pid
        break
    fi

    sleep 1
done
