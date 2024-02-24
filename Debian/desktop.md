# Debian 桌面环境笔记

之前我写文章介绍了我的 Debian 服务器配置。此外我还有一台装了 Debian 的 MBP。这里整理一下这台 MBP 安装时的要点作为自己的笔记，说明会比较随便。

## 硬件驱动

参见：[State of Linux on the MacBook Pro 2016 & 2017](https://github.com/Dunedan/mbp-2016-linux)。

不过主要来讲就是一个[声卡](https://github.com/davidjo/snd_hda_macbookpro)，一个[蓝牙](https://github.com/leifliddy/macbook12-bluetooth-driver)。声卡半残，休眠就废。蓝牙倒是没什么大问题。

## 软件包

- flatpak：不用多说，安装参见[官网说明](https://flatpak.org/setup/Debian)。
- zram-tools：压缩内存替代部分 Swap，得到更好的内存性能。
- ibus-rime：中文输入法，同时安装东风破(plum)和雾凇拼音方案。
- ibus-mozc：日语输入法。
- gnome-shell-extension-manager：Gnome 插件管理器。
- vlc：路障。
- ghex：HEX 编辑器。
- meld：文件对比工具。

## Gnome 插件

- Clipboard Indicator：剪贴板管理器。

- Dash to Dock：快捷启动当 Dock 用。

- Blur my Shell：各种界面模糊。

- AppIndicator and KStatusNotifierItem Support：传统通知图标支持。

- Just Perfection：界面微调。

- Burn My Windows：窗口开关特效。

- Focused Window D-Bus：给其他程序提供接口。

- TailScale-QS：TailScale 开关。

## 美化

[Fluent-icon-theme](https://github.com/vinceliuice/Fluent-icon-theme)

## 防精分

[Toshy](https://github.com/RedBearAK/toshy): 在 Linux 上使用 macOS 的快捷键。

### 修改手势

Gnome 默认的打开 Launcher 的手势是三指，但是 macOS 上四指五指都是有反应的，我自己平时是用四指，所以这里也要改一下。

先备份原文件。

```bash
cp /usr/lib/gnome-shell/libshell-12.so /usr/lib/gnome-shell/libshell-12.so.bak
```

然后用 HEX 编辑器比如 imhex 打开。搜索 `GESTURE_FINGER_COUNT=3` 改成 4 就可以了。

## 调整电源行为

苹果的机器上 Debian 休眠不太好使，我直接禁用了所有自动休眠，然后把合盖休眠也去掉了。

```bash
sudo nano /etc/systemd/logind.conf
```

## 固件参数调整

用 macOS 安装盘进恢复模式。

### 关闭启动声音。

```bash
nvram StartupMute=%01
```

### 限制充电

限制充电到 80% 可以保护电池。

先打开 Safari 从 github 下载 [bclm](https://github.com/zackelia/bclm)。下载完应该会自动解压。

回到命令行

```bash
./bclm write 80
./bclm persist
```

## 调整滚动速度

### 调整全局触摸板速度

Gnome 可以直接调整的触摸板速度是有极限的。剩下的就得直接改参数了。参阅：[Adjust Touchpad Scrolling Speed in Ubuntu 22.04 | 23.04 GNOME Wayland](https://ubuntuhandbook.org/index.php/2023/05/adjust-touchpad-scrolling-ubuntu/)。

先随便写一个尺寸让他吐出真的尺寸来，之后直接退出就可以。找到 Kernel specified touchpad size 记下来。

```bash
sudo libinput measure touchpad-size 100x100
```

用刚刚记下来的尺寸乘放大比例，算出一个数字写上去。

```bash
sudo libinput measure touchpad-size 45x28
```

按指示把触控板摸一遍，然后退出。按指示把输出粘贴到 `/etc/udev/hwdb.d/60-evdev-local.hwdb` 中。

```bash
sudo systemd-hwdb update
sudo udevadm trigger /dev/input/event*
```

最后重启生效。

### 调整 Firefox

Firefox 很多东西都得单独调，似乎和 Wayland 不是很对付。

从地址栏进入 `about:config`，搜索 `mousewheel.default.delta_multiplier_y` 改成需要的数字即可。

## 删除桌面文件夹

桌面在 Gnome 里没有意义，但是不能直接删掉。

需要先在 `.config` 里面建立一个假的 Desktop 文件夹。然后在 `.config/user-dirs.dirs` 里修改使其指向刚刚创建的假文件夹。然后把真的 Desktop 删掉眼不见心不烦。

需要整理的东西大概就是这么多。
