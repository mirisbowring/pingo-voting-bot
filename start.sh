#!/bin/bash

URL=$1
OPTION=$2
VOTES=$3

# output colors
BROWN='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

declare -a OPTIONS
declare -a CONFIG
## Config File
## line#1 ~ id
## line#2 ~ authenticity_token

echo "Getting survey from $URL."

#Getting Session Cookie
curl -s 'https://pingo.coactum.de/707759' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: https://pingo.coactum.de/707759' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' -H 'Cache-Control: max-age=0' -I -o header.pingo > /dev/null

SESSION_COOKIE="$(cat header.pingo | tr -d '\r' | sed -En 's/^Set-Cookie: (.*);.*;.*$/\1/p')"
SESSION_COOKIE="${SESSION_COOKIE}"

ETAG="$(cat header.pingo | tr -d '\r' | sed -En 's/^ETag: (.*)/\1/p')"
ETAG="${ETAG}"

rm header.pingo

load_survey()
{
    #Saves the survey page
    curl -s 'https://pingo.coactum.de/707759' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: https://pingo.coactum.de/707759' -H 'Connection: keep-alive' -H "Cookie: $SESSION_COOKIE" -H 'Upgrade-Insecure-Requests: 1' -H "If-None-Match: $ETAG" -H 'Cache-Control: max-age=0' -o pingo.html.pingo > /dev/null
    
    if [[ ${#CONFIG[@]} -eq 0 ]];then
        #Find needed informations from page
        grep -Eo '<label for="option_.[^"]*' pingo.html.pingo > options.pingo
        grep -Eo '<input type="hidden" name="id" id="id" value=".[^"]*' pingo.html.pingo > config.pingo
        grep -Eo '<meta name="csrf-token" content=".[^"]*' pingo.html.pingo >> config.pingo
        #Remove regex identifier
        sed -e 's/<label\ for="option_//g' -i options.pingo
        sed -e 's/<input type="hidden" name="id" id="id" value="//g' -i config.pingo
        sed -e 's/<meta name="csrf-token" content="//g' -i config.pingo
        #Filling array with parsed informations
        readarray -t OPTIONS < options.pingo
        readarray -t CONFIG < config.pingo
    else
        #reloading auth token
        grep -Eo '<meta name="csrf-token" content=".[^"]*' pingo.html.pingo >> config.pingo
        auth_token="$(sed -e 's/<meta name="csrf-token" content="//g' config.pingo)"
        CONFIG[1]="${auth_token}"
    fi
    rm pingo.html.pingo
    rm options.pingo -f
    rm config.pingo
    #encode auth token
    parsed_url=$(curl -s "https://helloacm.com/api/urlencode/?cached&s=${CONFIG[1]}")
    CONFIG[1]="${parsed_url}"
}

echo "Extracting options."
load_survey

echo "Found ${#OPTIONS[@]} options."
if [[ ${#OPTIONS[@]} -eq 0 ]]; then
    echo -e "${RED}No voting options available"
    exit 0
fi

if [[ "$OPTION" -eq "" ]]; then
    echo "On which option do you want to vote for? (choose an int)"
    read OPTION
    OPTION="${OPTIONS[$OPTION]}"
fi

if [[ "$VOTES" -eq "" ]]; then
    echo "How many votes do you want to place?"
    read VOTES
fi

echo -e "${BROWN}Start voting $VOTES times for option $OPTION on $URL."

echo $COMMAND

for run in $(seq $VOTES); do
    #Send Vote post
    curl -s 'https://pingo.coactum.de/vote' -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:65.0) Gecko/20100101 Firefox/65.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'Referer: https://pingo.coactum.de/707759' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H "Cookie: $SESSION_COOKIE" -H 'Upgrade-Insecure-Requests: 1' --data "utf8=%E2%9C%93&authenticity_token=${CONFIG[1]}&option%5B%5D=$OPTION&id=${CONFIG[0]}&commit=Vote%21" > /dev/null

    echo -e "${GREEN}Voted $run has been placed.${RESET}"

    if [[ $run -ne $VOTES]];then
        #Reloading survey
        load_survey
    fi
done
