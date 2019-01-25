OctoPi
======

.. image:: https://raw.githubusercontent.com/guysoft/OctoPi/devel/media/OctoPi.png
.. :scale: 50 %
.. :alt: OctoPi logo

A `Raspberry Pi <http://www.raspberrypi.org/>`_ distribution for 3d printers. It includes the `OctoPrint <http://octoprint.org>`_ host software for 3d printers out of the box and `mjpg-streamer with RaspiCam support <https://github.com/jacksonliam/mjpg-streamer>`_ for live viewing of prints and timelapse video creation.

This repository contains the source script to generate the distribution out of an existing `Raspbian <http://www.raspbian.org/>`_ distro image.

Where to get it?
----------------

Download the latest stable build via this button:

.. image:: https://i.imgur.com/NvUOGfS.png
   :target: https://octopi.octoprint.org/latest

Official mirror is `here <https://github.com/guysoft/OctoPi/releases>`_

Nightly builds are available `here <http://gnethomelinux.com/OctoPi/nightly/>`_

How to use it?
--------------

#. Unzip the image and install it to an sd card `like any other Raspberry Pi image <https://www.raspberrypi.org/documentation/installation/installing-images/README.md>`_
#. Configure your WiFi by editing ``octopi-wpa-supplicant.txt`` on the root of the flashed card when using it like a thumb drive
#. Boot the Pi from the card
#. Log into your Pi via SSH (it is located at ``octopi.local`` `if your computer supports bonjour <https://learn.adafruit.com/bonjour-zeroconf-networking-for-windows-and-linux/overview>`_ or the IP address assigned by your router), default username is "pi", default password is "raspberry". Run ``sudo raspi-config``. Once that is open:

   a. Change the password via "Change User Password"
   b. Optionally: Change the configured timezone via "Localization Options" > "Timezone".
   c. Optionally: Change the hostname via "Network Options" > "Hostname". Your OctoPi instance will then no longer be reachable under ``octopi.local`` but rather the hostname you chose postfixed with ``.local``, so keep that in mind.
  
   You can navigate in the menus using the arrow keys and Enter. To switch to selecting the buttons at the bottom use Tab.
   
   You do not need to expand the filesystem, current versions of OctoPi do this automatically.

OctoPrint is located at `http://octopi.local <http://octopi.local>`_ and also at `https://octopi.local <https://octopi.local>`_. Since the SSL certificate is self signed (and generated upon first boot), you will get a certificate warning at the latter location, please ignore it.

To install plugins from the commandline instead of OctoPrint's built-in plugin manager, :code:`pip` may be found at :code:`/home/pi/oprint/bin/pip`.  Thus, an example install cmd may be:  :code:`/home/pi/oprint/bin/pip install <plugin-uri>`

If a USB webcam or the Raspberry Pi camera is detected, MJPG-streamer will be started automatically as webcam server. OctoPrint on OctoPi ships with correctly configured stream and snapshot URLs pointing at it. If necessary, you can reach it under `http://octopi.local/webcam/?action=stream <octopi.local/webcam/?action=stream>`_ and SSL respectively, or directly on its configured port 8080: `http://octopi.local:8080/?action=stream <octopi.local:8080/?action=stream>`_.

CuraEngine is installed and OctoPrint ships pre-configured with the correct path to utilize it for on-board-slicing. Just import a Cura Slicing Profile in OctoPrint's settings and start slicing directly on your Pi.

Features
--------

* `OctoPrint <http://octoprint.org>`_ host software for 3d printers out of the box
* `Raspbian <http://www.raspbian.org/>`_ tweaked for maximum performance for printing out of the box
* `mjpg-streamer with RaspiCam support <https://github.com/jacksonliam/mjpg-streamer>`_ for live viewing of prints and timelapse video creation.
* `CuraEngine <https://github.com/Ultimaker/CuraEngine>`_ pre-installed for slicing directly on the Raspberry Pi

Developing
----------

Requirements
~~~~~~~~~~~~

#. `qemu-arm-static <http://packages.debian.org/sid/qemu-user-static>`_
#. `CustomPiOS <https://github.com/guysoft/CustomPiOS>`_
#. Downloaded `Raspbian <http://www.raspbian.org/>`_ image.
#. root privileges for chroot
#. Bash
#. git
#. realpath
#. sudo (the script itself calls it, running as root without sudo won't work)

Build OctoPi From within OctoPi / Raspbian / Debian / Ubuntu
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

OctoPi can be built from Debian, Ubuntu, Raspbian, or even OctoPi.
Build requires about 2.5 GB of free space available.
You can build it by issuing the following commands::

    sudo apt-get install gawk util-linux realpath qemu-user-static git p7zip-full python3
    
    git clone https://github.com/guysoft/CustomPiOS.git
    git clone https://github.com/guysoft/OctoPi.git
    cd OctoPi/src/image
    wget -c --trust-server-names 'https://downloads.raspberrypi.org/raspbian_lite_latest'
    cd ..
    ../../CustomPiOS/src/update-custompios-paths
    sudo modprobe loop
    sudo bash -x ./build_dist
    
Building OctoPi Variants
~~~~~~~~~~~~~~~~~~~~~~~~

OctoPi supports building variants, which are builds with changes from the main release build. An example and other variants are available in [CustomPiOS, folder ``src/variants/example``](https://github.com/guysoft/CustomPiOS/tree/CustomPiOS/src/variants/example).

To build a variant use::

    sudo bash -x ./build_dist [Variant]
    
Building Using Docker
~~~~~~~~~~~~~~~~~~~~~~
`See Building with docker entry in wiki <https://github.com/guysoft/CustomPiOS/wiki/Building-with-Docker>`_
    
Building Using Vagrant
~~~~~~~~~~~~~~~~~~~~~~
There is a vagrant machine configuration to let build OctoPi in case your build environment behaves differently. Unless you do extra configuration, vagrant must run as root to have nfs folder sync working.

Make sure you have a version of vagrant later than 1.9!

If you are using older versions of Ubuntu/Debian and not using apt-get `from the download page <https://www.vagrantup.com/downloads.html>`_.

To use it::
    
    sudo apt-get install vagrant nfs-kernel-server virtualbox
    sudo vagrant plugin install vagrant-nfs_guest
    sudo modprobe nfs
    cd ../OctoPi
    git clone https://github.com/guysoft/CustomPiOS.git    
    cd OctoPi/src
    ../../CustomPiOS/src/update-custompios-paths
    cd OctoPi/src/vagrant
    sudo vagrant up
    run_vagrant_build.sh

After provisioning the machine, its also possible to run a nightly build which updates from devel using::

    cd OctoPi/src/vagrant
    run_vagrant_build.sh
    
To build a variant on the machine simply run::

    cd src/vagrant
    run_vagrant_build.sh [Variant]
    

Usage
~~~~~

#. If needed, override existing config settings by creating a new file ``src/config.local``. You can override all settings found in ``src/modules/octopi/config``. If you need to override the path to the Raspbian image to use for building OctoPi, override the path to be used in ``ZIP_IMG``. By default the most recent file matching ``*-raspbian.zip`` found in ``src/image`` will be used.
#. Run ``src/build_dist`` as root.
#. The final image will be created at the ``src/workspace``

Code contribution would be appreciated!
