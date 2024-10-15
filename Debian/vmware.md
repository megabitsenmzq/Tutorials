# VMware 安装指南

## 下载

VMware 被博通收购之后下载变得极其难找。还好我们可以直接从 VMware 的更新服务器下：[VMware Downloads](https://softwareupdate.vmware.com/cds/vmw-desktop/)。

## 安装

首先安装软件本体，不管是 Workstation 还是 Player，流程都是一样的。

给安装文件执行权限，然后运行安装就可以了。

```sh
chmod +x VMware-Workstation-17.5.2-23775571.x86_64.bundle
sudo ./VMware-Workstation-17.5.2-23775571.x86_64.bundle
```

安装过程中会报错无法安装内核驱动，属于正常现象。这是因为 VMware 的官方内核驱动没支持最近几个 Linux 内核版本，大概是被弃坑了。这里我们需要安装一个第三方 Fork 的内核驱动。

### 安装内核驱动

使用此[教程](https://github.com/nan0desu/vmware-host-modules/wiki)中提供的方法进行安装，仓库地址在[GitHub](https://github.com/nan0desu/vmware-host-modules/)。可以看到仓库中给每一个 VMware 版本都做了一个分支。

针对最新版本 17，不管是 Workstation 还是 Player，安装步骤都是一样的。根据你的内核版本选择合适的分支。我这里使用的是 Debian Testing，目前是 6.10。

```sh
git clone -b workstation-17.5.2-k6.9+ https://github.com/nan0desu/vmware-host-modules.git
cd vmware-host-modules
apt-get install linux-headers-$(uname -r)
make
sudo make install
```

将编译好的驱动注册给 VMware。

```sh
make tarballs && sudo cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/ && sudo vmware-modconfig --console --install-all
```

最后使用 dkms 激活内核驱动。注意我下面的命令给分支加了 `origin` 标记，如果你没把分支 checkout 到本地的话，不这样写会报错。 

```sh
sudo apt install dkms
git rev-list origin/master..origin/dkms | git cherry-pick --no-commit --stdin
sudo dkms add .
```

之后 VMware 应该就可以打开了。

这里有一点要注意，在 VMware Tools 安装之前，打开图形加速会导致虚拟机没有画面。所以需要先关闭图形加速，安装完系统和 VMware Tools 之后再次打开。这个问题目前无解，只能等修。

不知道 VMware Workstation 以后还会不会给 Linux 好好提供后续支持，希望别等什么时候就彻底弃坑了。

## 屏幕缩放

Mac 用户大概知道 VMware Fusion 是有一个使用 Retina 原生分辨率还是缩放分辨率的选项的，这一选项在 Linux 中并不存在。但是我们可以通过一些设置达到类似的效果，否则一些老系统在 4K 的屏幕上真的完全没法看。

打开 `preferences.ini` 文件，其在 Linux 上存在于 `~/.vmware` 目录中，如果安装的是 Player，可在文件中添加如下内容：

```
pref.autoFit = "TRUE"
pref.autoFitGuestToWindow = "FALSE"
pref.autoFitFullScreen = "stretchGuestToHost"
```

如果安装的是 WorkStation，则可直接在偏好设置中修改。将“主机分辨率跟随虚拟机”关闭，“虚拟机分辨率跟随主机”打开（或者关闭也行），将全屏分辨率选项设置为拉伸。之后只要把虚拟机的分辨率设置成 1080p 即可。但要注意放大效果只会在全屏状态生效。

鉴于目前 WorkStation 对个人也免费了，说实话我觉得没什么只用 Player 的必要。
