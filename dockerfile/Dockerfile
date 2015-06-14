FROM ubuntu:14.10

MAINTAINER info@yourcompany.com

# install dependencies
RUN apt-get update &&\
    apt-get install -y git-core subversion build-essential gcc-multilib \
                       libncurses5-dev zlib1g-dev gawk flex gettext wget unzip python nano &&\
    apt-get clean

# add user
RUN useradd -m openwrt
RUN echo 'openwrt ALL=NOPASSWD: ALL' > /etc/sudoers.d/openwrt

# set user
USER openwrt

# set workdir
WORKDIR /home/openwrt

# checkout openwrt
RUN git clone git://git.openwrt.org/14.07/openwrt.git trunk

# set workdir
WORKDIR /home/openwrt/trunk/

# copy build script into container
COPY Build.sh /home/openwrt/bin/
RUN sudo chmod +x /home/openwrt/bin/Build.sh

# update and install feeds
RUN scripts/feeds update -a
RUN scripts/feeds install -a

# define .config file
RUN echo CONFIG_TARGET_ar71xx=y > .config #defconfig always needs a target
RUN make defconfig

# update config file
# NOTE: copy custom config changes (diffconfig) to the default config
RUN mkdir -p /home/openwrt/config/
COPY diffconfig /home/openwrt/config/diffconfig
RUN cat /home/openwrt/config/diffconfig >> .config

# NOTE: run defconfig again to apply overrides
RUN make defconfig

# download sources before make
RUN make download

# NOTE: run defconfig again to apply overrides (again after download)
RUN make defconfig

# build in verbose mode
RUN make V=s

# prepare customfeeds folder (virtual mounted folder)
RUN cp feeds.conf.default feeds.conf
RUN echo 'src-link customfeeds /home/openwrt/shared/customfeeds' >> feeds.conf
RUN cat /home/openwrt/trunk/feeds.conf
RUN mkdir -p /home/openwrt/shared/customfeeds

# launch at docker run
CMD ["/home/openwrt/bin/Build.sh"]
