```

 Usage: tasmo-shell.sh <list> "[command]" "[filter]"

   list ..... Single IP, comma separated list, or file
              * If a single IP is given without a command, the script will enter a shell-like
                loop that continues to prompt for commands until 'exit' or 'quit' is given.

   command .. Any valid Tasmota console command. Quote multi-part commands.
              * If the command given is a file, the script will loop through each line of the
                file as a sequence of separate commands.

   filter ... Json filter to pass to jq. Quote multi-part filters.

   help ..... Show this output and exit.
              * If a command name is given after 'help' then show help for that given command
              * To list all available commands use 'help list'
              * To search the help files use "help search <query>"

 Examples:
   Run command on a large list of devices
     tasmo-shell.sh <list-file> <command>

   Run command on a small list of devices
     tasmo-shell.sh <ip/host,ip/host,ip/host> <command>

   Run command with filtered output
     tasmo-shell.sh <list> "status 2" '.StatusFWR | "\(.Version), \(.Hardware)"'

   Run multiple commands, read from a file
     tasmo-shell.sh <list> <cmd-file>

   Connect to single device with shell-like command prompt
     tasmo-shell.sh <ip/host>

   Command help output
     tasmo-shell.sh help DevGroupSend

   List available commands
     tasmo-shell.sh help list

   Search command help
     tasmo-shell.sh help search fade

```
