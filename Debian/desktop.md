# 桌面环境备忘录

最近用 M1 Air 安装了 Asahi Linux，桌面主力从 Debian 转到了 Fedora。所以更新一下这篇文章。

从 FlatPak 安装：
- Extension Manager
- dconf Editor

接下来安装常用软件包。

- ibus-rime：中文输入法，同时安装东风破(plum)和雾凇拼音方案。
- ibus-mozc：日语输入法。
- vlc：路障。（或者 mpv）
- ghex：HEX 编辑器。
- meld：文件对比工具。
- gear-lever：App Image 管理工具。
- default-jdk：咖啡冒热气。
- wireshark：脆脆鲨。

  ```bash
  sudo usermod -a -G wireshark $(whoami)
  sudo chmod +x /usr/bin/dumpcap
  ```

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

关闭 Tap to Click。

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
