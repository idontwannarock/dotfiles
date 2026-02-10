if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch -c "$HOME/.config/fastfetch/config.jsonc"
}
