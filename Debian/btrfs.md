# Debian 使用 Btrfs 文件系统实现快照和恢复

我们大家都用过虚拟机，虚拟机可以打快照，弄坏了就可以回档。但这件事在真机上并不好实现。在 Linux 中我们可以借助 Btrfs 做到这一点。Btrfs 在文件系统中集成了快照功能，但由于手动创建和恢复比较麻烦，所以需要一些工具配合。

最常见的工具是 Snapper，但由于 Snapper 是为 OpenSUSE 设计的，并没有考虑其他发行版的情况，所以在 Debian 上需要手动做一些事。假如你的 Debian 安装了桌面环境，我这里比较推荐使用 Btrfs Assistant。基本上是装好了开箱即用的。但遇到无法进入桌面环境的情况就会很尴尬了。所以如果你想要更加的安全，我还是建议从头配置 Snapper，之后再来安装图形界面的管理工具。

## 分区

在安装 Debian 时使用专家安装，如果你是第一次碰专家安装，建议网上找找安装过程的视频先看一遍避免出错。使用专家安装的目的是为了能够在每个步骤之后停下。

分区时首先创建一个 500M 左右的 `EFI` 分区，这部分没什么特别的。接下来你有两个选择：

1. 使用全盘加密。在加密分区外创建一个 1G 左右的 `boot` 分区，再创建加密分区，在加密分区中创建 `/` 和 `swap`。
2. 不使用全盘加密，直接创建 `/` 和 `swap`。

不管选哪个，都要记得创建 Btrfs 格式的分区。然后不必在 Btrfs 中创建除了 `/` 之外的分区。我们可以之后再创建。

在分区完成后，不要着急安装。此时按下 `Crtl+Alt+F3` 等切换到其他的有命令行的 TTY。

## 重建子分区

首先用 `df -h` 查看一下现在挂载的磁盘。你会看到类似下面的列表：

```bash
Filesystem      Size  Used Avail Use% Mounted on
...
/dev/nvme0n1p3  231G   62G  168G  27% /target
/dev/nvme0n1p1  285M  5.9M  279M   3% /target/boot/efi
```

这其中我们可以看到 Debian 安装程序将目标磁盘挂载到了 `/target` 下。我这里没有使用加密，如果使用了加密分区，则左侧的 `/dev/nvme0n1p3` 会变成 `/dev/mapper/VG0-LV0` 之类的东西。

为了对其进行修改，我们要先把子分区都卸载，然后把整个分区的根挂载出来。

```bash
umount /target/boot/efi
umount /target
mount /dev/nvme0n1p3 /mnt 
```

这时如果我们来看 `/mnt` 的内容，就会看到一个：

```bash
@rootfs
```

这个 `@rootfs` 就是我们的各种麻烦事的万恶之源了。我们将它重命名为 `@`。

```bash
mv @rootfs @
``` 

接下来创建一个专门用于存放 Snapper 快照的子分区。

```bash
btrfs subvolume create @snapshots
```

也可以简写为

```bash
btrfs su cr @snapshots
```

你也可以创建一些其他你想要分别管理的子分区。不过越多一会越麻烦。

```bash
btrfs su cr @home
btrfs su cr @log
btrfs su cr @cache
btrfs su cr @crash
btrfs su cr @tmp
btrfs su cr @spool
...
```

接下来我们要把刚刚创建的子分区一个一个挂载上。注意这里 efi 在不同的分区上，`@snapshots` 要挂载到 `.snapshots` 文件夹上。

```bash
mount /dev/nvme0n1p1 /target/boot/efi
mount -o rw,noatime,compress=zstd,subvol=@ /dev/nvme0n1p3 /target
mount -o rw,noatime,compress=zstd,subvol=@snapshots /dev/nvme0n1p3 /target/.snapshots
mount -o rw,noatime,compress=zstd,subvol=@home /dev/nvme0n1p3 /target/home
...
```

之后我们还要修改 `/target/etc/fstab` 来让系统记住这些子分区。

在文件的上方，我们会找到这样一行：

```bash
UUID=0bd3d1d3-6814-4703-8796-c200c2f07552 / btrfs subvol=@rootfs 0 0
```

我们要把这一行的参数修改成我们刚刚挂载使用的参数，之后有多少子分区就写多少行。

```bash
UUID=0bd3d1d3-6814-4703-8796-c200c2f07552 / btrfs rw,noatime,compress=zstd,subvol=@ 0 0
UUID=0bd3d1d3-6814-4703-8796-c200c2f07552 /.snapshots btrfs rw,noatime,compress=zstd,subvol=@snapshots 0 0
UUID=0bd3d1d3-6814-4703-8796-c200c2f07552 /home btrfs rw,noatime,compress=zstd,subvol=@home 0 0
...
```

保存，回到安装用的 TTY 完成剩下的安装步骤。

## 配置 Snapper

首先安装 Snapper。

```bash
sudo apt install snapper
```

为了防止 Snapper 自动创建的快照干扰我们工作，先给他处理掉。

```bash
cd /
sudo umount .snapshots
sudo rm -r .snapshots
```

接下来让 Snapper 接管根目录。注意这里的根是指子分区中的 @，不是磁盘上真正的根。

```bash
sudo snapper -c root create-config /
```

然后我们来做一些配置，大家可以按需调整。

```bash
sudo systemctl disable snapper-boot.timer # 禁用开机快照
sudo snapper -c root set-config 'TIMELINE_CREATE=no' # 禁用定时快照（可选）
sudo nano /etc/snapper/configs/root # 可以调整定时快照的选项
sudo nano /lib/systemd/system/snapper-timeline.timer # 调整定时快照的清理周期
sudo snapper -c root set-config 'ALLOW_GROUPS=sudo' # 免 sudo 使用
sudo snapper -c root set-config 'SYNC_ACL=yes' # 精确保存文件权限
sudo nano /etc/apt/apt.conf.d/80snapper # 调整是否在 apt 执行时快照
```

接下来你可以继续让 Snapper 接管每一个子分区。

```bash
sudo snapper -c root create-config /home
···
```

最后再重新把保存快照的子分区挂载上。

```bash
sudo btrfs su del /.snapshots
sudo mkdir .snapshots
sudo mount -av
```

接下来我们就可以自由的创建快照了。

## 快照管理

创建快照非常简单。如果你的系统中只有一个 `@` 子分区需要管理，`-c root` 还可以省略。

```bash
sudo snapper --config root create --description "Aha!"
```

或简写为：

```bash
sudo snapper -c root cr -d "Aha!"
```

来看看我们创建的快照。

```
  # | Type   | Pre # | Date                     | User     | Cleanup | Description | Userdata
----+--------+-------+--------------------------+----------+---------+----------------------+---------
 0  | single |       | Sat Jan  6 17:02:13 2024 | root     |         | Aha!        |
```

删除快照也十分简单。

```bash
sudo snapper -c root del 0
```

麻烦的是回档。

## 恢复快照

虽然我们可以直接使用 Snapper 恢复快照，但这个过程一点都不让人省心。与其说是帮你恢复快照，Snapper 不如说是给你创建了一个目标快照的可读写副本，至于进入快照还有把那个副本替换成真的快照之类的麻烦事就得自己干了。所以我们需要使用一个脚本。

```bash
sudo apt install python3-btrfsutil
git clone 'https://github.com/jrabinow/snapper-rollback.git'
cd snapper-rollback
sudo cp snapper-rollback.py /usr/local/sbin/snapper-rollback
sudo cp snapper-rollback.conf /etc/
```

然后我们需要编辑一下配置文件。

```bash
sudo nano /etc/snapper-rollback.conf
```

把最后面这一行取消注释，改成你硬盘的分区。

```bash
dev = /dev/nvme0n1p3
```

之后就可以用它来回档了。执行完成后重启系统。

```bash
sudo snapper-rollback <ID>
```

在完成回档之后，还会产生一个备份用的子分区。如果不删除还会一直占用空间。可以用以下的方式删除，那些备份用的分区名字很好认。

```bash
sudo mount -o subvolid=0 /dev/nvme0n1p3 /mnt
cd /mnt
sudo btrfs subvolume delete <name>
sudo umount /mnt
```

不过 snapper-rollback 应该只能用来给 `@` 回档，其他的东西还是要用 Btrfs Assistant 或者 snapper-gui 比较方便。


## 救急

有时候我们会遇到系统都进不去的情况，为了防患于未然，我们还需要其他工具。安装 grub-btrfs 就可以在 GRUB 中显示当前系统中的所有快照。因为 Debian 中没有这个包，所以需要自己编译安装。

```bash
git clone https://github.com/Antynea/grub-btrfs.git
cd grub-btrfs
sudo make install
sudo systemctl start grub-btrfsd
sudo systemctl enable grub-btrfsd
```

以后再执行 `sudo update-grub` 的时候也会跟着把快照写进去。

## 增加新的子分区

有时候我们在安装完成之后还想增加新的子分区。比如说我们安装了 KVM 但不想要备份 KVM 的文件（因为太大了）。这时候该怎么办呢？

首先创建一个新的文件夹用于挂载 btrfs 真正的 root，然后挂载。如果忘了是哪个盘的话，可以用 `df -h` 再确认一下。

```
sudo mkdir /mnt/btrfsroot
sudo mount -o subvol=/ /dev/nvme0n1p3 /mnt/btrfsroot/
```

接下来创建新的子分区，然后解除挂载。

```
cd /mnt/btrfsroot
sudo btrfs su cr @images
cd ..
sudo umount btrfsroot
```

和之前一样编辑 `/target/etc/fstab` 在其中添加新子分区的信息。

```
UUID=0bd3d1d3-6814-4703-8796-c200c2f07552 /var/lib/libvirt/images btrfs rw,noatime,compress=zstd,subvol=@images 0 0
```

最后重新挂载所有分区就完成了。

```
sudo mount -av
```

以上就是我最近研究 Btrfs 快照的一些经验了，希望能对你有所帮助。
