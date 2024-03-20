# 在 Debian 上使用 Mac mini 的红外接收器控制 CD 播放

这个需求可以说是相当小众了，毕竟像我这么怀旧的人不多。因为我在用 2014 款的 Mac mini 当家里的服务器，所以我很想发挥它最大的作用，而且我有很多 CD。这一代的机器本身是没有光驱的，但我有一个外接的苹果光驱。我用的是初代的苹果遥控器，整个配置做好后可以实现如下功能：

- 按播放键开始播放/暂停
- 音量增减
- 上一曲/下一曲
- 长按菜单键弹出光盘

## 安装声卡驱动

这里我们使用 piewire。虽然实际上是只用 palse 的接口的，不过把能装的都装了反正以后也要用。如果你的电脑带声音之类的都配置好了，可以跳过这一章节。

```bash
sudo apt install pipewire pipewire-audio pipewire-alsa pipewire-jack pipewire-pulse
systemctl enable --user --now wireplumber
```

测试一下声音正不正常

```bash
sudo apt-get install alsa-utils
alsamixer # 调一下系统音量要么听不见
speaker-test
```

## 安装播放器

```bash
sudo apt install mplayer
```

编辑 mplayer 的配置文件 `.mplayer/config` 在其中加入如下内容：

```bash
cache=2048 # 不加的话放 CD 会卡
volume=70
lircc=Yes # 接收遥控器
```

然后插一张碟测试一下。播放时候可以按 9 和 0 来调节音量。! 和 @ 可以上一曲下一曲。


```bash
mplayer cdda://
```

## 配置 lirc

首先下载 Mac mini 红外接收器的配置文件。通过观察文件可以发现，苹果的接收器不是一个真的红外接收器，它并不会把实际的信号给你，只是告诉你它识别到了什么，识别不到的就当不存在了。

```bash
sudo apt install lirc
sudo systemctl enable lircd
irdb-get update
irdb-get download apple/macmini.lircd.conf
sudo mv macmini.lircd.conf /etc/lirc/lircd.conf.d/
```

重启服务，尝试检测遥控器。在执行下面的命令后对着按遥控器，如果输出了按键就成功了。

```bash
sudo systemctl restart lircd
irw /var/run/lirc/lircd
```

## 配置遥控器操作

编辑下面的文件，写入配置。这个文件的结构很简单，可以参照 lirc 的帮助文档阅读。这个文件是给 mplayer 读的。

```bash
nano ~/.lircrc
```

```bash
begin
    button = KEY_VOLUMEUP
    prog = mplayer
    config = volume 1
    repeat = 1
end

begin
    button = KEY_VOLUMEDOWN
    prog = mplayer
    config = volume -1
    repeat = 1
end

begin
    button = KEY_FORWARD
    prog = mplayer
    config = seek_chapter 1
end

begin
    button = KEY_REWIND
    prog = mplayer
    config = seek_chapter -1
end

begin
    button = KEY_PLAY
    prog = mplayer
    config = pause
end

begin
    button = KEY_MENU
    prog = mplayer
    config = quit
    ignore_first_events = 10
end
```

在另一个命令行窗口中打开 mplayer 调试。用遥控器按键看有没有反应。不出意外应该就已经可以用了。

## 配置后台启动

现在虽然已经可以遥控了，但是还得我们先自己把 mplayer 打开，就非常的麻烦。所以接下来我们来让它自动打开。

新建一个脚本文件，我的文件放在 `～/scripts/irexec_mplayer_run.sh` 这里。

```bash
#!/usr/bin/env bash

echo "Start Playing audio CD.";
mplayer_processes=$(pgrep mplayer 2>/dev/null)

if [[ -z "$mplayer_processes" ]]; then
  mplayer -ao pulse cdda://
fi
```

这个脚本的内容是在检测 mplayer 是否已经运行，如果没有则运行。

接下来编辑 `/etc/lirc/irexec.lircrc`，将其中全部内容删除，改为下面的内容。这个文件是给 irexec 读的，它和上面准备的给 mplayer 读的文件不冲突，绑定到同一按键上的操作会同时执行。

```bash
begin
    button = KEY_PLAY
    prog = irexec
    config = /home/megabits/scripts/irexec_mplayer_run.sh
end

begin
    button = KEY_MENU
    prog = irexec
    config = eject
    ignore_first_events = 10
end
```

接下来我们要将 irexec 的服务调整为用户所有。这主要是因为声卡驱动是在用户权限下执行的。先把服务停止，然后移动文件位置。

```bash
sudo systemctl stop irexec.service
sudo systemctl disable irexec.service
sudo mv /lib/systemd/system/irexec.service /lib/systemd/user/
```

在对应的位置加入或修改为下面的内容：

```bash
[Unit]
...
After=pulseaudio.service
Wants=pulseaudio.service
[Service]
...
Environment="XDG_RUNTIME_DIR=/run/user/1000"
Environment="PULSE_RUNTIME_PATH=/run/user/1000/pulse/"
[Install]
WantedBy=default.target
```

以用户权限启动服务并允许其在开机后自动恢复运行。

```bash
loginctl enable-linger $(whoami)
sudo systemctl daemon-reload
systemctl --user enable irexec.service
systemctl --user start irexec.service
```

接下来应该就可以正常使用了。

## 参考资料

[LIRC: linux infrared remote control - Dan's Cheat Sheets](https://cheat.readthedocs.io/en/latest/lirc.html#why-is-this-so-hard)

[LIRCによるMplayerの操作+ALSA設定 - Ficusonline Forum](https://forum.ficusonline.com/t/lirc-mplayer-alsa/70)

[Welcome to the LIRC 0.10.0rc1 Manual - LIRC](https://www.lirc.org/html/index.html)

[LIRC Configuration - Zorin Forum](https://forum.zorin.com/t/lirc-configuration/8829)

