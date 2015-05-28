# openwrt-buildroot-example
 Example docker environment for building images for a specific project.

 ## Getting started

 ### Dependencies
 Make sure you have the following dependencies installed.
 - Git ([installation instructions](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git))
 - Docker ([installation instructions](https://docs.docker.com/installation/)) ([Using Docker through Kitematic on OS X](https://github.com/Doodle3D/openwrt-buildroot/blob/master/README.md#using-docker-through-kitematic-on-os-x))

 ### OpenWrt Buildroot
 Checkout this repository and run `Run.sh`.
 ```bash
 $ git clone https://github.com/Doodle3D/openwrt-buildroot-example.git
 $ cd openwrt-buildroot-example
 $ ./Run.sh setup
 ```
 Use `./Run.sh help` to view available commands.

 ## Background
 This buildroot is a sharable build environment to build OpenWRT images with a custom project specific configuration and packages. The resulting image can be flashed to a OpenWRT compatible device, currently specifically the TP-Link MR3020.
 Instead of contaminating your machine with lots of build dependencies, which vary per operating system, we create a separate virtual machine using [Docker](http://docker.com/) ([Understanding docker](http://docs.docker.com/introduction/understanding-docker/)).

 We created [Run.sh](https://github.com/Doodle3D/openwrt-buildroot/blob/master/Run.sh) to automate the most common use case; building an image and flashing this to a OpenWRT device.

 1. The *Run.sh* script will clone custom packages, so these can be developed locally.
 2. A [container](http://docs.docker.com/introduction/understanding-docker/#docker-containers) is created the buildroot [image](http://docs.docker.com/introduction/understanding-docker/#docker-images). This image is comparable to a *.img* file used with VirtualBox or an operating system installation disk. We've already uploaded a ready made buildroot image, but you can also build it yourself, see *Image development*.
 3. In this buildroot container, our [Build.sh](https://github.com/Doodle3D/openwrt-buildroot/blob/master/Build.sh) is executed. This will use the local packages (through a [shared volume](http://docs.docker.com/userguide/dockervolumes/#data-volumes)), build the actual OpenWRT image and copy the image to the shared *bin* volume.
 4. Flash this OpenWRT image it to an OpenWRT device that connected to your computer.

 ## Image development
 Clone this repository
 ```bash
 $ git clone https://github.com/Doodle3D/openwrt-buildroot-example.git
 $ cd openwrt-buildroot-example
 ```
 Build image from Dockerfile (normally this is downloaded from Docker Hub)
 This is done according to our [Dockerfile](https://github.com/Doodle3D/openwrt-buildroot/blob/master/Dockerfile).
 ```bash
 $ docker build -t yourcompany/openwrt-buildroot dockerfile/
 ```
 Run as interactive docker container.
 This enables you to access the buildroot container and make changes. <br/>
 Using our Run.sh:
 ``` bash
 $ ./Run.sh interactive
 ```
 Original command:
 ``` bash
 $ docker run -t -i -v "$PWD/bin:/home/openwrt/shared/bin" -v "$PWD/customfeeds:/home/openwrt/shared/customfeeds" -u openwrt --name buildroot yourcompany/openwrt-buildroot bash
 ```
 ### Common Docker commands
 ``` bash
 user@container: $ exit # exit container
 $ docker ps # show running containers
 $ docker ps -a -s # show all containers with size
 $ docker start <NAME> # (re)start container
 $ docker attach <NAME> # attach to container
 # docker pull <IMAGE_NAME> # update an image
 ```
 ### Updating image
 Since rebuilding the image takes a lot of time, it's usually more convenient to update the image. This can be done by creating a container from an image, updating the container and committing these changes into the image.
 ``` bash
 # Create & run an image interactively executing bash instead of Build.sh
 $ docker run -t -i -u openwrt --name openwrt-buildroot yourcompany/openwrt-buildroot bash
 # Make the changes and exit the container...
 # Commit the changes back into the image, while restoring the command to Build.sh. You can specify what's changed with a message using the -m flag.
 $ docker commit -c "CMD /home/openwrt/bin/Build.sh" -m="{change message}" openwrt-buildroot yourcompany/openwrt-buildroot
 ```

 ## Using Docker through Kitematic on OS X
 [Kitematic](http://kitematic.com/) is a gui to make using Docker easier. It creates a Docker host (Virtual machine) in which the Docker deamon, images and containers live.
 Our Run.sh script will automatically start the Docker Host. You can also start the Docker host manually using:
 ```
 $ docker-machine start dev
 ```
 For Docker to access this Docker Host it needs certain Environment variables. Our Run.sh script will export these automatically for that session. You can also include the following line in your `~/.bash_profile` to have these permanently available.
 ```
 eval "$(docker-machine env dev)"
 ```
 Save and `$ source ~/.bash_profile` to load the changes.
