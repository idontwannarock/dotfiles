# 27-twg.ps1 -- restrict the twg CLI to commands that do not consume Rovo credits.
#
# basic-v1 removes every credit-consuming command and flag from twg itself, for
# every caller (any agent, or a human). $env: assignments are process-scoped, so
# lift it for the rest of this session only, and open a new shell to restore it:
#   Remove-Item Env:TWG_COMMAND_SURFACE_RESTRICTION
#
# Mirror of .chezmoitemplates/shell-common/base.
$env:TWG_COMMAND_SURFACE_RESTRICTION = 'basic-v1'
