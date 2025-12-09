#!/bin/bash

SESSION=nmrs
ROOT=~/personal/nmrs

# If the session already exists, just attach.
tmux has-session -t "$SESSION" 2>/dev/null && {
    tmux attach -t "$SESSION"
    exit
}

# Otherwise create it once.
tmux new-session -d -s "$SESSION" -n main -c "$ROOT"
tmux split-window -h  -t "$SESSION:main" -c "$ROOT"
tmux send-keys   -t "$SESSION:main.0" "nvim" C-m

tmux new-window  -t "$SESSION" -n shell -c "$ROOT"

tmux attach -t "$SESSION"
