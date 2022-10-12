#!/usr/bin/env bash
# shellcheck shell=bash
# Bash 3 compatible for Darwin

# Script taken from https://github.com/NixOS/nixpkgs/blob/0b20bf89e0035b6d62ad58f9db8fdbc99c2b01e8/pkgs/tools/admin/pulumi/update.sh
# and slightly modified to use the environment configured by the containing flake.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Version of Pulumi from
# https://www.pulumi.com/docs/get-started/install/versions/
VERSION="3.42.0"

# An array of plugin names. The respective repository inside Pulumi's
# Github organization is called pulumi-$name by convention.

declare -a pulumi_repos
pulumi_repos=(
  "docker"
  "gcp"
  "google-native"
  "github"
  "gitlab"
  "kubernetes"
  "postgresql"
  "random"
  "tls"
  "vault"

  # "aiven"
  # "akamai"
  # "alicloud"
  # "artifactory"
  # "auth0"
  # "aws"
  # "azure"
  # "azuread"
  # "azuredevops"
  # "cloudflare"
  # "consul"
  # "datadog"
  # "digitalocean"
  # "equinix-metal"
  # "fastly"
  # "linode"
  # "mailgun"
  # "mysql"
  # "openstack"
  # "hcloud"
  # "snowflake"
  # "spotinst"
  # "sumologic"
  # "tailscale"
  # "venafi"
  # "vsphere"
  # "wavefront"
  # "yandex"
)

# Contains latest release ${VERSION} from
# https://github.com/pulumi/pulumi-${NAME}/releases

# Dynamically builds the plugin array, using the GitHub API for getting the
# latest version.
plugin_num=1
plugins=()
for key in "${pulumi_repos[@]}"; do
  plugin="${key}=$(gh api "repos/pulumi/pulumi-${key}/releases/latest" --jq '.tag_name | sub("^v"; "")')"
  printf "%20s: %s of %s\r" "${plugin}" "${plugin_num}" "${#pulumi_repos[@]}"
  plugins+=("${plugin}")
  sleep 1
  ((++plugin_num))
done
printf "\n"

function genMainSrc() {
  local url="https://get.pulumi.com/releases/sdk/pulumi-v${VERSION}-${1}-${2}.tar.gz"
  local sha256
  sha256=$(nix-prefetch-url "$url")
  echo "      {"
  echo "        url = \"${url}\";"
  echo "        sha256 = \"$sha256\";"
  echo "      }"
}

function genSrc() {
  local url="${1}"
  local plug="${2}"
  local tmpdir="${3}"

  local sha256
  sha256=$(nix-prefetch-url "$url")

  {
    if [ -n "$sha256" ]; then # file exists
      echo "      {"
      echo "        url = \"${url}\";"
      echo "        sha256 = \"$sha256\";"
      echo "      }"
    else
      echo "      # pulumi-resource-${plug} skipped (does not exist on remote)"
    fi
  } > "${tmpdir}/${plug}.nix"
}

function genSrcs() {
  local tmpdir
  tmpdir="$(mktemp -d)"

  local i=0

  for plugVers in "${plugins[@]}"; do
    local plug=${plugVers%=*}
    local version=${plugVers#*=}
    # url as defined here
    # https://github.com/pulumi/pulumi/blob/06d4dde8898b2a0de2c3c7ff8e45f97495b89d82/pkg/workspace/plugins.go#L197
    local url="https://api.pulumi.com/releases/plugins/pulumi-resource-${plug}-v${version}-${1}-${2}.tar.gz"
    genSrc "${url}" "${plug}" "${tmpdir}" &
    ((++i))
  done

  wait

  find "${tmpdir}" -name '*.nix' -print0 | sort -z | xargs -r0 cat
  rm -r "${tmpdir}"
}

{
  cat << EOF
# DO NOT EDIT! This file is generated automatically by update.sh
_:
{
  version = "${VERSION}";
  pulumiPkgs = {
EOF

  echo "    x86_64-linux = ["
  genMainSrc "linux" "x64"
  genSrcs "linux" "amd64"
  echo "    ];"

  echo "    x86_64-darwin = ["
  genMainSrc "darwin" "x64"
  genSrcs "darwin" "amd64"
  echo "    ];"

  echo "    aarch64-linux = ["
  genMainSrc "linux" "arm64"
  genSrcs "linux" "arm64"
  echo "    ];"

  echo "    aarch64-darwin = ["
  genMainSrc "darwin" "arm64"
  genSrcs "darwin" "arm64"
  echo "    ];"

  echo "  };"
  echo "}"

} > "${SCRIPT_DIR}/data.nix"
