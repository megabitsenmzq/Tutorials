# 2024 我对我的 Mac mini 做了什么

最近我一连更新了几篇文章，关于对我的 Mac mini 2014 的 Debian 改造。大头都写完了之后我准备写一篇文章把这些东西都串起来，让大家对这次改造有一个整体的认识，也算是我自己的备忘。

这台 Mac mini 2014 是我的第一台 Mac。我的 App PomoNow 的第一版是在这个机器上开发的，这台电脑的键盘我直到现在都还在使用。在有了新电脑之后，我也尽可能的利用这台电脑，把它拿来当作家里的服务器，给我提供各种文件备份和共享服务。而我也一直在上面运行 OS X。

继续用 OS X 做服务器的原因非常简单，文件共享可以直接在偏好设置里开，对我的需求来讲非常的省心。我差不多就是用这 Mac 当 NAS 用。而且还可以用于 CI/CD。当时我还在用 Xcode Server。

比较有趣的是，这台 Mac mini 是苹果最后一款可以同时安装 SSD 和 HDD 的型号。这台机器是只有 HDD，8G 内存的机型，但是主板上却保留了 SSD 的接口。虽然是苹果自己的特殊接口，但是华强北早就给我们解决了。所以我来日本之后就给这个机器加了 NVME SSD。然后 HDD 现在也是 2T 的了。

之后 OS X 变成了 macOS，苹果也终于把这台机器 Drop 了。但没过多久，OpenCore Legacy Patcher 被搞出来了，所以我就继续在这台机器上运行最新的 macOS。追求最新的 macOS 主要有两个原因，一个是 CI/CD 必须得支持最新的 Xcode，另外一个是公开到公网上的服务不更新可能会有 0day。

直到最近，这台电脑越来越不正常了。不知道是旧的驱动和 Sonoma 合不来还是怎样，显卡驱动经常会崩溃，然后会顺带让 Window Server 卡死 CPU 100%。一大早听见那个声音还感觉电表要倒转了。尤其在元旦附近这种现象发生越来越频繁了。为了彻底解决这个问题我终于决定把 macOS 刷成 Linux，然后把 macOS 关进虚拟机，让其自生自灭。

接下来我就按整个流程的顺序详细讲一下我都做了什么。

## 安装系统

因为是做服务器平时不会碰，所以我完全没有安装图形环境。就是纯命令行的非常干净的 Debian。之所以选择 Debian 一方面是我对 Debian 系比较熟悉，我的主力 Linux 电脑也是 Debian。另外也是出了问题教程好找，就算找不到 Debian 的，Ubuntu 的也能凑活用。剩下就没什么特别大的原因了。

安装时候配置了用了 Btrfs，参见文章：[Debian 使用 Btrfs 文件系统实现快照和恢复](btrfs.md)。

我将 HDD 挂载到了 `/mnt/Documents` 也是 Btrfs。

## 安装 Wi-Fi 驱动

这台机器距离路由器很远，不好拉线，所以我还是走无线网络了。无线网卡的驱动一般不是自由软件，所以要把非自由软件源打开，然后自己装。

```bash
sudo apt install broadcom-sta-dkms network-manager
```

然后进 `nmtui` 连 Wifi 就可以了。

## File Browser

[File Browser](https://filebrowser.org) 是一个轻量的文件管理 Web UI，功能刚好够用，我非常推荐。可以直接装也可以在 Docker 里装。需要的朋友可以自己去官网看看。

因为要让这个东西开机启动，要写一个 systemd 服务。服务一般都放在 `/etc/systemd/system/` 中。注意这里要写好用户，因为我们不希望有人用 root 权限乱改东西，也不希望以 root 权限创建文件别的程序无法访问。

```bash
[Unit]
Description=File Browser Service
After=network.target

[Service]
User=user
Group=group
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=filebrowser

[Install]
WantedBy=multi-user.target
```

之后用 systemctl 启动就可以了。

这里讲个题外话。systemd 真的是比 launchd 好用太多了。macOS 的 launchd 甚至都没办法直接看到日志，必须要指定一个输出文件才行。

## frp

frp 是一个很好用的内网穿透工具。用于把部分服务公开到外网。我以前是用 ngrok 的，但是 ngrok 的配置十分麻烦。不但需要自己生成证书，自己编译二进制，证书过期了还得重来。只是当年 frp 的连接非常不稳定动不动就断我才没有采用。过了这几年 frp 取得了长足的进步，现在也没什么大问题了，所以我已经全面转向使用 frp。

配置 frp 非常简单只需要下载对应的二进制，写好配置文件执行即可。只是有一点要注意，官方文档给出的 systemd 服务是不会在遇到故障的时候自动重启的，于是我做了一些修改。

```bash
[Unit]
Description=frp client
After=network.target syslog.target
Wants=network.target
StartLimitIntervalSec=30
StartLimitBurst=2

[Service]
Type=simple
ExecStart=/home/megabits/frp/frpc -c /home/megabits/frp/frpc.toml
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

## Tailscale

同时为了那些并不想要暴露到外网的服务，我使用 [Tailscale](https://tailscale.com) 来访问。其安装也可以直接参考官网即可，实在是简单的不行。只是不要忘了启用它的服务。

```bash
sudo systemctl enable --now tailscaled
```

## Syncthing

[Syncthing](https://syncthing.net) 是一个同步文件的工具。我用它来实现类似云盘的同步功能，配合 File Browser，我的 Mac mini 可以完全替代云盘。因为 Debian 自带的版本比较老，建议按照[说明](https://apt.syncthing.net)添加官方源。

安装完成后以用户态启动服务，之后可以通过 8384 端口访问 WebUI。

```bash
sudo systemctl enable --now syncthing@$(whoami)
syncthing --paths // 找到配置文件。
```

此外因为 Syncthing 是开源软件，公共节点都是志愿者提供的，所以在穿透内网的情况下速度较慢，可以自己搭建中继。

安装方法和前面一样从官方源安装。

```bash
sudo apt install syncthing-relaysrv
```

之后先编辑 `/etc/default/syncthing-relaysrv` 添加 token 参参数, 关闭内网发现，然后再启动服务。

```bash
NAT=false
RELAYSRV_OPTS=-token=myToken
```

```bash
sudo systemctl start --now strelaysrv
sudo systemctl status strelaysrv
```

在日志中可以看到访问的 URI。在所有参数最后添加 Token 即可填入设置，替换 ListenAddress 默认的 default。

```
relay://0.0.0.0:22067/?id=AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-AAAAAAA-
AAAAAAA-AAAAAAA&networkTimeout=2m0s&pingInterval=1m0s&statusAddr=%3A22070&token=myToken
```

## 自动备份

对于同步的重要文件，我还会对其进行定期云备份。

我在 Oracle Cloud 有注册一个免费的 VPS，并配置了 100GB 的存储块。比较有趣的是，如果我想在 Oracle Cloud 上获得同样容量的对象存储需要花钱，存储块却不用。

于是我在 VPS 中也安装了 Resilio Sync，然后用一个备份专用的文件夹加密同步。再通过计划任务将需要备份的文件打包存入这个文件夹。即实现了一个虽然原始但十分有效的备份逻辑。脚本如下：

```bash
#!/bin/bash

date_string=$(date +'%Y-%m-%d_%H-%M-%S')

tar --absolute-names --exclude .sync -zcf /mnt/Documents/Backups/Archive/Developer_$date_string.tar.gz /mnt/Documents/Files/Developer
chmod g+rw /mnt/Documents/Backups/Archive/Developer_$date_string.tar.gz
chown megabits:megabits /mnt/Documents/Backups/Archive/Developer_$date_string.tar.gz
backup_files_dev=($(ls -tr "/mnt/Documents/Backups/Archive/Developer_"*.tar.gz))

if [[ ${#backup_files_dev[@]} -gt 7 ]]; then
  num_files_to_delete=$(( ${#backup_files_dev[@]} - 7 ))
  files_to_delete=("${backup_files_dev[@]:0:$num_files_to_delete}")
  rm "${files_to_delete[@]}"
fi
```

这里做了三件事，一个是用 tar 打包保存，保存时排除了 Resilio Sync 的索引文件。之后设置权限确保 Resilio Sync 可以读。最后再检查文件夹中超过一周的文件并删除。我只保留最近一周的备份。

脚本写完后用 systemd timer 触发。一样放在 `/etc/systemd/system/` 中首先是 timer 文件：

```bash
[Unit]
Description=Run every day

[Timer]
OnCalendar=*-*-* 05:00:00

[Install]
WantedBy=timers.target
```

然后是 service 文件：

```bash
[Unit]
Description=Daily Archive
[Service]
ExecStart=/home/megabits/scripts/daily_archive.sh
```

这里可以看到这个脚本会在每天凌晨五点执行。之后一样在 systemctl 中启用可以了。注意启用时只要启用 timer 即可，不必对 service 进行操作。

## 自动手机备份

备份使用 libimobiledevice 来实现，参见文章：[Debian 使用 libimobiledevice 实现苹果设备无线备份](libimobiledevice.md)。

之后用类似的思路配置 systemd timer 即可。

## 文件共享

文件共享使用 Samba 和 Netatalk 来实现，其中 Netatalk 是用于支持苹果的 AFP 共享协议的。可以支持诸如 Time Machine 备份等功能。而且因为 AFP 的速度要比 Samba 快好多倍，是一定要搞的。

至于为什么速度差这么多，这很可能是苹果的问题。在支持 M1 的 macOS 发布之后，苹果更新的 samba 驱动就有非常严重的性能问题。参见这一篇文章：[M1登場以降 macOSのSMB実装がずっとやらかしている件](https://www.note.lespace.co.jp/n/n53b8d7135039)。

不过我们首先来配置 Samba。基本上按网上讲的做就可以。如果要让 Samba 共享的设备名称不要显示成全大写，可以在配置文件的全局设置中加入 `mdns name = mdns`。另外不要忘了设置 Samba 用户的密码：`sudo smbpasswd -a megabits`。

Netatalk 在 debian 上的配置较为麻烦。主要是因为这个包不在 stable 源中，所以我们要先在系统中添加不稳定源。打开 `/etc/apt/sources.list`。添加：

```bash
# Unstable
deb http://deb.debian.org/debian/ unstable main
deb-src http://deb.debian.org/debian/ unstable main
```

为了防止 apt 使用不稳定源更新仓库导致系统变得不稳定（笑），我们还要调整 apt 的设置。编辑 `/etc/apt/preferences.d/default-release` 改为：

```bash
Package: *
Pin: release o=Debian,a=unstable
Pin-Priority: 10
```

Netatalk 的配置文件不像 Samba 那么好找，这里我写一下：

```bash
[Global]
log level = default:warn
log file = /var/log/afpd.log
zeroconf = yes
hostname = Home-Server
save password = yes
valid users = megabits

[Files]
path = /mnt/Documents/Files
...
```

## KVM

之后我通过 KVM 安装了 macOS 和 Windows 的虚拟机，过程参见文章：[Debian 安装 macOS Sonoma KVM 虚拟机](osx-kvm.md)。

## CD 播放

因为电脑上插了一个光驱，我还配置了 CD 播放器，可以用苹果的遥控器遥控，过程参见文章：[在 Debian 上使用 Mac mini 的红外接收器控制 CD 播放](cd-player.md)。

## Cockpit

[Cockpit](https://cockpit-project.org) 是一个 RedHat 做的轻量服务器管理面板。基本上照着官网的装就可以了。我多装了两个插件。

```bash
sudo apt install cockpit-pcp cockpit-machines
```

## Aria2

这里的配置大同小异，需要的话可以直接参照文件夹: [aria2](https://github.com/megabitsenmzq/Tutorials/tree/master/Debian/aria2)。

## Caddy

接下来安装了 [Caddy](https://caddyserver.com) 用来改善 WebUI 的体验，顺便跑 [AriaNG](https://github.com/mayswind/AriaNg)。

我这里踩了一个坑，就是 Caddy 的静态服务器似乎无论如何都读不到用户目录的文件。即便我确认了文件的访问权限是没有问题的。最后我在 `/etc/caddy` 中创建了一个 `www` 文件夹，把东西放在里面。

我的 Caddyfile 大致内容如下：

```bash
:8003 {
	root * /etc/caddy/www
	log
	encode gzip
	file_server browse
}

:80 {
	redir https://{host}{uri} permanent
}
```

## 总结

整个过程我折腾了一周左右，正好赶上元旦放假。虽然花了很多时间，但过程中也学到了很多东西，我对 Linux 系统的认识又进了一步。很多以前靠我自己可能解决不了的东西这次也能在不 Google 的前提下依靠自己的经验解决了。总的来说还是很顺利的，没碰到特别大的坑。

另外我还有一台安装了 Debian 的 MBP，有一些需要调整的地方也做了[笔记](desktop.md)。
