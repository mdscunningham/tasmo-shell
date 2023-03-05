#!/bin/bash
#                                                          +----+----+----+----+
#                                                          |    |    |    |    |
# Author: Mark David Scott Cunningham                      | M  | D  | S  | C  |
#                                                          +----+----+----+----+
# Created: 2022-10-03
# Updated: 2023-01-27
#
# Purpose: A simple interface for sending console commands to Tasmota devices
#

# Dependency check
for util in jq curl; do
  if [[ ! -e $(which $util) ]]; then
    echo "
  This script requires the $util utility, but $util is either missing or not executable.
  Please install $util with your package manager, and re-run the script.
  "
    exit 2
  fi
done

# Initial Setup
shopt -s extglob
cmd="$2"
filter="$3"
curlopts="-s -k --connect-timeout 0.5"
out=/var/tmp/tasmo-shell.tmp
history=~/.tasmo_history
datefmt="%F %T"
proto="http"
help_dir='.tasmo_help'

# Source rc file if it exists
if [[ -f ~/.tasmorc ]]; then source ~/.tasmorc; fi

# Check http or https
if [[ $ts_proto ]]; then proto="$ts_proto"; fi

# Check hisotry file location
if [[ $ts_histfile ]]; then history="$ts_histfile"; fi

# Check date format
if [[ $ts_datefmt ]]; then datefmt="$ts_datefmt"; fi

# Chekc for alternate help directory
if [[ $ts_help_dir ]]; then help_dir="$ts_help_dir"; fi

# Log start of session
echo "$(date +"$datefmt") - SHELL_CMD - ${1:-shell} - '${cmd:-shell}' - '${filter:-none}'" >> $history

# Query function
query(){
  _ip="$1"
  _cmd="$2"
  echo -n "$(date +"$datefmt") - TASMO_CMD - $_ip - '$_cmd'" >> $history
  echo -ne "${_ip}: "; > $out
  if [[ $_cmd == 'metrics' ]]; then
    curl ${curlopts} ${proto}://${_ip}/metrics > $out
    if [[ $(grep -i 'file not found' $out) ]]; then
      echo "Metrics endpoint not enabled or not accessible"; echo --; > $out
    else
      echo; cat $out; echo --; > $out
    fi
  elif [[ $ts_user && $ts_pass ]]; then
    curl ${curlopts} --data-urlencode "user=${ts_user}&password=${ts_pass}&cmnd=${_cmd}" ${proto}://${_ip}/cm -o $out || echo "Failed to connect"
  else
    curl ${curlopts} --data-urlencode "cmnd=${_cmd}" ${proto}://${_ip}/cm -o $out || echo "Failed to connect"
  fi
  echo " - $(cat $out)" >> $history
  if [[ -s $out ]]; then
    if [[ -f $filter ]]; then
      # echo " - $(cat $out | jq -rc "$(cat $filter)")" >> $history
      cat $out | jq -rc "$(cat $filter)"
    else
      # echo " - $(cat $out | jq -rc "$filter")" >> $history
      cat $out | jq -rc "$filter"
    fi
  fi
}

# Command loop
cmdloop(){
  for ip in $list; do
    if [[ -f $cmd ]]; then
      while read line; do
        query $ip "$line"
      done < $cmd
      echo --
    else
      query $ip "$cmd"
    fi
  done
}

# Command help
cmd_help(){
  if [[ $1 == "list" ]]; then
    count=$(ls -1 $help_dir | wc -l)
    read -p "Display $count commands? [y/n] " yn
    if [[ $yn =~ [yY].* ]]; then ls -1 $help_dir | column -x; fi
  elif [[ $1 == search && $2 ]]; then
    shift; echo; grep -irls "$@" $help_dir | while read name; do basename $name; done; echo
  elif [[ $1 == search && ! $2 ]]; then
    echo "Please enter a serch query."
  elif [[ -f $help_dir/$(ls -1 $help_dir | grep -i ^${1}$) ]]; then
    cat $help_dir/$(ls -1 $help_dir | grep -i ^${1}$); echo
  fi
}

# Command shell
shell(){
  shell-help
  list=${1}; ip=${1}
  read -p "${ip}: " cmd
  while [[ $cmd != 'quit' && $cmd != 'exit' && $cmd != 'q' && $cmd != 'x' ]]; do
    if [[ $cmd =~ help.[a-zA-Z].* ]]; then
      cmd_help ${cmd/help/}
    elif [[ $cmd == help ]]; then
      shell-help
    else
      cmdloop
    fi
    read -p "${ip}: " cmd
  done
}

# Help inside the shell
shell-help(){
  echo "Use 'exit' or 'quit' to end session. Use 'help list' or 'help command-name' for help."; echo
}

# Help output
usage(){
_name=$(basename $0)
cat <<EOF

 Usage: $_name <list> "[command]" "[filter]"

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
     $_name <list-file> <command>

   Run command on a small list of devices
     $_name <ip/host,ip/host,ip/host> <command>

   Run command with filtered output
     $_name <list> "status 2" '.StatusFWR | "\(.Version), \(.Hardware)"'

   Run multiple commands, read from a file
     $_name <list> <cmd-file>

   Connect to single device with shell-like command prompt
     $_name <ip/host>

   Command help output
     $_name help DevGroupSend

   List available commands
     $_name help list

   Search command help
     $_name help search fade

EOF
exit 1
}

# Main select logic
if [[ ! $1 ]]; then
  read -p "Enter IP/Host to connect to: " ip
  shell $ip
elif [[ $1 =~ -h|--help|help ]]; then
  if [[ ! $2 ]]; then
    usage
  else
    shift; cmd_help $@
  fi
elif [[ -f $1 ]]; then
  list="$(cat $1)"
  cmdloop
elif [[ $1 =~ .*,.* ]]; then
  list="${1//,/ }"
  list="$(for x in $list; do if [[ -f $x ]]; then cat $x; else echo $x; fi; done)"
  cmdloop
elif [[ $cmd ]]; then
  list="$1"
  cmdloop
elif [[ ! $cmd ]]; then
  shell $1
fi

# Cleanup
if [[ -f $out ]]; then rm $out; fi
