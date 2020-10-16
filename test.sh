#! /usr/bin/zsh

# Start nested xserver
Xephyr :3 &

# start gala on the new display
gala -d :3 &

sleep 2

# start a few applications to switch between
DISPLAY=:3 xterm &
DISPLAY=:3 io.elementary.calculator
