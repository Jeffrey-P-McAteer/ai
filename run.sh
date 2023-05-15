#!/bin/bash

# One-shot environment setup for test from host
set -e

subdirectory="$1"
if ! [ -d "$subdirectory" ] ; then
  echo "Unknown subdirectory '$subdirectory'"
  exit 1
fi

if grep -q 'ai-disk' <<<"$subdirectory" ; then
  echo "Refusing to treat '$subdirectory' as a container, it is a disk mount point!"
  exit 1
fi


storage_disk="/dev/disk/by-label/ai"

if ! [ -e "$storage_disk" ] ; then
  echo "Please plug in the disk labeled 'ai' to use as storage! ($storage_disk)"
  exit 1
fi

storage_disk_device=$(realpath $(dirname "$storage_disk")/$(readlink "$storage_disk"))
storage_disk_mountpoint=$(mount | grep "$storage_disk_device" | cut -d' ' -f3)

touch /tmp/noauto-disks.txt
if ! grep -q "$storage_disk_device" /tmp/noauto-disks.txt ; then
  echo "$storage_disk_device" >> /tmp/noauto-disks.txt
fi

if ! grep -q '/j/infra/ai/ai-disk' <<<"$storage_disk_mountpoint" ; then
  echo "Detected AI disk at $storage_disk_mountpoint but we want it at /j/infra/ai/ai-disk, unmounting..."
  sync
  sudo umount $storage_disk_device || true
  sync
  storage_disk_mountpoint=$(mount | grep "$storage_disk_device" | cut -d' ' -f3)
fi

if [ -z "$storage_disk_mountpoint" ] ; then
  echo "$storage_disk_device is not mounted, mounting to /j/infra/ai/ai-disk..."
  mkdir -p /j/infra/ai/ai-disk
  sudo mount "$storage_disk_device" /j/infra/ai/ai-disk
  storage_disk_mountpoint="/j/infra/ai/ai-disk"
  sudo chown $UID "$storage_disk_mountpoint"
fi

# We assume we'll need a TON of swap for model-compilation steps;
# We create and manage a 64-GB swapfile for AI model junk.
if ! [ -e /j/infra/ai/ai-disk/swapfile ] ; then
  echo "Creating 64GB swapfile at /j/infra/ai/ai-disk/swapfile, this could take a long time but only needs to happen once..."
  sudo dd if=/dev/zero of=/j/infra/ai/ai-disk/swapfile bs=1G count=64 status=progress
fi
if ! grep -q  /j/infra/ai/ai-disk/swapfile /proc/swaps ; then
  echo "Saw we have /j/infra/ai/ai-disk/swapfile but it is not swapped on, enabling..."
  sudo chmod 0600 /j/infra/ai/ai-disk/swapfile || true
  sudo swapoff /j/infra/ai/ai-disk/swapfile || true
  sync
  sudo mkswap -U clear /j/infra/ai/ai-disk/swapfile || true
  sync
  sudo swapon /j/infra/ai/ai-disk/swapfile || true
  sync
fi

export OVERLAY_BASE="$storage_disk_mountpoint"
export DRI_PRIME=1

cd "/j/infra/ai/$subdirectory"

export ENVIRONMENT_NAME=$(echo "$subdirectory" | tr -d '/' | tr -d '.')

if [ -e ./setup.sh ]; then
  exec ./setup.sh
else
  # Misc shared/common env vars for my machine
  export RUSTBERT_CACHE='/j/infra/ai/ai-disk/rust-bert-model-cache'

  cat <<EOF

Dropping to a shell on $HOST at $ENVIRONMENT_NAME

EOF
  exec bash
fi
