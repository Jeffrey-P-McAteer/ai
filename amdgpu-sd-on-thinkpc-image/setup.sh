#!/bin/bash

# One-shot environment setup for test from host
set -e

ORIG_PWD="$PWD"
ENV_DIRECTORY_NAME="$(basename $PWD)"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-$ENV_DIRECTORY_NAME}"


storage_disk="/dev/disk/by-partuuid/13f2fa76-69cd-41ea-b5f5-83429372506f"

if ! [ -e "$storage_disk" ] ; then
  echo "Please plug in the partition '13f2fa76-69cd-41ea-b5f5-83429372506f' to use as storage! ($storage_disk)"
  exit 1
fi

storage_disk_device=$(realpath $(dirname "$storage_disk")/$(readlink "$storage_disk"))
storage_disk_mountpoint=$(mount | grep "$storage_disk_device" | cut -d' ' -f3)

touch /tmp/noauto-disks.txt
if ! grep -q "$storage_disk_device" /tmp/noauto-disks.txt ; then
  echo "$storage_disk_device" >> /tmp/noauto-disks.txt
fi

if ! grep -q '/mnt/thinkpc' <<<"$storage_disk_mountpoint" ; then
  echo "Detected thinkpc disk at $storage_disk_mountpoint but we want it at /mnt/thinkpc, unmounting..."
  sync
  sudo umount $storage_disk_device
  sync
  storage_disk_mountpoint=$(mount | grep "$storage_disk_device" | cut -d' ' -f3)
fi

if [ -z "$storage_disk_mountpoint" ] ; then
  echo "$storage_disk_device is not mounted, mounting to /mnt/thinkpc..."
  sudo mkdir -p /mnt/thinkpc
  sudo mount "$storage_disk_device" /mnt/thinkpc
  storage_disk_mountpoint="/mnt/thinkpc"
fi

cd "$storage_disk_mountpoint"

if ! [ -e bin/ ] ; then
  # Install the OS

  sudo pacstrap -K "$storage_disk_mountpoint" base linux linux-firmware \
    vim sudo python python-pip base-devel git

fi

cat <<EOF

Welcome to the $ENVIRONMENT_NAME container!

Install Setup:
  
  pacman -S sudo vim base-devel python python-pip git

  echo 'ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"' | sudo tee /etc/udev/rules.d/99-removable.rules

  export HSA_OVERRIDE_GFX_VERSION=10.3.0

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
  
  yay -S opencl-amd opencl-amd-dev amd-vulkan-prefixes vulkan-amdgpu-pro vulkan-radeon xf86-video-amdgpu

  # sudo pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/rocm5.1.1
  # sudo mkdir /opt/InvokeAI
  # sudo chown admin:admin /opt/InvokeAI
  # git clone https://github.com/invoke-ai/InvokeAI.git /opt/InvokeAI
  # cd /opt/InvokeAI

  sudo mount -o remount,size=24G,noatime /tmp # Fix for pip out-of-disk-space errors

  pip install InvokeAI --use-pep517 --extra-index-url https://download.pytorch.org/whl/rocm5.4.2

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

  # Uhhhh
  # NOPE export HSA_OVERRIDE_GFX_VERSION=10.3.0

  yay -S clang
  export CC=clang
  export CXX=clang++

  ldconfig
  
  export USE_CUDA=0
  export USE_ROCM=1
  export MAX_JOBS=1
  sudo mkdir /opt/pytorch-git
  sudo chown admin:admin /opt/pytorch-git
  git clone https://github.com/pytorch/pytorch.git /opt/pytorch-git
  cd /opt/pytorch-git
  git checkout -f v2.0.0
  git submodule update --init --recursive
  python tools/amd_build/build_amd.py
  USE_CUDA=0 USE_ROCM=1 MAX_JOBS=4 python setup.py install


  # From homepage on https://pytorch.org/
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.4.2
  # ^^ seems to work??

  python -c 'import torch ; print("GPU detected: ", torch.cuda.is_available())'

  export AMDGPU_TARGETS=$(rocminfo | grep -oh 'Name.*gfx.*' | head -n 1 | awk '{print $2}')


Running:
  
  invokeai --precision=float32 --free_gpu_mem --web --host 127.0.0.1

EOF


sudo arch-chroot  "$storage_disk_mountpoint"

sync

exit 0


