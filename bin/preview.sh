#!/usr/bin/env bash


if [ "$1" = "-w" ]; then
    VIM_PREVIEW_FILE=$HOME/.config/king/vim_preview_file.txt
    line="$3"
    if [[ "$line" != *':'* ]]; then
        # line is a file path
        cword="$2"
        echo "$line" > $VIM_PREVIEW_FILE
        ag --color "$cword" "$line" 2>/dev/null
        exit 0
    else
        # reload and reset params
        FILE_PATH=`cat $VIM_PREVIEW_FILE`
        set -- "$FILE_PATH:$line"
    fi
fi


REVERSE="\x1b[7m"
RESET="\x1b[m"

if [ -z "$1" ]; then
  echo "usage: $0 [--tag] FILENAME[:LINENO][:IGNORED]"
  exit 1
fi

if [ "$1" = --tag ]; then
  shift
  "$(dirname "${BASH_SOURCE[0]}")/tagpreview.sh" "$@"
  exit $?
fi

IFS=':' read -r -a INPUT <<< "$1"
FILE=${INPUT[0]}
CENTER=${INPUT[1]}

if [[ "$1" =~ ^[A-Za-z]:\\ ]]; then
  FILE=$FILE:${INPUT[1]}
  CENTER=${INPUT[2]}
fi

if [[ -n "$CENTER" && ! "$CENTER" =~ ^[0-9] ]]; then
  exit 1
fi
CENTER=${CENTER/[^0-9]*/}

# MS Win support
if [[ "$FILE" =~ '\' ]]; then
  if [ -z "$MSWINHOME" ]; then
    MSWINHOME="$HOMEDRIVE$HOMEPATH"
  fi
  if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
    MSWINHOME="${MSWINHOME//\\/\\\\}"
    FILE="${FILE/#\~\\/$MSWINHOME\\}"
    FILE=$(wslpath -u "$FILE")
  elif [ -n "$MSWINHOME" ]; then
    FILE="${FILE/#\~\\/$MSWINHOME\\}"
  fi
fi

FILE="${FILE/#\~\//$HOME/}"
if [ ! -r "$FILE" ]; then
  echo "File not found ${FILE}"
  exit 1
fi

if [ -z "$CENTER" ]; then
  CENTER=0
fi

# Sometimes bat is installed as batcat.
if command -v batcat > /dev/null; then
  BATNAME="batcat"
elif command -v bat > /dev/null; then
  BATNAME="bat"
fi

if [ -z "$FZF_PREVIEW_COMMAND" ] && [ "${BATNAME:+x}" ]; then
  ${BATNAME} --style="${BAT_STYLE:-numbers}" --color=always --pager=never \
      --theme='Monokai Extended' --highlight-line=$CENTER -- "$FILE"
  exit $?
fi

FILE_LENGTH=${#FILE}
MIME=$(file --dereference --mime -- "$FILE")
if [[ "${MIME:FILE_LENGTH}" =~ binary ]]; then
  echo "$MIME"
  exit 0
fi

DEFAULT_COMMAND="highlight -O ansi -l {} || coderay {} || rougify {} || cat {}"
CMD=${FZF_PREVIEW_COMMAND:-$DEFAULT_COMMAND}
CMD=${CMD//{\}/$(printf %q "$FILE")}

eval "$CMD" 2> /dev/null | awk "{ \
    if (NR == $CENTER) \
        { gsub(/\x1b[[0-9;]*m/, \"&$REVERSE\"); printf(\"$REVERSE%s\n$RESET\", \$0); } \
    else printf(\"$RESET%s\n\", \$0); \
    }"
