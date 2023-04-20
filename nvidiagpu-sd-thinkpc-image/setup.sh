#!/bin/bash

# One-shot environment setup for test from host
set -e

ORIG_PWD="$PWD"
ENV_DIRECTORY_NAME="$(basename $PWD)"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-$ENV_DIRECTORY_NAME}"

os_root_folder="/j/infra/ai/ai-disk/$ENVIRONMENT_NAME-root"

mkdir -p "$os_root_folder"

cd "$os_root_folder"

if ! [ -e bin/ ] ; then
  # Install the OS

  sudo pacstrap -K "$os_root_folder" base linux linux-firmware \
    vim sudo python python-pip base-devel git

fi

cat <<EOF

Welcome to the $ENVIRONMENT_NAME container!

Install Setup:
  
  pacman -S sudo vim base-devel python python-pip git

  echo 'ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"' | sudo tee /etc/udev/rules.d/99-removable.rules

  useradd -m -G wheel -s /bin/bash admin
  sudo vim /etc/sudoers # grant wheel access to passwordless sudo
  usermod -a -G video admin
  usermod -a -G render admin
  
  sudo vim /etc/locale.gen
  sudo locale-gen

  sudo mkdir -p /opt/yay
  sudo chown admin:admin /opt/yay
  # As admin
  git clone https://aur.archlinux.org/yay.git /opt/yay
  cd /opt/yay
  makepkg -si
  
  yay -S xf86-video-nouveau stable-diffusion-ui

  # sudo pip install torch torchvision torchaudio
  # sudo mkdir /opt/InvokeAI
  # sudo chown admin:admin /opt/InvokeAI
  # git clone https://github.com/invoke-ai/InvokeAI.git /opt/InvokeAI
  # cd /opt/InvokeAI

  sudo mount -o remount,size=24G,noatime /tmp # Fix for pip out-of-disk-space errors

  pip install InvokeAI --use-pep517

  export PATH=\$PATH:\$HOME/.local/bin

  invokeai-configure

  # To import .ckpt/.safetensors, run invokeai
  # and enter
  !import_model /path/to/martians.safetensors

  # Dependencies for https://invoke-ai.github.io/InvokeAI/installation/060_INSTALL_PATCHMATCH/#linux
  sudo pacman -S python-opencv opencv --overwrite '*'
  ( cd /usr/lib/pkgconfig/ ; sudo ln -sf opencv4.pc opencv.pc )
  pip install pypatchmatch
  # Test with
  python -c 'from patchmatch import patch_match'

  sudo chown -R admin:admin /usr/lib/python3.10/site-packages/patchmatch

  # Yeah we're deep in the weeds rn: https://github.com/invoke-ai/InvokeAI/issues/2217#issuecomment-1435671028
  cd /usr/lib/python3.10/site-packages/torch
  find . -iname '*libgomp*so*'
  # Move it somewhere, remember the name
  sudo cp ./lib/libgomp-a34b3233.so.1 ./lib/_ORIGINAL_libgomp-a34b3233.so.1
  rm lib/libgomp-a34b3233.so.1
  sudo ln -s /usr/lib/libgomp.so.1 lib/libgomp-a34b3233.so.1

  sudo pacman -S mesa-utils
  DISPLAY=:0 DRI_PRIME=1 glxgears -info


  yay -S clang
  export CC=clang
  export CXX=clang++

  ldconfig
  
  # From homepage on https://pytorch.org/
  pip install --user torch torchvision torchaudio

  # very important!
  yay -S nvidia cuda
  # Also we'll have to boot using the regular kernel -_-...

  python -c 'import torch ; print("GPU detected: ", torch.cuda.is_available())'


Running:
  
  invokeai --precision=float32 --free_gpu_mem --web --host 127.0.0.1

  stable-diffusion-ui-server

EOF


sudo arch-chroot  "$os_root_folder"

sync

exit 0


