!/bin/bash
export DISPLAY=:0
xhost +local:
docker run --rm   -p 9000:8080   -e DISPLAY=$DISPLAY   -v /tmp/.X11-unix:/tmp/.X11-unix   burpsuite
