# Debian 安装 macOS Sonoma KVM 虚拟机

我配置这个虚拟机主要是用于持续集成，对图形性能之类的毫无要求。KVM 已经非常的好用了。整个过程基本上看 OSX-KVM 的 Readme 就能弄出来，但是他写的东一块西一块的。本文希望可以防止大家踩坑。同时，本教程针对的是在图形界面的 virt-manager 中进行管理的安装方式，和 OSX-KVM 默认的从命令行直接启动方式不同，这一点请大家注意。

## 安装 KVM

首先安装 KVM 相关组件。

```bash
sudo apt install virt-manager qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils libguestfs-tools genisoimage virtinst libosinfo-bin
```

加用户组。

```bash
sudo adduser $(whoami) libvirt
sudo adduser $(whoami) libvirt-qemu
```

启动 KVM 的网络服务
```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

## 准备安装镜像

将 OSX-KVM 下载下来。

```bash
git clone https://github.com/kholia/OSX-KVM.git
cd OSX-KVM
```

将其提供的 OpenCore 启动镜像（用于引导）复制到 libvirt 的目录里。虽然也可以把镜像换成自己下载的最新版，但是因为它提供的这个版本会默认以详细模式启动，有助于检查问题，所以暂时用他的。

```bash
sudo cp OpenCore/OpenCore.qcow2 /var/lib/libvirt/images/
```

然后我们还要将启动 macOS 需要的固件也拷贝过去。

```bash
sudo cp OVMF_CODE.fd /var/lib/libvirt/images/
sudo cp OVMF_VARS.fd /var/lib/libvirt/images/
```

接下来我们要准备安装镜像。这里要分成你是在已有的 macOS 上准备还是在 Linux 上准备。安装方法也会略有不同，在后面我会具体说明。这里推荐在 macOS 上准备，比较省心。

### 在 macOS 上准备

这里推荐大家使用 [Mist](https://github.com/ninxsoft/Mist) 工具下载安装镜像，下载时请选择 .app 格式保存。

接下来我们使用 macOS 提供的工具来创建空 DMG 文件并挂载。

```bash
hdiutil create -o "Sonoma-full.dmg" -size 15g -layout GPTSPUD -fs HFS+J
hdiutil attach -noverify -mountpoint /Volumes/install_build "Sonoma-full.dmg"

```

使用 macOS 安装程序提供的工具来制作启动盘。

```bash
sudo "Install macOS Sonoma.app/Contents/Resources/createinstallmedia" --volume /Volumes/install_build
```

弹出做好的安装盘。

```bash
hdiutil detach "/Volumes/Install macOS Sonoma"
```

把 DMG 格式转换成 KVM 可以使用的格式。有这一个文件就好。

```bash
hdiutil convert Sonoma-full.dmg -format UDRW -o Sonoma-full.img
```

### 在 Linux 上准备

首先要加装 genisoimage 和 dmg2img。

```bash
sudo apt-get install genisoimage dmg2img
```

从 [Mr. Macintosh](https://mrmacintosh.com/macos-ventura-13-full-installer-database-download-directly-from-apple/) 下载安装包放在 OSX-KVM 的目录下。

执行下面的命令来把安装镜像转换成 ISO 格式，同时把 OSX-KVM 提供的安装脚本也放进去。

```bash
mkisofs -allow-limited-size -l -J -r -iso-level 3 -V InstallAssistant -o InstallAssistant.iso InstallAssistant.pkg scripts/run_offline.sh
```

然后还要下载用来开机的 Recovery 启动盘。使用 OSX-KVM 提供的脚本即可。脚本会下载一个 `BaseSystem.dmg`，我们需要将其转换为 img 以供虚拟机使用。

```
./fetch-macOS-v2.py
dmg2img -i BaseSystem.dmg BaseSystem.img
```

记得把产生的 `InstallAssistant.iso` 和 `BaseSystem.img` 两个文件都移动到 `/var/lib/libvirt/images/` 中。

## 配置虚拟机

首先安装模版。之后就可以在 virt-manager 中看到名为 macOS 的虚拟机了。

```bash
virsh --connect qemu:///system define macOS-libvirt-Catalina.xml
```

接下来打开 virt-manager 的设置允许 XML 编辑。双击打开 macOS 虚拟机，先不要开机，直接进到 XML 标签页来修改。

为了能让 Sonoma 正常开机，我们需要将文件中的两处 Penryn 修改为 Haswell-noTSX。老架构 Sonoma 不支持了。

在文件开头指定固件的部分，需要修改地址指向 `/var/lib/libvirt/images/`。

```xml
<loader readonly='yes' type='pflash'>/var/lib/libvirt/images/OVMF_CODE.fd</loader>
<nvram>/var/lib/libvirt/images/OVMF_VARS.fd</nvram>
```

删除含有 mac_hdd_ng 镜像的磁盘。也就是这一段：

```xml
<disk type='file' device='disk'>
    <driver name='qemu' type='qcow2' cache='writeback' io='threads'/>
    <source file='/home/CHANGEME/OSX-KVM/mac_hdd_ng.img'/>
    <target dev='sdb' bus='sata'/>
    <boot order='1'/>
    <address type='drive' controller='0' bus='0' target='0' unit='1'/>
</disk>
```

对于含有 OpenCore 镜像的硬盘，要将文件位置改成指向 `/var/lib/libvirt/images/OpenCore.qcow2`。

```xml
<driver name="qemu" type="qcow2" cache="writeback" io="threads"/>
<source file="/var/lib/libvirt/images/OpenCore.qcow2" index="2"/>
```

接下来就要分情况了。

### 在 macOS 上准备的安装盘

对于含有 `BaseSystem.img` 的硬盘，将其改为指向 `/var/lib/libvirt/images/Sonoma-full.img`。

```xml
<driver name="qemu" type="raw" cache="writeback"/>
<source file="/var/lib/libvirt/images/Sonoma-full.img">
```

### 在 Linux 上准备的安装盘

对于含有 `BaseSystem.img` 的镜像，将其改为指向 `/var/lib/libvirt/images/BaseSystem.img`。

```xml
<driver name="qemu" type="raw" cache="writeback"/>
<source file="/var/lib/libvirt/images/BaseSystem.img">
```

接下来点保存，如果语法正确的话，理论上不应该报错。

在左侧列表中创建一个磁盘，类型保持硬盘，选择 `InstallAssistant.iso`。在 xml 画面中确认磁盘的 type 属性是 raw，将 cache 属性改为 writeback。

最后两个系统都一样，在左侧列表中创建一个磁盘，用于当作虚拟机的系统盘。

## 安装虚拟机

开机，准备装系统。

### 在 macOS 上准备的安装盘

直接按正常流程安装即可。

### 在 Linux 上准备的安装盘

先分区。分区完成后打开终端（终端可以在顶上菜单里面打开）。在终端中运行打包进去的脚本。这个脚本会把安装程序拷贝到正确的位置然后执行。

```bash
sh /Volumes/InstallAssistant/run_offline.sh
```

之后正常完成安装即可。

安装完成后，可以关闭虚拟机，将用于安装的磁盘全部删除，注意别把 OpenCore 给删了。

## 顺带提一下 Windows

在 KVM 中安装 Windows 相比来讲简单多了，这里主要是讲两点。

首先驱动这里可以下载 [virtio-win](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/)。

然后为了能让共享文件夹正常工作，我们还要下载 [WinFSP](https://github.com/winfsp/winfsp/releases/)。安装之后将系统中的 VirtIO-FS Service 这个服务启用，然后改成自动。

## 从 macOS 远程管理虚拟机

要从另一台 macOS 上远程管理 KVM 虚拟机，可以用 brew 安装 virt-manager。

首先在 Linux 上打开远程管理，编辑 `/etc/libvirt/libvirtd.conf` 文件，写上这两行：

```bash
unix_sock_group = "libvirt"
unix_sock_rw_perms = "0770"
```

在 macOS 上安装。

```bash
brew tap jeffreywildman/homebrew-virt-manager
brew install virt-manager virt-viewer
```

之后就可以通过下面的命令来管理虚拟机了。注意 no-fork 参数不加会崩溃。

```bash
virt-manager --connect="qemu+ssh://USER@HOSTNAME/system?socket=/var/run/libvirt/libvirt-sock" --no-fork
```

但是如果你只做了上面这些事，你会发现一个问题就是远程桌面打不开。这是因为远程桌面默认不接受外部访问。所以我们需要编辑虚拟机，在左侧列表中选择 Display Spice，然后在右侧将 Address 改为 All Interfaces。这样应该就可以打开了。

但是还有另外一个问题，Spice 从局域网走的话很慢，不如 VNC。所以我们可以进入 XML 编辑界面，将所有与 Spice 相关的东西全部删除，注意只要有一样 Spice 的东西还留着，就没办法保存修改，就会报错。全删除之后在左侧列表里重新添加 VNC 类型的 Display 就可以了。别忘了改 All Interface。

以后再执行的时候就可以省略连接命令，直接在 GUI 里连接就好。

```bash
virt-manager --no-fork
```

## 结论

最后的结论就是。如果不是有什么大病，咱还是用 VMware 吧，折腾死了，有这时间干点啥不好。用 [VMware Unlocker](https://github.com/theJaxon/unlocker) 可以解锁安装 macOS 的功能。

## 参考资料

[OSX-KVM - GitHub](https://github.com/kholia/OSX-KVM/blob/master/notes.md)

[How to install KVM server on Debian 9/10 Headless Server - Nix Craft](https://www.cyberciti.biz/faq/install-kvm-server-debian-linux-9-headless-server/)

[Share Folder Between Windows Guest and Linux Host in KVM using virtiofs - Debug Point](https://www.debugpoint.com/kvm-share-folder-windows-guest/)

[Remote virt-manager from Mac OS - Gist](https://gist.github.com/davesilva/da709c6f6862d5e43ae9a86278f79188)
