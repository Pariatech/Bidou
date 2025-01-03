#!/bin/sh

./scripts/run-and-capture.sh

while true; do
    if ! ps -p $ffmpeg_pid > /dev/null; then
        len="$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 output.mp4)"
        trim_s=2
        len="$(echo "$len $trim_s" | awk '{print $1-$2}')"
        ffmpeg -i output.mp4 -ss 0 -t "$len" -c:v libvpx-vp9 -vf format=yuv420p -an -b:v 1M -fs 3M -pass 1 -f null /dev/null && \
        ffmpeg -i output.mp4 -ss 0 -t "$len" -c:v libvpx-vp9 -vf format=yuv420p -an -b:v 1M -fs 3M -pass 2 -y output.webm
        break
    fi

    sleep 1
done
