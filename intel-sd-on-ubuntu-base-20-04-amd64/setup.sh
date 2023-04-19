#!/bin/bash

# One-shot environment setup for test from host
set -e

ORIG_PWD="$PWD"
ENV_DIRECTORY_NAME="$(basename $PWD)"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-$ENV_DIRECTORY_NAME}"

if [ "$(hostname)" != "$ENVIRONMENT_NAME" ] ; then
  if [ -z "$OVERLAY_BASE" ] ; then
    echo "error, setup.sh expected an ai-specific OVERLAY_BASE=$OVERLAY_BASE to be set but it is empty!"
    exit 1
  fi
  
  # We manually download + extracted
  #   https://cdimage.ubuntu.com/ubuntu-base/releases/focal/release/ubuntu-base-20.04.1-base-amd64.tar.gz
  # to /j/infra/ai/ai-disk/"$ENVIRONMENT_NAME"

  exec sudo systemd-nspawn \
    -D /j/infra/ai/ai-disk/"$ENVIRONMENT_NAME" \
    --setenv=TERM=xterm \
    --capability=all \
    --capability=CAP_SYS_ADMIN \
    --system-call-filter=modify_ldt \
    --bind="$ORIG_PWD":"$ORIG_PWD" \
    --bind=/run/user/1000:/run/user/1000 \
    --bind=/var/lib/dbus \
    --bind=/dev/dri \
    --bind=/tmp \
    --machine="$ENVIRONMENT_NAME" \
    --hostname="$ENVIRONMENT_NAME"

  exit

fi


if ! [ -z "$DEBUG" ] ; then
  exec bash
  exit
fi

# Now we are within the container, ensure our GPU is setup
# gpu-dump





cat <<EOF

Welcome to the $ENVIRONMENT_NAME container!

   See https://www.intel.com/content/www/us/en/developer/articles/technical/running-tensorflow-stable-diffusion-on-intel-arc.html#gs.u5ufin
   for setup.

   conda activate keras-cv
   jupyter notebook --allow-root

   Also See https://dgpu-docs.intel.com/installation-guides/ubuntu/ubuntu-focal-dc.html#step-1-add-package-repository
   for intel driver nonsense

EOF


exec bash
