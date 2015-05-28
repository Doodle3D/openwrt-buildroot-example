#!/bin/sh

# set workdir
echo "> set workdir"
cd /home/openwrt/trunk/
echo "> pwd: $PWD"

# update feeds
echo "> update and install customfeeds"
scripts/feeds update customfeeds # download from source into feeds folder and parse info to index
scripts/feeds install -a -p customfeeds # make all packages from this feed available for install

#update .config file
echo "> update config file"
cat /home/openwrt/config/diffconfig >> .config
make defconfig

echo "> clear bin"
cd bin
rm -rf *
cd -

# build
# DOCS: V=s : s is stdout+stderr (equal to the old V=99)
# DOCS: -j [jobs]: devide build process over multiple processors
echo "> make"
make V=s -j $(($(getconf _NPROCESSORS_ONLN)+1))
RESULT=$?
if [ $RESULT -eq 0 ]; then
  echo '[ok] Build successful'

  # copy binary to shared folder
  echo "> copy bin folder to shared folder"
  echo "> path: /home/openwrt/shared/bin"
  cp -r bin /home/openwrt/shared/

  # complete
  echo "> complete"
else
  echo '[error] Build failed'
fi
