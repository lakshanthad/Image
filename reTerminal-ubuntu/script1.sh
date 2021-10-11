#!/bin/bash

uname_r=$(uname -r)
arch_r=$(dpkg --print-architecture)

url="http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/"

# Check root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)" 1>&2
  exit 1
  fi

KERNAL_VERSION=""
function download_install_debpkg() {
  local version-kernel-headers version-kernel
  mkdir temporary_dir

  wget http://archive.raspberrypi.org/debian/pool/main/r/raspberrypi-firmware/ -O rpi-kernel-version-text

  version_kernel_headers=`cat rpi-kernel-version-text  | grep raspberrypi-kernel-headers | grep arm64 | awk 'END { print }' | awk '{print $6}' | awk -F '\"' '{print $2} '`
  version_kernel=`cat rpi-kernel-version-text  | grep raspberrypi-kernel | grep arm64 | awk 'END { print }' | awk '{print $6}' | awk -F '\"' '{print $2} '`

  wget -P temporary_dir $url$version_kernel_headers
  wget -P temporary_dir $url$version_kernel

  sudo dpkg -i temporary_dir/$version_kernel_headers
  sudo dpkg -i temporary_dir/$version_kernel

  #copy bcm2711-rpi-4-b.dtb to the specified directory,then install again
  sudo cp /boot/bcm2711-rpi-4-b.dtb /etc/flash-kernel/dtbs/
  sudo dpkg -i temporary_dir/$version_kernel
  
  rm -f rpi-kernel-version-text
  rm -r -f temporary_dir

	KERNAL_VERSION=`ls -1t /lib/modules/ | sed -n '1p'`
}

RASPI_VMLINUZ=""
function find_raspi_vmlinuz() {

#  sudo apt-get update
#  sudo apt-get -y --force-yes full-upgrade

  RASPI_VMLINUZ=`ls -1t /lib/modules/ | sed -n '1p'`

  echo "$RASPI_VMLINUZ"
}

#change the running kernel to latest
function install_kernel() {
  local vmlinuz
  
  find_raspi_vmlinuz
  
  download_install_debpkg
  
  cd /boot/

  vmlinuz="vmlinuz-$RASPI_VMLINUZ"

  sudo cp $vmlinuz $vmlinuz.bak
  sudo cp kernel8.img $vmlinuz
 
  sudo update-initramfs -u
  sync

  return 0
}
function install_seeed_driver() {
	sudo apt -y --force-yes install build-essential

  cd ~
  
num=1
while [ $num -le 2000 ]; do
	git clone https://github.com/Seeed-Studio/seeed-linux-dtoverlays
if [ $? -ne 0 ]; then
       num=$(($num+1))
   else
       break
   fi
done
	cd seeed-linux-dtoverlays

	sed -i "227 i fragment@8 {\n\ttarget = <&hdmi0>;\n\t\t__overlay__  {\n\t\t\tstatus = \"disabled\";\n\t\t\t};\n\t\t};\n\tfragment@9 {\n\t\ttarget = <&hdmi1>;\n\t\t__overlay__  {\n\t\t\tstatus = \"disabled\";\n\t\t};\n\t};" overlays/rpi/reTerminal-overlay.dts

	make KBUILD=/lib/modules/$KERNAL_VERSION/build all_rpi
	sudo make KBUILD=/lib/modules/$KERNAL_VERSION/build KO_DIR=/lib/modules/$KERNAL_VERSION/extra/seeed install_rpi

	echo "#-------------------------------------------
dtoverlay=vc4-fkms-v3d
enable_uart=1
dtoverlay=dwc2,dr_mode=host
dtparam=ant2
disable_splash=1
ignore_lcd=1
dtoverlay=vc4-kms-v3d-pi4
dtoverlay=i2c3,pins_4_5
gpio=13=pu
dtoverlay=reTerminal,tp_rotate=1
#------------------------------------------" >> /boot/firmware/config.txt

	sudo cp /boot/overlays/reTerminal.dtbo /boot/firmware/overlays/reTerminal.dtbo

	sudo cp overlays/rpi/reTerminal-overlay.dtbo /boot/firmware/overlays/reTerminal.dtbo

  cd -

  sudo rm -r -f seeed-linux-dtoverlays
}

function creat_symbolic_link() {
	
	sudo cp /boot/firmware/bcm2711-rpi-cm4.dtb /boot/firmware/bcm2711-rpi-cm4.dtb.bak
	sudo cp /boot/bcm2711-rpi-cm4.dtb /boot/firmware/
	cd /boot/
	sudo cp bcm2711-rpi-cm4.dtb dtbs/$RASPI_VMLINUZ/./
	sudo rm dtb
	sudo ln -s dtbs/$RASPI_VMLINUZ/./bcm2711-rpi-cm4.dtb dtb
	sudo rm dtb-$RASPI_VMLINUZ
	sudo ln -s dtbs/$RASPI_VMLINUZ/./bcm2711-rpi-cm4.dtb dtb-$RASPI_VMLINUZ
	sudo cp bcm2711-rpi-cm4.dtb dtbs/$KERNAL_VERSION/./
	sudo rm dtb-$KERNAL_VERSION
	sudo ln -s dtbs/$KERNAL_VERSION/./bcm2711-rpi-cm4.dtb dtb-$KERNAL_VERSION
	
	sync
}


function reterminal_make_install() {

  touch once_install.sh
  chmod +x once_install.sh
  sudo cp once_install.sh /
  echo "#!/bin/bash
  sudo make KBUILD=/lib/modules/$KERNAL_VERSION/build KO_DIR=/lib/modules/$KERNAL_VERSION/extra/seeed install_rpi
  sudo chmod -x once_install.sh
  " >> once_install.sh
  
}

function install() {

  install_kernel
	install_seeed_driver
	sudo apt install -y --force-yes ubuntu-desktop
	creat_symbolic_link

  echo "------------------------------------------------------"
  echo "Please reboot your device to apply all settings"
  echo "Enjoy!"
  echo "------------------------------------------------------"
}
install



