#!/usr/bin/env bash

function die () {
    echo >&2 "$@"
    exit 1
}

function fixLd(){
  sed -i 's@/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@\#/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@' etc/ld.so.preload
  sed -i 's@/usr/lib/arm-linux-gnueabihf/libarmmem.so@\#/usr/lib/arm-linux-gnueabihf/libarmmem.so@' etc/ld.so.preload
}

function restoreLd(){
  sed -i 's@\#/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@/usr/lib/arm-linux-gnueabihf/libcofi_rpi.so@' etc/ld.so.preload
  sed -i 's@\#/usr/lib/arm-linux-gnueabihf/libarmmem.so@/usr/lib/arm-linux-gnueabihf/libarmmem.so@' etc/ld.so.preload
}

function pause() {
  # little debug helper, will pause until enter is pressed and display provided
  # message
  read -p "$*"
}

function gitclone(){
  # call like this: gitclone OCTOPI_OCTOPRINT_REPO someDirectory -- this will do:
  #
  #   sudo -u pi git clone -b $OCTOPI_OCTOPRINT_REPO_BRANCH --depth $OCTOPI_OCTOPRINT_REPO_DEPTH $OCTOPI_OCTOPRINT_REPO_BUILD someDirectory
  # 
  # and if $OCTOPI_OCTOPRINT_REPO_BUILD != $OCTOPI_OCTOPRINT_REPO_SHIP also:
  #
  #   pushd someDirectory
  #     sudo -u pi git remote set-url origin $OCTOPI_OCTOPRINT_REPO_SHIP
  #   popd
  # 
  # if second parameter is not provided last URL segment of the BUILD repo URL
  # minus the optional .git postfix will be used

  repo_build_var=$1_BUILD
  repo_ship_var=$1_SHIP
  repo_branch_var=$1_BRANCH
  repo_depth_var=$1_DEPTH
  
  repo_dir=$2
  if [ ! -n "$repo_dir" ]
  then
    repo_dir=$(echo ${REPO} | sed 's%^.*/\([^/]*\)\(\.git\)?$%\1%g')
  fi

  repo_depth=${!repo_depth_var}
  if [ -n "$repo_depth" ]
  then
    depth=$repo_depth
  else
    if [ "$#" -gt 2 ]
    then
      depth=$3
    fi
  fi

  build_repo=${!repo_build_var}
  ship_repo=${!repo_ship_var}
  branch=${!repo_branch_var}

  if [ ! -n "$build_repo" ]
  then
    build_repo=$ship_repo
  fi

  clone_params=
  if [ -n "$branch" ]
  then
    clone_params="-b $branch"
  fi

  if [ -n "$depth" ]
  then
    clone_params="$clone_params --depth $depth"
  fi

  sudo -u pi git clone $clone_params "$build_repo" "$repo_dir"

  if [ "$build_repo" != "$ship_repo" ]
  then
    pushd "$repo_dir"
      sudo -u pi git remote set-url origin "$ship_repo"
    popd
  fi
}

function unpack() {
  # call like this: unpack /path/to/source /target user -- this will copy
  # all files & folders from source to target, preserving mode and timestamps
  # and chown to user. If user is not provided, no chown will be performed

  from=$1
  to=$2
  owner=
  if [ "$#" -gt 2 ]
  then
    owner=$3
  fi

  # $from/. may look funny, but does exactly what we want, copy _contents_
  # from $from to $to, but not $from itself, without the need to glob -- see 
  # http://stackoverflow.com/a/4645159/2028598
  cp -v -r --preserve=mode,timestamps $from/. $to
  if [ -n "$owner" ]
  then
    chown -hR $owner:$owner $to
  fi
}

function mount_image() {
  image_path=$1
  mount_path=$2

  # dump the partition table, locate boot partition and root partition
  boot_partition=1
  root_partition=2
  fdisk_output=$(sfdisk -d $image_path)
  boot_offset=$(($(echo "$fdisk_output" | grep "$image_path$boot_partition" | awk '{print $4-0}') * 512))
  root_offset=$(($(echo "$fdisk_output" | grep "$image_path$root_partition" | awk '{print $4-0}') * 512))

  echo "Mounting image $image_path on $mount_path, offset for boot partition is $boot_offset, offset for root partition is $root_offset"

  # mount root and boot partition
  sudo mount -o loop,offset=$root_offset $image_path $mount_path/
  sudo mount -o loop,offset=$boot_offset $image_path $mount_path/boot
  sudo mount -o bind /dev/pts $mount_path/dev/pts
}

function unmount_image() {
  mount_path=$1
  force=
  if [ "$#" -gt 1 ]
  then
    force=$2
  fi

  if [ -n "$force" ]
  then
    for process in $(sudo lsof $mount_path | awk '{print $2}')
    do
      echo "Killing process id $process..."
      sudo kill -9 $process
    done
  fi

  # unmount first boot, then root partition
  for m in $(sudo mount | grep $mount_path | awk '{print $3}' | sort -r)
  do
    echo "Unmounting $m..."
    sudo umount $m
  done
}

function cleanup() {
    # make sure that all child processed die when we die
    local pids=$(jobs -pr)
    [ -n "$pids" ] && kill $pids && sleep 5 && kill -9 $pids
    exit 0
}

function install_fail_on_error_trap() {
  set -e
  trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
  trap 'if [ $? -ne 0 ]; then echo -e "\nexit $? due to $previous_command \nBUILD FAILED!" && echo "unmounting image..." && ( unmount_image $OCTOPI_MOUNT_PATH force || true ); fi;' EXIT
}

function install_chroot_fail_on_error_trap() {
  set -e
  trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
  trap 'if [ $? -ne 0 ]; then echo -e "\nexit $? due to $previous_command \nBUILD FAILED!"; fi;' EXIT
}

function install_cleanup_trap() {
  set -e
  trap "cleanup" SIGINT SIGTERM
 }

function enlarge_ext() {
  # call like this: enlarge_ext /path/to/image partition size
  #
  # will enlarge partition number <partition> on /path/to/image by <size> MB
  image=$1
  partition=$2
  size=$3

  echo "Adding $size MB to partition $partition of $image"
  start=$(sfdisk -d $image | grep "$image$partition" | awk '{print $4-0}')
  offset=$(($start*512))
  dd if=/dev/zero bs=1M count=$size >> $image
  fdisk $image <<FDISK
p
d
$partition
n
p
$partition
$start

p
w
FDISK

  LODEV=$(losetup -f --show -o $offset $image)
  trap 'losetup -d $LODEV' EXIT

  e2fsck -fy $LODEV
  resize2fs -p $LODEV
  losetup -d $LODEV

  trap - EXIT
  echo "Resized parition $partition of $image to +$size MB"
}

function minimize_ext() {
  image=$1
  partition=$2
  buffer=$3

  echo "Resizing partition $partition on $image to minimal size + $buffer MB"
  start=$(sfdisk -d $image | grep "$image$partition" | awk '{print $4-0}')
  offset=$(($start*512))

  LODEV=$(losetup -f --show -o $offset $image)
  trap 'losetup -d $LODEV' EXIT

  e2fsck -fy $LODEV
  e2fblocksize=$(tune2fs -l $LODEV | grep -i "block size" | awk -F: '{print $2-0}')
  e2fminsize=$(resize2fs -P $LODEV 2>/dev/null | grep -i "minimum size" | awk -F: '{print $2-0}')

  e2fminsize_bytes=$(($e2fminsize * $e2fblocksize))
  e2ftarget_bytes=$(($buffer * 1024 * 1024 + $e2fminsize_bytes))

  e2fminsize_mb=$(($e2fminsize_bytes / 1024 / 1024))
  e2fminsize_blocks=$(($e2fminsize_bytes / 512 + 1))
  e2ftarget_mb=$(($e2ftarget_bytes / 1024 / 1024))
  e2ftarget_blocks=$(($e2ftarget_bytes / 512 + 1))

  echo "Minimum size is $e2fminsize_mb MB ($e2fminsize file system blocks, $e2fminsize_blocks blocks), resizing to $e2ftarget_mb MB ($e2ftarget_blocks blocks)"

  echo "Resizing file system to $e2target_blocks blocks..."
  resize2fs $LODEV ${e2ftarget_blocks}s
  losetup -d $LODEV
  trap - EXIT

  new_end=$(($start + $e2ftarget_blocks))

  echo "Resizing partition to end at $start + $e2ftarget_blocsk = $new_end blocks..."
  fdisk $image <<FDISK
p
d
$partition
n
p
$partition
$start
$new_end
p
w
FDISK

  new_size=$((($new_end + 1) * 512))
  echo "Truncating image to $new_size bytes..."
  truncate --size=$new_size $image
  fdisk -l $image

  echo "Resizing filesystem ..."
  LODEV=$(losetup -f --show -o $offset $image)
  trap 'losetup -d $LODEV' EXIT

  e2fsck -fy $LODEV
  resize2fs -p $LODEV
  losetup -d $LODEV
  trap - EXIT
}
