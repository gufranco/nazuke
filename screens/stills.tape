Source common.tape
Output scratch.gif
Set Height 1100
Hide
Type ". ./setup.sh"
Enter
Sleep 1s
Show
Sleep 800ms
Type `nazuke name "Quarterly Report 2024 (final draft)" "Straße der Sterne" "Mozart - Requiem in D minor, K. 626"`
Enter
Sleep 4s
Screenshot name.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "nazuke rename --dry-run Music"
Enter
Sleep 4s
Screenshot dry-run.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "nazuke rename Pictures"
Enter
Sleep 2s
Screenshot error.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "nazuke doctor"
Enter
Sleep 10s
Screenshot doctor.png
Sleep 1s
Hide
Type "clear"
Enter
Show
Sleep 800ms
Type "for t in kodougu catppuccin-mocha dracula nord gruvbox tokyo-night; do nazuke --theme $t version; done"
Enter
Sleep 8s
Screenshot themes.png
Sleep 1s
Sleep 1s
