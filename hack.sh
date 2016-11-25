#!/bin/bash

# Find current screen resolution
WIDTH=$(xwininfo  -root | grep "Width:" | sed "s/[[:space:]]*Width:[[:space:]]*\([0-9]*\)/\1/g")
HEIGHT=$(xwininfo  -root | grep "Height:" | sed "s/[[:space:]]*Height:[[:space:]]*\([0-9]*\)/\1/g")
# Find maximal scale factor
SCALE_FACTOR=$(echo "console.log(Math.min(($WIDTH / 800), ($HEIGHT / 600)))" | node)
echo "Scaling game by: $SCALE_FACTOR"

# Creating log-file
LOG_FILE=$(mktemp)
echo "Outputting logs to: $LOG_FILE"

function kill_pid {
    # Notify that we're killing
    echo -e "$1...\c"
    # Send SIGTERM
    kill $2 1>>$LOG_FILE 2>>$LOG_FILE 
    # Send SIGKILL in 10 seconds (capture PID, and disown)
    (sleep 10; echo "FAILED"; echo -e "$1 (forced)...\c"; kill -9 $2) &
    BRUTAL_PID=$(echo $!)
    disown $BRUTAL_PID
    # Wait for SIGTERM (or SIGKILL) to work
    wait $2 1>>$LOG_FILE 2>>$LOG_FILE
    # Kill the SIGKILL script, if SIGTERM fired within time
    kill $BRUTAL_PID 1>>$LOG_FILE 2>>$LOG_FILE
    echo "OK"
}

# Install Ctrl+C handler
function kill_all {
    # Kill stuff
    kill_pid "vncviewer" $VNCVIEWER_PID
    kill_pid "v11vnc" $X11VNC_PID
    kill_pid "heroes3" $HEROES_PID
    kill_pid "Xvfb" $XVFB_PID
}
trap kill_all 2

# Run the virual frame buffer
echo ""
echo -e "Starting Xvfb...\c"
Xvfb :1 -screen 0 800x600x16 1>>$LOG_FILE 2>>$LOG_FILE &
XVFB_PID=$(echo $!)
echo "OK"

# Run the game
echo ""
echo -e "Starting heroes3...\c"
# Start with padsp to get sound
DISPLAY=:1 padsp -S -M ./heroes3 -f 1>>$LOG_FILE 2>>$LOG_FILE &
HEROES_PID=$(echo $!)
echo "OK"

# Run the x11vnc server
# We need a temp file for output
echo ""
echo -e "Starting x11vnc...\c"
X11VNC_LOG=$(mktemp)
x11vnc -localhost -nocursor -scale $SCALE_FACTOR:nb -display :1 1>>$LOG_FILE 2>>$LOG_FILE &
X11VNC_PID=$(echo $!)
echo "OK"
# Wait for X11VNC to be reading
echo -e "Waiting for x11vnc...\c"
tail -f $LOG_FILE | while read LOGLINE
do
   [[ "${LOGLINE}" == *"PORT"* ]] && pkill -P $$ tail
done
#sleep 3
echo "OK"

# Run the VNCViewer
echo ""
echo -e "Starting vncviewer...\c"
DISPLAY=:0 vncviewer -fullscreen 127.0.0.1 1>>$LOG_FILE 2>>$LOG_FILE &
VNCVIEWER_PID=$(echo $!)
echo "OK"

# Wait for heroes
echo ""
echo -e "Waiting for heroes3 termination...\c"
wait $HEROES_PID
echo "OK"

# Clean up
echo ""
echo "Killing processes..."
kill_all

echo ""
echo "All OK"
