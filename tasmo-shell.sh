#!/bin/bash
#                                                          +----+----+----+----+
#                                                          |    |    |    |    |
# Author: Mark David Scott Cunningham                      | M  | D  | S  | C  |
#                                                          +----+----+----+----+
# Created: 2022-10-03
# Updated: 2023-01-19
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
out=/var/tmp/tasmo-shell.tmp

# Source rc file if it exists
if [[ -f ~/.tasmorc ]]; then source ~/.tasmorc; fi

# Check hisotry file location
if [[ -f $ts_histfile ]]; then history="$ts_histfile"; else history=~/.tasmo_history; fi

# Check date format
if [[ $ts_datefmt ]]; then datefmt="$ts_datefmt"; else datefmt="%F %T"; fi

# Log start of session
echo "$(date +"$datefmt") - SHELL_CMD - ${1:-shell} - '${cmd:-shell}' - '${filter:-none}'" >> $history

# Query function
query(){
  _ip="$1"
  _cmd="$2"
  echo -n "$(date +"$datefmt") - TASMO_CMD - $_ip - '$_cmd'" >> $history
  echo -ne "${_ip}: "; > $out
  if [[ $ts_user && $ts_pass ]]; then
    curl -s --connect-timeout 0.5 --data-urlencode "user=${ts_user}&password=${ts_pass}&cmnd=${_cmd}" http://${_ip}/cm -o $out || echo "Failed to connect"
  else
    curl -s --connect-timeout 0.5 --data-urlencode "cmnd=${_cmd}" http://${_ip}/cm -o $out || echo "Failed to connect"
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

# Command shell
shell(){
  echo "Input 'exit' or 'quit' to end session"; echo
  list=${1}; ip=${1}
  read -p "${ip}: " cmd
  while [[ $cmd != 'quit' && $cmd != 'exit' ]]; do
    cmdloop
    read -p "${ip}: " cmd
  done
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

 Examples:
   Run command on a large of devices
     $_name <list-file> <command>

   Run command on a small list of devices
     $_name <ip,ip,ip> <command>

   Run command with filtered output
     $_name <list> "status 2" '.StatusFWR | "\(.Version), \(.Hardware)"'

   Run multiple commands, read from a file
     $_name <list> <cmd-file>

   Connect to single device with shell-like command prompt
     $_name <ip>

EOF
exit 1
}

# Main select logic
if [[ ! $1 ]]; then
  read -p "Enter IP to connect to: " ip
  shell $ip
elif [[ $1 =~ -h|--help|help ]]; then
  usage
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
