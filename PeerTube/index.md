# 搭建易于访问的私人 PeerTube 实例

本文旨在描述如何通过虚拟主机与对象存储，配置易于私人使用的 PeerTube 实例。教程并不适用供大规模访问的网站架设。

虽然说只要 VPS 访问起来没有问题，不用对象存储也是没有问题的。但从经费的角度上，购买高带宽的对象存储总要比高带宽的 VPS 来的省钱。所以对于本文的目标读者，我还是建议使用对象存储。

## 事前准备

1. 一台 VPS（本文以 Ubuntu/Debian 为例）
2. 对象存储服务（本文以 Backblaze B2 为例）
3. 个人域名或子域名
4. 习惯使用 Linux 的大脑

## 配置对象存储

首先你需要配置一个供 PeerTube 保存其影片的对象存储池。PeerTube 支持 Amazon S3，或 Backblaze B2，你用哪个都行。

### 访问密钥

你需要从你选择的服务商建立一个访问用的 Key，并将：

1. App Key ID 
2. App Key 

记录下来以备稍后使用。

### 存储池

之后建立一个给 PeerTube 使用的池，并将池设置为**公开（Public）**，记录下：

1. 名字
2. 终结点（Endpoint，即对象存储的主域名）
3. 地区（只有 Amazon S3 需要）

### 配置 CORS

CORS 其实就是防盗链。你肯定不希望什么网站都外链你的视频出去播放。在上一步已经设置为公开的基础上，点击 **“CORS Rules”** 按钮进行配置。

选择：Share everything in this bucket with this one origin.

并在其下方写下你将会使用的域名。需包含 https://，端口号可以没有。

CORS 配置大概需要十分钟左右的时间来生效，正好可以来安装我们的网站。

## 安装 PeerTube

PeerTube 的安装是非常麻烦的，所以有很多人会选择使用 Docker 进行安装，但假如你对 Docker 并不熟悉，后续配置的时候可能会十分头疼。所以这里我们将直接进行安装。本文默认你在非 root 的 sudo user 下进行操作，其他情况请自行调整。

### 前置准备

安装 Node.js：

```
sudo apt install build-essential gnupg curl wget unzip

curl -sL https://deb.nodesource.com/setup_lts.x | sudo bash -

sudo apt install nodejs
sudo npm i -g yarn
```

安装其他包：

```
sudo apt install git python-dev ffmpeg postgresql postgresql-contrib redis-server
```

此处我们没有安装 nginx，因为我将会在后文使用 Caddy2 作为 Web 服务器。

启动数据库：

```
sudo systemctl enable --now postgresql redis-server
```

建立 PeerTube 用户并设置其密码：

```
sudo useradd -m -d /var/www/peertube -s /bin/bash peertube
sudo passwd peertube
```

配置 PostgreSQL 用户和数据库：

```
sudo -u postgres createuser -P peertube
sudo -u postgres createdb -O peertube -E UTF8 -T template0 peertube_prod

sudo -u postgres psql -c "CREATE EXTENSION pg_trgm;" peertube_prod
sudo -u postgres psql -c "CREATE EXTENSION unaccent;" peertube_prod
```

此处第一条命令后你会被要求输入数据库的访问密码，后面我们会用到。

### 安装 PeerTube

首先进入到 peertube 用户下：

```
su - peertube
```

下载最新版的 PeerTube：

```
mkdir config storage versions && cd versions
wget https://github.com/Chocobozzz/PeerTube/releases/download/v4.0.0/peertube-v4.0.0.zip
unzip peertube-v4.0.0.zip
ln -s /var/www/peertube/versions/peertube-v4.0.0 ../peertube-latest
```

本文编写时 PeerTube 的最新版本是 4.0，其他版本可以从 [GitHub](https://github.com/Chocobozzz/PeerTube/releases) 获取。

安装：

```
cd ../peertube-latest
yarn install --production --pure-lockfile
```

安装过程中可能会出现一些警告，不用管他。

### 调整配置文件

首先从模版创建新的配置文件并打开：

```
cp config/default.yaml /var/www/peertube/config/default.yaml
cp config/production.yaml.example /var/www/peertube/config/production.yaml
nano /var/www/peertube/config/production.yaml
```

此处使用的是 nano 编辑器，使用方法非常简单，99.9% 的时候都只用 Crtl+O 保存，Ctrl+X 退出。

需要改动的地方有以下几点：

```
webserver:
  https: true
  hostname: 'peertube.imlala.best' # 你的域名
  port: 443
```

如果你希望使用 http 进行测试，可以暂时改为 80 端口。

```
database:
  hostname: 'localhost'
  port: 5432
  ssl: false
  suffix: '_prod'
  username: 'peertube'
  password: 'password' # 刚刚设置的数据库密码
  pool:
    max: 5
```

```
object_storage:
  enabled: true # 改为启用
  endpoint: 's3.us-west-002.backblazeb2.com' # 你的对象存储池终结点
  # region: 'us-east-1' # 你的对象存储地区（如果需要的话）
  credentials:
    access_key_id: 'xxxxxx' # 你的 App Key ID
    secret_access_key: 'xxxxxx' # 你的 App Key
  max_upload_part: 2GB
  streaming_playlists:
    bucket_name: 'PeerTube' # 你的对象存储池名字
    prefix: 'streaming-playlists:' # 串流子文件夹名，注意结尾的冒号
  videos:
    bucket_name: 'PeerTube' # 你的对象存储池名字
    prefix: 'videos:' # 影片子文件夹名，注意结尾的冒号
```

可以根据自己的实际需要填写，如果你不准备用对象存储，这里可以不改。串流列表和影片的池可以不是一个，如果不是一个的话，可以将两行子文件夹名用井号注释掉，如果是一个则必须要有子文件夹名。

```
transcoding:
  enabled: false # 关闭转码
```

如果你的 VPS 性能很强可以不改，一般的便宜 VPS 都不太带的动转码的工作，我建议你在自己的电脑上转好了再上传。确保视频格式为 H264 音频格式为 AAC。

```
tracker:
  enabled: false ## 关闭 P2P
```

因为我们的实例是自用的，开着 P2P 没什么意义，所以关掉。P2P 还会影响从对象存储串流。这里的选项并没有办法完全关闭 WebTorrent，我们后面会继续讲。

最后不要忘了保存。

### 启动 PeerTube

这里先用 `Exit` 命令回到之前的用户下，之后启动 PeerTube 服务：

```
sudo systemctl enable --now peertube
```

检查一下运行有无问题：

```
sudo systemctl status peertube
```

我们还需要修改默认的管理员密码，回到 peertube 用户下操作：

```
su - peertube
cd peertube-latest && NODE_CONFIG_DIR=/var/www/peertube/config NODE_ENV=production npm run reset-password -- -u root
```

注意此处因为要拉起 Node.js，到出现输入密码提示的速度非常慢，如果误操作多按了回车什么的，可以用 Crtl+C 取消重来。

完成后再次用 `Exit` 命令回到之前的用户下。

## 安装 Caddy

Caddy 是一款非常现代且易于配置的 Web 服务器，还可以自动从 Let's Encrypt 签发 HTTPS 证书，我也很推荐你在其他场合尝试使用 Caddy。

用以下命令添加 Caddy 的源并安装：

```
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

编辑 Caddy 配置文件：

```
sudo nano /etc/caddy/Caddyfile
```

将文件的内容替换为以下内容并保存：

```
peertube.imlala.best { # 你的域名
        reverse_proxy 127.0.0.1:9000
}
```

启动 Caddy 服务：

```
sudo systemctl enable --now caddy
```

检查运行有无问题：

```
sudo systemctl status caddy
```

此时如果出现端口被占用的问题，说明你可能在运行 nginx 一类的其他 Web 服务器。如果出现无法注册 HTTPS 证书一类的问题，可以检查一下防火墙和 CDN 配置，比如关掉 Cloudflare 的代理再试。

现在你可以打开你的网站试试看了，如果不出意外应该已经可以打开了。你可以用 root 和刚才设置的密码来登录。如果访问不了可以检查防火墙配置。

## 其他必要配置

在 PeerTube 的管理页面中我们可以对服务器做进一步的自定义。我这里挑选一些重要的来讲一下。

### 管理面板

首先我建议你安装 privacysettings 插件，它可以将新上传的影片锁定为站内访问，对一个自用的节点非常实用。

在 Configuration > Basic 下，你可以将 SEARCH 和 FEDERATION 里面的项目全部勾掉，来进一步提高自闭程度。记得点保存设置。

### 我的账户面板

还记得我们刚才提到的 P2P 影响对象存储访问的问题吗？我很怀疑这其实是一个 Bug，在 Tracker 已经被禁用的情况下，P2P 应该不可用才对，但 Web Torrent 却还在浏览器上运行。这基本上等于是把我们用来提速的对象给存储架空了。即便在不用对象存储的条件下，我依然发现它要比直连慢得多，对于私人使用来说怎么都是关掉为好。

我们需要在 “我的账户” 的 Settings 中找到 “帮助分享正在播放的视频” 勾掉。记得点保存设置。这一选项需要在每个用户的设置里面进行调整，非常的麻烦，不过因为我们是自己用，所以影响不是特别大。希望这一问题能在以后的版本中得到解决。

PeerTube 的中文翻译也不是很完整，有时候有有时候没有。

## 排错

在 PeerTube 的 “管理” 的 “系统” 菜单下的 Jobs 中可以看到正在执行的任务。如 “move-to-object-storage	” 就是将上传的视频移动到对象存储的任务，你可以在其报告中看到一些相关的错误提示。如果对象存储无法访问，可以检查 CORS 是否正确，极端情况下可以先改成允许所有网站访问进行测试。还有可能是因为对象存储没有设置为 Public。

如完全按照本教程配置，播放器应该会在播放时右下角显示 HTTP 字样（电脑版页面），而不是上传下载速度，否则请检查是否已关闭 “帮助分享正在播放的视频”。

## 参考资料

[PeerTube Github](https://github.com/Chocobozzz/PeerTube/)
[PeerTube Docs](https://docs.joinpeertube.org/)

[荒岛 PeerTube v3：终于支持直播功能啦](https://lala.im/7688.html)
[知乎 Xpitz PeerTube 安装教程：如何搭建视频分享平台](https://zhuanlan.zhihu.com/p/357738044)（想要用 Docker 装的可以参考此文）

## 结语

我早就有想搭一个 PeerTube 的想法但是一直没有付诸实践，主要就是因为安装过于麻烦。这次教程用自用节点的角度尽可能细致的梳理了安装步骤，希望能够帮到有同样想法的朋友。