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

  container_root_dir="/j/infra/ai/ai-disk/$ENVIRONMENT_NAME"

  if ! [ -e "$container_root_dir" ] ; then
    echo "Downloading container files to $container_root_dir"
    docker-fetcher 'l1naforever/stable-diffusion-rocm:latest' "$container_root_dir" 
  fi

  # exec sudo systemd-nspawn \
  #   -D "$container_root_dir" \
  #   --setenv=TERM=xterm \
  #   --capability=all \
  #   --bind="$ORIG_PWD":"$ORIG_PWD" \
  #   --bind=/dev/kfd \
  #   --bind=/dev/dri \
  #   --bind=/dev/shm \
  #   --bind=/tmp \
  #   --machine="$ENVIRONMENT_NAME" \
  #   --hostname="$ENVIRONMENT_NAME"

  exec sudo systemd-nspawn \
    -D "$container_root_dir" \
    --setenv=TERM=xterm \
    --capability=all \
    --bind=/dev/kfd \
    --bind=/dev/dri \
    --bind=/dev/shm \
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

   See https://github.com/l1na-forever/stable-diffusion-rocm-docker
   First run:
      cd /sd
      source venv/bin/activate
      rocminfo # Test GPU
      python launch.py --precision full --no-half

  Then open a browser to http://localhost:7860/
  
  We should be able to load alternative models by replacing /sd/models/Stable-diffusion/model.ckpt

EOF

exec bash
