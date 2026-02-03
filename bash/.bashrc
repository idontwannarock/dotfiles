# Windows Terminal OSC 9;9 - 報告當前工作目錄，讓 duplicate pane 繼承目錄
if [ -n "$WT_SESSION" ]; then
    PROMPT_COMMAND=${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}'printf "\e]9;9;%s\e\\" "$(wslpath -w "$PWD")"'
fi
