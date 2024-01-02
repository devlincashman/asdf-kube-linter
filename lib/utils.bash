#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/stackrox/kube-linter"
TOOL_NAME="kube-linter"
TOOL_TEST="kube-linter --help"
LAST_TARGZ_RELEASE="0.5.0"
LAST_BARE_VERSION="0.6.0"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

has_targz() {
  local version="$1"
  case "$(printf "%s\n" "$LAST_TARGZ_RELEASE" "$version" | sort -t. -k1,1 -k2,2 -k3,3 | head -1)" in
  "$LAST_TARGZ_RELEASE") return 1 ;;
  *) return 0 ;;
  esac
}

has_bare_version() {
  local version="$1"
  case "$(printf "%s\n" "$LAST_BARE_VERSION" "$version" | sort -t. -k1,1 -k2,2 -k3,3 | head -1)" in
  "$LAST_BARE_VERSION") return 0 ;;
  *) return 1 ;;
  esac
}

download_url() {
  local version="$1"
  local uname_s os url with_targz with_v
  uname_s="$(uname -s)"

  case "$uname_s" in
  Darwin) os="darwin" ;;
  Linux) os="linux" ;;
  *) fail "OS not supported: $uname_s" ;;
  esac

  if has_targz "$version"; then
    with_targz=".tar.gz"
  else
    with_targz=""
  fi

  if has_bare_version "$version"; then
    with_v="v"
  else
    with_v=""
  fi

  echo "$GH_REPO/releases/download/${with_v}${version}/kube-linter-${os}${with_targz}"
}

download_release() {
  local version="$1"
  local filename="$2"
  local url
  url="$(download_url "$version")"
  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="${3%/bin}/bin"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH/"* "$install_path"
    chmod +x "$install_path/$TOOL_NAME"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
