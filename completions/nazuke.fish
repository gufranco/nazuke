complete -c nazuke -f
complete -c nazuke -n __fish_use_subcommand -a name -d 'print a short name for each text'
complete -c nazuke -n __fish_use_subcommand -a rename -d 'give every file of a folder a short unique name'
complete -c nazuke -n __fish_use_subcommand -a doctor -d 'check the tools nazuke needs'
complete -c nazuke -n __fish_use_subcommand -a version -d 'print the version'
complete -c nazuke -n __fish_use_subcommand -a help -d 'print usage'
complete -c nazuke -n '__fish_seen_subcommand_from rename' -a '(__fish_complete_directories)'

complete -c nazuke -n '__fish_seen_subcommand_from name rename' -l max -r -d 'longest name, 4 to 255'
complete -c nazuke -n '__fish_seen_subcommand_from rename' -l ext -r -d 'longest extension, 1 to 255'
complete -c nazuke -n '__fish_seen_subcommand_from name rename' -l words -r -a 'generic games' -d 'word pack'
complete -c nazuke -n '__fish_seen_subcommand_from rename' -l dry-run -d 'list every rename and change nothing'
complete -c nazuke -n '__fish_seen_subcommand_from name rename' -l json -d 'print the result as one JSON object'
complete -c nazuke -l theme -r -a 'kodougu catppuccin-mocha catppuccin-latte dracula nord gruvbox tokyo-night mono' -d 'colours of the terminal interface'
