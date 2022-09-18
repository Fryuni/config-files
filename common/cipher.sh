#!/bin/bash
set -eu -o pipefail

ME="/home/$(whoami)"
DOTDIR="${ME}/ZShutils"
gcloud=$ME/google-cloud-sdk/bin/gcloud

declare -rA COLORS=(
    [RED]=$'\033[0;31m'
    [GREEN]=$'\033[0;32m'
    [BLUE]=$'\033[0;34m'
    [PURPLE]=$'\033[0;35m'
    [CYAN]=$'\033[0;36m'
    [WHITE]=$'\033[0;37m'
    [YELLOW]=$'\033[0;33m'
    [BOLD]=$'\033[1m'
    [OFF]=$'\033[0m'
)

print_red () {
    echo -e "\n${COLORS[RED]}${1}${COLORS[OFF]}\n"
}

print_yellow () {
    echo -e "\n${COLORS[YELLOW]}${1}${COLORS[OFF]}\n"
    sleep 1
}

print_green () {
    echo -e "\n${COLORS[GREEN]}${1}${COLORS[OFF]}\n"
    sleep 1
}

print_cyan () {
    echo -e "\n${COLORS[CYAN]}${1}${COLORS[OFF]}\n"
}

wait_key () {
    echo -e "\n${COLORS[YELLOW]}"
    read -n 1 -s -r -p "${1}"
    echo -e "${COLORS[OFF]}\n"
}

authenticate_gcloud () {
    $gcloud --quiet config configurations activate default
    $gcloud config set project lferraz-portfolio

    $gcloud auth list --format=json | jq -e '.[] | select(.account == "luiz@lferraz.com")' > /dev/null
    if [ $? == 0 ]; then
    	$gcloud --quiet config set account luiz@lferraz.com
    else
    	$gcloud auth login
    fi
}

encrypt_rcfile () {
    msg="Encrypting rcfile $1 ..."
    print_yellow "${msg}"
    local rcbase="$DOTDIR/rcfiles/$1"
    local cipher_rc="$rcbase.cipher"
    local plain_rc="$rcbase.unsafe"

    $gcloud --project lferraz-portfolio kms encrypt \
        --ciphertext-file "$cipher_rc" \
        --plaintext-file "$plain_rc" \
        --location global \
        --keyring cipher-files \
        --key rcfiles
}

authenticate_gcloud
encrypt_rcfile "npmrc"
encrypt_rcfile "maven_settings"
