#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)" 1>&2
  exit 1;
fi

uname_r=$(uname -r)

num=1
while [ $num -le 2000 ]; do
  git clone https://github.com/Seeed-Studio/seeed-linux-dtoverlays.git
if [ $? -ne 0 ]; then
       num=$(($num+1))
   else
       break
   fi
done


cd seeed-linux-dtoverlays
sed -i "227 i fragment@8 {\n\ttarget = <&hdmi0>;\n\t\t__overlay__  {\n\t\t\tstatus = \"disabled\";\n\t\t\t};\n\t\t};\n\tfragment@9 {\n\t\ttarget = <&hdmi1>;\n\t\t__overlay__  {\n\t\t\tstatus = \"disabled\";\n\t\t};\n\t};" overlays/rpi/reTerminal-overlay.dts

make KBUILD=/lib/modules/$uname_r/build all_rpi
sudo make KBUILD=/lib/modules/$uname_r/build KO_DIR=/lib/modules/$uname_r/extra/seeed install_rpi

rm -rf seeed-linux-dtoverlays