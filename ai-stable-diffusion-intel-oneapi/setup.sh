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
  echo contain /j/infra/ai/$ENVIRONMENT_NAME "$0"
  exec contain /j/infra/ai/$ENVIRONMENT_NAME "$0"
  exit

fi


if ! [ -z "$DEBUG" ] ; then
  exec bash
  exit
fi

# Now we are within the container, ensure our GPU is setup
gpu-dump

arch_pkgs=(
  opencv openmp
  intel-oneapi-basekit
  # stable-diffusion-intel # stability??? See https://github.com/bes-dev/stable_diffusion.openvino
   pypy3
)
for p in "${arch_pkgs[@]}" ; do
  if ! pacman -Q | awk '{print $1}' | grep -xq "$p" ; then
    echo "Missing package $p, installing..."
    # Try to auto-install everything, fall back to asking human to type things in on conflicts
    yay -S --noconfirm --answerdiff=None "$p" || yay -S "$p"
  fi
done


if ! [ -e /opt/stable_diffusion.openvino/demo.py ] ; then
  sudo mkdir -p /opt/stable_diffusion.openvino
  sudo chown -R $UID /opt/stable_diffusion.openvino
  
  git clone https://github.com/bes-dev/stable_diffusion.openvino.git /opt/stable_diffusion.openvino
  
  cd /opt/stable_diffusion.openvino
  
  python -m pip --default-timeout=9000 install 'openvino-dev[onnx,pytorch]==2022.3.0'
  python -m pip --default-timeout=9000 install -r requirements.txt

  pypy3 -m ensurepip
  pypy3 -m pip --default-timeout=9000 install 'openvino-dev[onnx,pytorch]==2022.3.0'
  pypy3 -m pip --default-timeout=9000 install -r requirements.txt

  cd "$ORIG_PWD"
fi

cat <<EOF

Welcome to the $ENVIRONMENT_NAME container!

   cd /opt/stable_diffusion.openvino
   
   python demo.py --device GPU.1 --prompt "Bubbles in the night sky" --seed 0 --num-inference-steps 26 --guidance-scale 7.5 

   python demo.py --device GPU.1 --prompt "Bubbles in the night sky" --init-image ./data/input.png --strength 0.5

   python demo.py --device GPU.1 --prompt "Bubbles in the night sky" --init-image ./data/input.png --mask ./data/mask.png --strength 0.5


EOF


exec bash
