# 用树莓派（等）为 USB Midi 键盘增添连接方式

我在去年买了一个 M-Audio 的 Midi 键盘，用来连接电脑或者 iPad 弹琴。但是由于琴摆放的位置没有办法拉充电线，所以我能弹琴多久很大程度上取决于设备还有多少电。前一阵子从朋友手里白嫖了个橘子派，鉴于在练琴的时候其实并不需要多高的音质，我决定用这个设备给自己做一个钢琴的音源。

我首先会介绍如何配置 USB Midi 设备发出声音，再介绍如何通过 Midi over BLE 广播 Midi 信号，最后介绍如何通过 Midi over Wifi 来广播 Midi 信号。

## 系统配置

由于我使用的是橘子派而不是树莓派，我遇到了一些只有这边才会遇到的问题，其他开发板可以选择性掠过本节。

橘子派能安装的最新版本 Armbian 内核关闭了 Midi 功能。在各种论坛研究一圈之后，发现旧版本的 Armbian 内核是开了的，于是我下载了使用旧版内核的系统。

（注意使用旧版本系统仅限于本教程前半部分 USB Midi 设备，假如你需要配置蓝牙 Midi，则必须自己编译新内核。可自己 Google 如何编译 Armbian，在编译选项中开启：Device Drivers > Sound card support > Advanced Linux Sound Architecture > Sequencer Support )。参考 [How to Compile Armbian: Step-by-Step Tutorial for Beginners](https://www.youtube.com/watch?v=Fg966ivZlrc) 和 [Armbian - using kernel-config](https://zuckerbude.org/armbian-using-kernel-config/)。

进去之后正常更新系统，旧版镜像要久一点。橘子派还需要在系统中启用声音，使用自带的配置工具 `sudo armbian-config`，启用 System > Hardware > Toggle hardware configuration > analog-codec 。

由于橘子派会等待网络服务激活后才进入系统，导致开机时间非常长，使用下面的命令关闭它：

```
sudo systemctl disable NetworkManager-wait-online
```

你还可以使用 `systemd-analyze blame` 命令查看服务的启动时间，关闭一些其他你不需要的服务。

## 安装 [FluidSynth](http://www.fluidsynth.org)

Debian 源中自带的 FluidSynth 版本比较低，是 1.x 的。由于旧版本的 FluidSynth 并不能自动连接 Midi 设备，我们需要手动编译新版。

为了安装依赖，我们先要调整 apt 源,在文件中取消几个 deb-src 源前面的注释。

```
sudo nano /etc/apt/sources.list
sudo apt-get update
```

安装所有需要的依赖包然后编译。

```
sudo apt-get build-dep fluidsynth --no-install-recommends
git clone https://github.com/FluidSynth/fluidsynth
cd fluidsynth/
mkdir build
cd build
cmake ..
sudo make install
```

接下来在命令行中执行 fluidsynth 确认是否正常。如果出现了找不到库的情况的话，首先应该尝试更新链接库。

```
sudo ldconfig
```

如果这样不行的话，可以添加环境变量。（下面的代码是临时的，永久修改可以自己 Google 一下。）

```
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

确认可以正常运行之后就可以进入下一步骤了。

（本节参阅 [Github](https://github.com/FluidSynth/fluidsynth/wiki/BuildingWithCMake)）


## 获取 Sound Font

如果你尝试过直接用 apt 安装 FluidSynth 的话，你应该会看到它推荐的几个包：fluidr3mono-gm-soundfont、timgm6mb-soundfont、fluid-soundfont-gm。这些都是 Sound Font。但是他们可能不够好听，并不能达到你的要求，这时候你就可以去一些第三方网站下载，比如 [SoundFont4U](https://sites.google.com/site/soundfonts4u/)。

FluidSynth 支持 SF2/SF3 格式的音源文件，不支持 SFZ，请注意不要搞错。自己下载的音源可以存到一个叫 sound-fonts 的文件夹下备用，使用 apt 安装的上述几个音源则安装在 /usr/share/sounds/sf2 文件夹下。

## 测试声音

先运行一次测试是否能够正常出声，这里我使用了 GM 音源。

```
fluidsynth -is -a alsa -m alsa_seq -g 5 -o midi.autoconnect=1 /usr/share/sounds/sf2/FluidR3_GM.sf2
```

解释一下参数：

- a,m 输入输出使用的音频驱动。
- is 作为服务静默运行。
- g 力度阈值，这里设置的大一点，以防一些设备音量太小。
- o 细节参数，这里设置了自动连接 Midi 设备 midi.autoconnect。

（本节参阅 [Github](https://github.com/FluidSynth/fluidsynth/wiki/UserManual)）

运行之后弹一下连接的键盘，看看有没有声音，比较慢的设备可能需要等一段时间才会显示已连接。按照目前的设置，音量应该会蛮大的，如果声音特别小，可以打开 `alsamixer` 调整一下音量，并使用 `sudo alsactl store` 保存状态。确认可以正常演奏之后，就可以进行下一步了。

## FluidSynth 启动服务

为了能够让 FluidSynth 开机启动我们需要自己写一个服务：`sudo nano /etc/systemd/system/fluidsynth.service`。在文件中输入：

```
[Unit]
Description=FluidSynth Daemon
After=sound.target

[Service]
EnvironmentFile=/etc/fluidsynth
ExecStart=/usr/local/bin/fluidsynth -is -a alsa -m alsa_seq -z 64 -c 2 -g $GAIN -o synth.cpu-cores=4 -o midi.autoconnect=1 ${FONT_PATH}

[Install]
WantedBy=multi-user.target
```

解释一下这里多出来的几个参数：

- z 缓存大小，可以使用 64 128 256 等“整数”。
- c 缓存个数，一般为 2 或 3。
- o 多了一个设置 CPU 核心数的选项 synth.cpu-cores，你可以根据自己的开发板来设置。可以装一个 htop 数条条看几个核。

文件中还把音源文件名和力度放在了环境文件中方便设置。新建环境文件：`sudo nano /etc/fluidsynth`，在文件中输入：

```
FONT_PATH=/home/megabits/sound-fonts/SalC5Light2.sf2
GAIN=1.5
```

这个应该就不用我太多解释了。这里将力度设置为 1.5 是我试出来在橘子派上比较合适的音量，你可以自己调。假如你的 Midi 键盘有音量滑杆那就更方便了。

激活服务：

```
sudo systemctl enable fluidsynth
sudo systemctl start fluidsynth
```

之后理论上就应该能正常弹琴了。假如听不到声音，可以用 `journalctl -u fluidsynth` 来查看服务的日志，看看是出了什么问题。如果你只需要用 USB 来连接一下 Midi 设备的话，下面就可以不用看了。

参考文章：

- [Raspberry Pi Zero をMIDI音源ボックス化](http://artteknika.hatenablog.com/entry/2017/04/28/185509)
- [Orange Pi USB MIDI Host](http://hunke.ws/posts/orange-pi-usb-midi-host/)

## Midi over Bluetooth Low Energy

除了直接用这个做音源，我还有希望能够通过 BLE 转发 USB 设备的 Midi 信号到其他设备上方便连接。首先要下载 BlueZ，由于 BlueZ 默认是没有开启 Midi 功能的，所以需要自己编译。此外这里使用的 BlueZ 是一个经过修改的版本，提供了 Midi Server 的功能。不过这个程序有一个蛮烦人的问题，那就是无法同时发送音符，也就是说弹和弦时候，声音永远都对不齐。所以这个就推荐各位自己考虑一下要不要装吧。

```
git clone https://github.com/oxesoft/bluez
sudo apt install -y build-essential
sudo apt install -y autotools-dev libtool autoconf automake
sudo apt install -y libasound2-dev
sudo apt install -y libusb-dev libdbus-1-dev libglib2.0-dev libudev-dev libical-dev libreadline-dev
cd bluez
./bootstrap
./configure --enable-midi --prefix=/usr --mandir=/usr/share/man --sysconfdir=/etc --localstatedir=/var
sudo make install
```

之后测试一下开启服务端并用其他支持 Bluetooth Midi 的软件来搜索，如 iOS 下的 Garageband。

```
sudo btmidi-server -v -n "Midi over BLE"
```

如果出现了 `MGMT_OP_SET_LE failed: Not Supported`，就说明设备不支持 BLE。在确认一切正常后打开另外一个终端窗口，连接好 Midi 设备并扫描。注意在这之前要先用别的设备连接上 Bluetooth Midi，BlueZ 只有在有设备连接时才会创建 Midi 通道。

```
aconnect -l
```

在列表中找到你自己的蓝牙设备和创建的 "Midi over BLE"。比如我的输出结果是：

```
client 0: 'System' [type=kernel]
    0 'Timer           '
    1 'Announce        '
client 14: 'Midi Through' [type=kernel]
    0 'Midi Through Port-0'
client 20: 'Keystation 88' [type=kernel,card=0]
    0 'Keystation 88 MIDI 1'
    1 'Keystation 88 MIDI 2'
client 128: 'Midi over BLE' [type=user,pid=2104]
    0 'Midi over BLE   '
```

这里可以看到我的键盘 "Keystation 88" 编号是 20，"Midi over BLE" 默认编号是 128。 

```
aconnect 20:0 128:0 
```

这样就可以把两个通道连接起来了。去键盘上按几个键，看看连接的设备会不会发出声音。一切正常就可以进行下一步了。

## Midi over BLE 启动服务

新建一个服务：`sudo nano /lib/systemd/system/btmidi.service`，在文件中输入：

```
[Unit]
Description=MIDI Bluetooth connect
After=bluetooth.target sound.target multi-user.target
Requires=bluetooth.target sound.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=btmidi
Restart=always
ExecStart=/usr/bin/btmidi-server -n "Midi over BLE"

[Install]
WantedBy=multi-user.target
```

激活服务：

```
sudo systemctl enable btmidi.service
sudo systemctl start btmidi.service  
```

接下来配置自动连接 Midi 通道，这里我们使用 udev 来在蓝牙设备发生变化时自动连接。首先来写一个连接脚本：

```
touch linkble.sh
chmod a+x linkble.sh
nano linkble.sh
```

这个脚本会自动连接 card=0 和设备 128。

```sh
#!/bin/bash

CLIENT_128_ID=128

CARD_ID=$(aconnect -i | grep "card=0" | cut -d':' -f1 | cut -d' ' -f2)

if [ -z "$CARD_ID" ]; then
  echo "Error: No MIDI device found with card=0"
  exit 1
fi

aconnect "$CARD_ID:0" "$CLIENT_128_ID:0"

if [ $? -eq 0 ]; then
  echo "Successfully connected MIDI device (card=$CARD_ID:0) to client $CLIENT_128_ID:0"
else
  echo "Error: Failed to connect MIDI device to client $CLIENT_128_ID:0"
  exit 1
fi

aconnect "$CARD_ID:1" "$CLIENT_128_ID:0"

if [ $? -eq 0 ]; then
  echo "Successfully connected MIDI device (card=$CARD_ID:1) to client $CLIENT_128_ID:0"
else
  echo "Warning: Could not connect MIDI device card=$CARD_ID:1, likely only one port"
fi

exit 0
```

注意这里要把键盘的名字改成自己的。之所以要用设备名来连接，是因为设备编号是不稳定的。接下来建立规则 `sudo nano /etc/udev/rules.d/44-bt.rules`,在文件中输入：

```
ACTION=="add|remove", SUBSYSTEM=="bluetooth", RUN+="/home/user-name/linkble.sh"
```

刷新规则：

```
sudo udevadm control --reload-rules
```

这样就可以在其他设备连接到 BLE 的时候自动连接通道了。

参考文章：

- [RASPBERRY PI 3B AS USB/BLUETOOTH MIDI HOST](https://neuma.studio/rpi-as-midi-host.html)
- [BlueZ with MIDI over BLE Support](https://tttapa.github.io/Pages/Ubuntu/Software-Installation/BlueZ.html)

## Midi over Wifi

首先需要激活虚拟 Midi 设备模块。

```
modprobe snd-virmidi
aconnect -l
```

如果输出中出现了几个虚拟 Midi 设备就说明设置成功了。为了能让模块永久启用，我们来建立一个配置文件 `sudo nano /etc/modules-load.d/snd-virmidi.conf`，在文件中输入：

```
snd-virmidi
```

保存并重启。

接下来安装 raveloxmidi：

```
sudo apt-get install -y git pkg-config libasound2-dev libavahi-client-dev autoconf automake
sudo apt-get install avahi-daemon
git clone -b experimental https://github.com/ravelox/pimidi.git
cd pimidi/raveloxmidi/ && ./autogen.sh && ./configure && make -j2
sudo make install
```

假如你的网络不支持 ipv6，就需要配置一下 avahi-daemon，打开文件：`sudo nano /etc/avahi/avahi-daemon.conf`，按照下面的值来设置，注意一些行需要取消注释。

```
use-ipv6=no
publish-addresses=yes
publish-aaaa-on-ipv4=no
```

接下来查看可用的设备编号：

```
amidi -l
```

打开 `aconnect -l` 来看一下设备在其中的编号，看一下 Midi 键盘的编号和第一个虚拟设备的编号，我的是 28:0 24:0，把它们连接起来。注意这里的顺序，一定是把键盘通道发送给虚拟设备通道。

```
aconnect 28:0 24:0
```

我这里第一个虚拟 Midi 设备的编号是 hw:2,0，记住这个值。为 raveloxmidi 建立一个配置文件：`/etc/raveloxmidi.conf`，在文件中输入：

```
alsa.input_device = hw:2,0
network.bind_address = 0.0.0.0
logging.enabled = yes
logging.log_level = normal
```

接下来启动测试：

```
sudo raveloxmidi -dN -c /etc/raveloxmidi.conf
```

如果程序正常运行了你应该就可以在其他地方连接它。这里以 macOS 上的 Garageband 为例：

打开 “音频 Midi 音频设置” 并在菜单中打开显示 “Midi 音频工作室”。之后在 “Midi 音频工作室” 的菜单或者工具栏上打开 “Midi 网络设置”。启用 “会话1”。在目录中选择 raveloxmidi，点连接。

打开 Garageband 弹几个音试一试，如果正常出声就是成功了。

## Midi over Wifi 启动服务

新建一个服务：`sudo nano /etc/systemd/system/raveloxmidi.service`，在文件中输入：

```
[Unit]
After=local-fs.target network.target
Description=raveloxmidi RTP-MIDI network server

[Install]
WantedBy=multi-user.target

[Service]
User=root
ExecStartPre=/usr/bin/aconnect 'Keystation 88':0 24:0
ExecStart=/usr/local/bin/raveloxmidi -dN -c /etc/raveloxmidi.conf
```

注意 Midi 设备的名称要改成自己的。激活服务：

```
sudo systemctl enable raveloxmidi.service
sudo systemctl start raveloxmidi.service
```

服务没有启动成功也没关系，可能是因为我们之前已经手动连接过一次 Midi 设备了，重启试试就好。

（本节参阅：[Github](https://github.com/ravelox/pimidi/blob/master/FAQ.md)）

参考文章：

- [Using a Raspberry Pi as a RTP-MIDI Gateway for macOS](https://blog.tarn-vedra.de/pimidi-box/)
- [Raspberry Pi as USB/Bluetooth MIDI host](https://neuma.studio/raspberry-pi-as-usb-bluetooth-midi-host/)

## 后记

最后我还是没能把这些都装好，新内核老内核都有各自的问题，无法两全。在我重新编译的内核的系统中，虽然两边的程序都能正常运行了，但是 alsa 却开始定时输出一些噪音，非常的诡异。真心推荐大家不要购买 Orange Pi Zero，这个板子很要人命。假如你用的是其他的板子，那按照我的教程来弄应该就可以正常使用了。
