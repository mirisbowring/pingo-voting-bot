#!/bin/bash

#########################################################
# Reimplements the echo command
# Globals:
#   NAME
# Arguments:
#   None
# Returns:
#   None
#########################################################
echo()
{
    if [[ ! -z "$NAME" ]]; then
        builtin echo -n "<$NAME>"
    fi
    if [[ $2 -eq "style" ]]; then
        builtin echo -e "$1"
    else
        builtin echo "$1"
    fi
}

#########################################################
# Receives a session cookie and the ETag from the Website
# Globals:
#   SESSION_COOKIE
#   ETAG
# Arguments:
#   None
# Returns:
#   None
#########################################################
get_session_cookie()
{
    # Getting the Header
    curl -s 'https://pingo.coactum.de/707759' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: https://pingo.coactum.de/707759' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' -H 'Cache-Control: max-age=0' -I -o header.pingo > /dev/null

    # Extracting the session cookie
    SESSION_COOKIE="$(cat header.pingo | tr -d '\r' | sed -En 's/^Set-Cookie: (.*);.*;.*$/\1/p')"
    SESSION_COOKIE="${SESSION_COOKIE}"

    # Extracting the ETag
    ETAG="$(cat header.pingo | tr -d '\r' | sed -En 's/^ETag: (.*)/\1/p')"
    ETAG="${ETAG}"

    # Removing tmp file
    rm header.pingo
}

#################################################################
# loading survey informations from website
# -> evaluating the informations
# -> only reloads the auth token if the CONFIG array is not empty
# Globals:
#   CONFIG
# Arguments:
#   None
# Returns:
#   None
#################################################################
load_survey()
{
    # Getting the survey page
    curl -s 'https://pingo.coactum.de/707759' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: https://pingo.coactum.de/707759' -H 'Connection: keep-alive' -H "Cookie: $SESSION_COOKIE" -H 'Upgrade-Insecure-Requests: 1' -H "If-None-Match: $ETAG" -H 'Cache-Control: max-age=0' -o pingo.html.pingo > /dev/null
    
    # Parse all information if the config array is empty (indicates that the
    # was not running before).
    if [[ ${#CONFIG[@]} -eq 0 ]];then
        # Find needed informations from downloaded voting page
        grep -Eo '<label for="option_.[^"]*' pingo.html.pingo > options.pingo
        grep -Eo '<input type="hidden" name="id" id="id" value=".[^"]*' pingo.html.pingo > config.pingo
        grep -Eo '<meta name="csrf-token" content=".[^"]*' pingo.html.pingo >> config.pingo
        # Remove regex identifier
        sed -e 's/<label\ for="option_//g' -i options.pingo
        sed -e 's/<input type="hidden" name="id" id="id" value="//g' -i config.pingo
        sed -e 's/<meta name="csrf-token" content="//g' -i config.pingo
        # Filling array with parsed informations
        readarray -t OPTIONS < options.pingo
        readarray -t CONFIG < config.pingo
    else
        #reloading auth token
        grep -Eo '<meta name="csrf-token" content=".[^"]*' pingo.html.pingo >> config.pingo
        auth_token="$(sed -e 's/<meta name="csrf-token" content="//g' config.pingo)"
        CONFIG[1]="${auth_token}"
    fi
    # Removing temporary files
    rm pingo.html.pingo
    rm config.pingo
    # Force this file to be deleted because it does not exist in every case
    rm options.pingo -f
    
    #encode auth token to a url string
    parsed_url=$(curl -s "https://helloacm.com/api/urlencode/?cached&s=${CONFIG[1]}")
    CONFIG[1]="${parsed_url}"
}

#################################################################
# Prints the help page
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#################################################################
print_help()
{
    echo "Usage: $0 [option]... {url}" >&2
    echo
    echo "Optional arguments:"
    echo "   -h, --help                 Shows this help page"
    echo "   -n, --name                 <worker_name> is used by the script"
    echo "                                itselfs when working async"
    echo "   -o, --option               Specifies which option should"
    echo "                                be taken (starting at 1)"
    echo "   -v, --votes                Specifies how many votes should"
    echo "                                be send"
    echo "   -w, --worker               Specifies the amound of workers"
    echo

    exit 0
}


POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -h|--help)
        print_help
        exit 0
        ;;
        -n|--name)
        NAME="$2"
        shift 2
        ;;
        -o|--option)
        OPTION="$2"
        shift 2
        ;;
        -v|--votes)
        VOTES="$2"
        shift 2
        ;;
        -w|--worker)
        WORKER="$2"
        shift 2
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

URL=$1

# Output colors
BROWN='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

## Config file
## line#1 ~ id
## line#2 ~ authenticity_token
declare -a OPTIONS
declare -a CONFIG

### Verifies that a URL has been specified
if [[ -z "$URL" ]]; then
    echo "You must specify an Survey URL"
    exit 1
fi

### Checks whether the script should work async
if [[ $WORKER -eq "" ]]; then
    echo "Preparing the async work."

fi



### Starting script
echo "Getting survey from $URL."

### Getting Session Cookie
get_session_cookie

### Extracting survey details
echo "Extracting options."
load_survey

### Exit if no option was found
echo "Found ${#OPTIONS[@]} options."
if [[ ${#OPTIONS[@]} -eq 0 ]]; then
    echo "${RED}No voting options available" style
    exit 0
fi

### Ask the user if no voting option has been passed as command line argument
if [[ "$OPTION" -eq "" ]]; then
    echo "On which option do you want to vote for? (choose an int)"
    read OPTION
fi

### Replaces the option number with the generic option id
OPTION="${OPTIONS[$((OPTION-1))]}"

### Ask the user if no vote amount has been passed as command line argument
if [[ "$VOTES" -eq "" ]]; then
    echo "How many votes do you want to place?"
    read VOTES
fi
echo $VOTES
echo $OPTION
### Notify the user that the script is about to start
echo -e "${BROWN}Start voting $VOTES times for option $OPTION on $URL."

### Iterate through the votes
for run in $(seq $VOTES); do
    # Send Vote post
    curl -s 'https://pingo.coactum.de/vote' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: https://pingo.coactum.de/707759' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H "Cookie: $SESSION_COOKIE" -H 'Upgrade-Insecure-Requests: 1' --data "utf8=%E2%9C%93&authenticity_token=${CONFIG[1]}&option%5B%5D=$OPTION&id=${CONFIG[0]}&commit=Vote%21" > /dev/null

    # Notify the user about the Progress (does not validate the success of the
    # vote)
    echo -e "${GREEN}Voted $run has been placed.${RESET}"

    # Refresh the survey auth token if this is not the last round
    if [[ $run -ne $VOTES ]]; then
        #Reloading survey
        load_survey
    fi
done
