# Worklogs aliases (run set-worklogs-path.sh to configure)
if [ -n "$WORKLOGS_PATH" ] && [ -d "$WORKLOGS_PATH" ]; then
    alias createnewlog="$WORKLOGS_PATH/create-new-log.sh"
    alias gitpushlog="$WORKLOGS_PATH/git-push.sh"
fi
