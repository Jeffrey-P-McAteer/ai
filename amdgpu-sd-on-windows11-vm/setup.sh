#!/bin/sh

set -e


ORIG_PWD="$PWD"
ENV_DIRECTORY_NAME="$(basename $PWD)"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-$ENV_DIRECTORY_NAME}"


env_dir="ai-disk/$ENVIRONMENT_NAME"

mkdir -p "$env_dir"
cd "$env_dir"

pwd

wget \
  --continue -q --show-progress \
  -O WinDev.Eval.Virtualbox.zip \
  "https://download.microsoft.com/download/4/e/f/4ef4a123-758a-4184-828b-216082409b89/WinDev2303Eval.VirtualBox.zip"

mkdir -p WinDev.Eval.Virtualbox
unzip WinDev.Eval.Virtualbox.zip -d WinDev.Eval.Virtualbox

ls -alh WinDev.Eval.Virtualbox





