#!/bin/sh

VOLUME_BIN="$PWD/bin:/home/openwrt/shared/bin"
VOLUME_FEEDS="$PWD/customfeeds:/home/openwrt/shared/customfeeds"
DOCKER_IMAGE="yourcompany/openwrt-buildroot"
DOCKER_CONTAINER_NAME="buildroot"
INTERACTIVE_DOCKER_CONTAINER_NAME="buildroot-interactive"
FEEDS_DIR="customfeeds"
REPO_BASE="git@github.com:yourcompany/"
REPO_EXT=".git"
#REPO[0]="custompackage"

DEVICE_NAME="devicename" # example: box
DEVICE_HOSTNAME="device hostname" # example: 192.168.5.1
DEVICE_USER="root"

###############################################
function clone() {
  echo 'clone...'

  # if dir customfeeds does not exists: create
  if [ ! -d "$FEEDS_DIR" ]; then
    echo "[ok] creating dir $FEEDS_DIR"
    mkdir $FEEDS_DIR
  else
    echo "[ok] $FEEDS_DIR already exists"
  fi

  # into dir
  cd "$FEEDS_DIR"
  echo "[note] working dir: $PWD"

  # loop repositories, clone if not exists
  for repo in "${REPO[@]}"
  do
    URL="$REPO_BASE""$repo""$REPO_EXT"
    if [ ! -d "$repo" ]; then
      git clone --recursive $URL
      echo "[ok] cloned " $URL
    else
      echo "[note] repository already exists:" $repo
    fi
  done

  # back to root dir
  cd ..

  # done
  echo "[ok] done."
}

###############################################
function checkdocker() {
  echo 'checking Docker...'
  # start with docker host check?
  docker info > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo '[ok] Docker is available'
  else
    echo '[note] Docker not (yet) available'
    # checking Docker host availablility
    docker-machine inspect dev > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo '[note] Docker host found, starting host'
      docker-machine start dev
      if [ ! $DOCKER_HOST ]; then
        echo '[note] Exporting Docker host environment variables'
        eval "$(docker-machine env dev)"
      fi
    else
      echo '[error] Can not start Docker, please install Docker. See: https://docs.docker.com/installation/#installation'
      exit 1
    fi
  fi
}

###############################################
function image() {
  echo 'Check, pull or build image ...'

  checkdocker
  
  if [ `docker images | grep "$DOCKER_IMAGE" | wc -l` -gt 0 ]; then
    echo '[note] found docker image: '"$DOCKER_IMAGE"
  else
    echo '[note] image not found, checking docker hub'
    docker pull "$DOCKER_IMAGE"
    if [ $RESULT -eq 0 ]; then
      echo '[ok] pulled docker image successful'
    else
      echo '[note] docker image not found on docker hub'
      echo "> build image"
      docker build -t $DOCKER_IMAGE dockerfile/
    fi
  fi
}

###############################################
function build() {
  echo 'build...'

  checkdocker

  BIN="./bin"
  FEEDS_DIR="customfeeds"

  # if dir bin does not exists: create
  if [ ! -d "$BIN" ]; then
    echo "[ok] creating dir $BIN"
    mkdir $BIN
  else
    echo "[ok] $BIN already exists"

    # clear bin
    cd $BIN
    rm -rf ./*
    cd -
    echo "[ok] emptied ""$BIN""/*"
  fi

  # check if customfeeds dir exists
  if [ ! -d "$FEEDS_DIR" ]; then
    echo "[error] no $FEEDS_DIR dirs"
    exit 1
  fi

  #docker
  echo 'docker run... (executes Build.sh inside container)'
  docker run --rm -v "$VOLUME_BIN" -v "$VOLUME_FEEDS" -u openwrt --name=$DOCKER_CONTAINER_NAME $DOCKER_IMAGE

  # check if succeeded
  NUM_BIN_FILES=`ls "$BIN" | wc -l`
  if [ $NUM_BIN_FILES -gt 0 ]; then
      echo "[ok] new built files are copied succesfully"
  else
      echo "[error] $BIN is empty"
      exit 1
  fi

  # done
  echo "[ok] done."
}

###############################################
function interactive() {
  echo 'docker run interactive...'

  if [ `docker ps -aqf "name=$INTERACTIVE_DOCKER_CONTAINER_NAME" | wc -l` -gt 0 ]; then
    echo '[note] restarting existing container'
    docker start $INTERACTIVE_DOCKER_CONTAINER_NAME
    docker attach $INTERACTIVE_DOCKER_CONTAINER_NAME
  else
    echo '[note] creating new container'
    docker run -t -i -v "$VOLUME_BIN" -v "$VOLUME_FEEDS" -u openwrt --name=$INTERACTIVE_DOCKER_CONTAINER_NAME $DOCKER_IMAGE bash
  fi
}

###############################################
function flash() {
  echo 'flash...'

  # how to
  echo '[note] connect an ethernet cable to $DEVICE_NAME and host computer...'
  read -t 20 -p "Hit ENTER or wait 20 seconds";

  # make sure device is listed in ~/.ssh/config
  SSH_CONFIG="$HOME/.ssh/config"

  echo "> check ssh config file"
  if grep -q "$DEVICE_NAME" "$SSH_CONFIG"; then
    echo "'$DEVICE_NAME' is already listed in ssh config file"
  else
    echo "'$DEVICE_NAME' is NOT listed in .ssh/config file: append"
    echo "creating ssh config backup: "$SSH_CONFIG"_backup"
    sudo cp $SSH_CONFIG $SSH_CONFIG"_backup"
    CONFIG=$(printf '\n%s\n\t%s\n\t%s\n\t%s\n\t%s\n' 'Host '$DEVICE_NAME 'Hostname '$DEVICE_HOSTNAME 'User '$DEVICE_USER 'StrictHostKeyChecking no' 'UserKnownHostsFile=/dev/null')
    sudo sh -c "echo '$CONFIG' >> $SSH_CONFIG"
    echo "> added to ssh config file:$CONFIG"
  fi


  # copy binary to device using scp to /tmp folder
  # if a file is supplied use that to flash the device, otherwise choose a file from the bin folder
  if [ -f "$1" ];
  then
    SOURCE_PATH="$(dirname $1)/"
    BINARY="$(basename $1)"
  else
    SOURCE_PATH="bin/ar71xx/"
    BINARY="openwrt-ar71xx-generic-tl-mr3020-v1-squashfs-sysupgrade.bin"
  fi

  FOLDER="/tmp/"

  if [ -n "$2" ];
  then
    FLAGS="$2"
  else
    FLAGS=""
  fi

  # check if binary exists
  if [ -f "$SOURCE_PATH""$BINARY" ];
  then
     echo "[ok] binary exists"
  else
     echo "[error] binary does not exist: ""$SOURCE_PATH""$BINARY"
     exit 1
  fi

  # ssh copy
  echo "> ssh copy ""$BINARY"" to ""$DEVICE_NAME":"$FOLDER"
  scp "$SOURCE_PATH""$BINARY" "$DEVICE_NAME":"$FOLDER"

  if [ $? -eq 0 ]; then
    # execute sysupgrade command on device
    echo "> excecute sysupgrade on ""$DEVICE_NAME"
    CMD="sysupgrade -v $FLAGS ""$FOLDER""$BINARY"
    ssh $DEVICE_NAME "$CMD"

    # done
    echo "[ok] done."
  else
    echo "[error] Couldn't copy file to $DEVICE_NAME"
    exit 1
  fi
}

###############################################
function update() {
  echo 'updating...'

  # update buildroot
  git pull
  echo "[ok] updated buildroot"

  # if dir customfeeds does not exists: exit
  if [ ! -d "$FEEDS_DIR" ]; then
    echo "[error] no '$FEEDS_DIR' folder available"
    exit 1
  fi

  # go into dir
  cd "$FEEDS_DIR"
  echo "[note] working dir: $PWD"

  # loop repositories, clone if not exists
  for repo in "${REPO[@]}"
  do
    URL="$REPO_BASE""$repo""$REPO_EXT"
    if [ -d "$repo" ]; then
      cd "$repo"
      git pull
      echo "[ok] git pulled (updated)" $URL
      cd ..
    else
      echo "[error] repo '$repo' not available"
    fi
  done

  # back to root dir
  cd ..

  # update docker image
  docker pull $DOCKER_IMAGE
  echo "[ok] updated docker image"

  # done
  echo "[ok] done."

}

###############################################
function help() {
  echo 'help...'
  echo ''
  echo 'Usage: ./Run.sh {COMMAND}'
  echo ''
  echo 'Commands:'
  echo "   setup               clone repo's, build Docker image (when unavailable) and OpenWRT image"
  echo '   clone               clone repositories in ./customfeeds dir'
  echo '   image               build Docker image (when unavailable)'
  echo '   build               build OpenWRT image'
  echo '   flash [file [-n]]   flash a built OpenWrt image to device over ssh'
  echo '   deploy              build OpenWRT image and flash to device'
  echo '   interactive         Create or start and existing buildroot container interactively'
  echo '   update              Update the buildroot, git pull latest custom feeds and update docker image'
  echo '   help                show this help'
  echo ''
}

###############################################
case "$1" in
setup) clone && image && build ;;
clone) clone ;;
build) build ;;
image) image ;;
flash) flash $2 $3 ;;
deploy) build && flash ;;
interactive) interactive ;;
update) update ;;
*) help ;;
esac
