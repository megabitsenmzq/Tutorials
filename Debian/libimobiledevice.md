# Debian 使用 libimobiledevice 实现苹果设备无线备份

我个人对 iCloud 是零信任的，因为以前出过很大问题。所以我自然也不会信任 iCloud 的设备备份。在 macOS 或 Windows 上我们可以使用 iMazing 来做备份，虽然这东西要钱而且越来越贵了。而在 Linux 上，我们可以使用 libimobiledevice 来备份。这篇文章主要聚焦于无线备份，如不需要无线备份则可直接从 apt 安装 libimobiledevice 并参照下面的备份命令即可。

但是 libimobiledevice 并不完美，在 Windows 和 macOS 上，它可以正常通过无线方式连接到设备，但在 Linux 上则不工作。其原因在于使用的 usbmuxd 不支持这一功能。于是有人从头重写开发了 usbmuxd2，可以直接替换 usbmuxd 使用。

## 编译基本组件

因为 Debian 的包比较老，我们需要从头编译很多东西。总之先来装依赖吧。

```bash
sudo apt install git build-essential autoconf automake libtool-bin pkg-config clang libssl-dev  libcurl4-openssl-dev avahi-utils
```

然后把这五个包的源代码下载下来。

```bash
git clone https://github.com/libimobiledevice/libplist.git 
git clone https://github.com/libimobiledevice/libimobiledevice-glue.git
git clone https://github.com/tihmstar/libgeneral.git
git clone https://github.com/libimobiledevice/libtatsu
git clone https://github.com/libimobiledevice/libimobiledevice.git
```

其中 libplist 用于读取苹果的 plist 格式。libimobiledevice-glue 和 libgeneral 都是 libimobiledevice 中的工具依赖的公共代码。

之后依次进入文件夹编译

```bash
./autogen.sh 
make 
sudo make install
sudo ldconfig
```

## 配置 Avahi

Avahi 是用来做局域网发现的，用它可以找到网络中的 bonjour 设备。按如下所示修改配置文件 `/etc/avahi/avahi-daemon.conf`。

```bash
domain-name=local # 这一行去掉注释
publish-hinfo=yes # 默认是 no
publish-workstation=yes # 默认是 no
```

再启动服务。

```bash
sudo systemctl enable --now avahi-daemon.service
```

另外虽然说咱们都已经在用 ssh 登陆了，这方面应该没问题，不过还是注意下需要装 ssh 服务器。

```bash
sudo apt-get install openssh-server 
sudo systemctl enable --now ssh.service
```

下面的命令可以显示当前网络中扫描到的设备：

```bash
avahi-browse -a
```

然后这里还可能要删除一个不太需要的后台服务，它会一直在系统日志里报错，很烦。

```bash
sudo apt remove --purge avahi-autoipd
```

## 编译 usbmuxd2

这个作者写的代码只能用 clang 编，所以需要多一步。编译前需要打开文件 `usbmuxd2/Muxer.cpp` 加入 `#include <algorithm>`，这是目前版本的一个 bug，之后可能会修复。

```bash
https://github.com/tihmstar/usbmuxd2.git
./autogen.sh 
./configure CC=clang CXX=clang++
make
sudo make install
sudo ldconfig
```

启动服务，之后可能要重启一下电脑才能读到设备。

```bash
sudo systemctl start usbmuxd
```

## 尝试连接

先将 iOS 设备用 USB 线接到电脑上，在设备上输入密码信赖电脑。然后执行 `idevice_id` 查看设备列表，可能会看到这样的结果：

```bash
00008030-000572092A30802E (USB)
00008030-000572092A30802E (Network)
```

如果其中包含 Network 则表示成功。你还可以使用 `ideviceinfo` 命令查看设备信息，应该会输出一大堆东西。

## 尝试备份

备份的命令非常简单，如果只配对这一个设备，也可以不具体指定。我的命令中还指定了搜索网络设备。执行后就会立即开始备份。

```bash
idevicebackup2 backup --full --network --udid 00008030-000572092A30802E backup_folder
```

idevicebackup2 还有很多的的选项，具体可以参见官方文档。

## 小技巧

在备份文件夹中使用 `plistutil -p Status.plist` 来打印这个状态文件，来获得诸如备份时间之类的信息。

定时备份可以创建 systemd timer 来实现，但要注意局域网备份只有在手机解锁的状态下才有效。锁屏的时候是找不到设备的。

## 参考资料

[Untether iOS – Step by Step - Numerous Networks](https://www.numerousnetworks.co.uk/guides/untether-ios-step-by-step/)

[Raspberry PiでAltServerを動かす - さおとめらいふ](https://jun3010.me/raspberrypi-altserver.html)

[Automatically backup the iPhone to the Raspberry-Pi - VALINET](https://valinet.ro/2021/01/20/Automatically-backup-the-iPhone-to-the-Raspberry-Pi.html)
