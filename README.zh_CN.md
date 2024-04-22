# Warp Tproxy For Docker

[中文文档](./README.zh_CN.md) | [English README](./README.md)



一个容器化的[WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp)客户端代理。（ubuntu:22.04 + warp-svc），用于在容器项目和k8s中使用零信任和私有网络， 与[docker-transparent-proxy](https://github.com/Paper-Dragon/docker-transparent-proxy/tree/main/tproxy-warp)项目配合，实现给每个容器分配一个公网IP地址。

适用于`free`或`warp+`和`zero Trust`网络。

- 为 Docker 提供 Warp Tproxy
  - [功能](#功能)
  - [环境变量](#环境变量)
  - [自动切换Registration](自动切换Registration)
  - [在仪表板中设置MDM](#在仪表板中设置MDM)
  - [本地构建镜像](本地构建镜像)
  - [示例](#示例)
  - [技巧](#技巧)
  - [致谢](#致谢)
  - [许可证](#许可证)

## 功能

它可以在 Linux 平台上使用`docker`、`podman`或`k8s`一起运行。

## 环境变量

- **WARP_ORG_ID** - WARP MDM 组织ID。（例如`paperdragon`）
- **WARP_AUTH_CLIENT_ID** - WARP MDM 客户端ID。（例如以 `.access` 结尾的`[a-z0-9]{32}`）
- **WARP_AUTH_CLIENT_SECRET** - WARP MDM 客户端密钥。（例如`[a-z0-9]{64}`）
- **WARP_UNIQUE_CLIENT_ID** - WARP MDM 唯一客户端ID。
- **WARP_LICENSE** - WARP MDM 许可证密钥。

## 自动切换Registration

- 如果未设置`ID`或`LICENSE`，则`free`模式是默认模式。它将注册新帐户（免费网络）。
- 当设置了`WARP_ORG_ID` `WARP_AUTH_CLIENT_ID` `WARP_AUTH_CLIENT_SECRET`时，将自动使用`mdm`模式（零信任网络）。
- 当设置了`WARP_LICENSE`时，将自动使用`warp+`模式（warp+网络）。

基于某种原因，强烈建议您使用具有`WARP_ORG_ID` `WARP_AUTH_CLIENT_ID` `WARP_AUTH_CLIENT_SECRET`设置的`mdm`模式。

并设置一个来自Cloudflare Zero Trust仪表板的代理策略，或者使用`WARP_LICENSE`设置`warp+`模式。

> 如果您需要在`mdm`模式下添加其他组织，或者编写更多自定义设置，您可以修改此示例文件并添加一个`<dict>`部分。

Cloudflare MDM 文档 [在此](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/)。Cloudflare MDM 参数文档 [在此](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/parameters/#service_mode)。

但为了不破坏`entrypoint.sh`流程，请**不要**更改此部分：

```
xml
<array>
  # 不要修改此部分
  <dict>
    <key>organization</key>
    <string>ORGANIZATION</string>
    <key>display_name</key>
    <string>ORGANIZATION</string>
    <key>auth_client_id</key>
    <string>AUTH_CLIENT_ID</string>
    <key>auth_client_secret</key>
    <string>AUTH_CLIENT_SECRET</string>
    <key>unique_client_id</key>
    <string>UNIQUE_CLIENT_ID</string>
    <key>onboarding</key>
    <false />
  </dict>
  # 在这里添加您的自定义部分
</array>
```

## 在仪表板中设置MDM

1. 进入Cloudflare Zero Trust仪表板。
2. 在字母范围内创建您的组织团队：`[a-zA-Z0-9-]`，并记住您的`ORGANIZATION`（将org名称设置为./secrets）。
3. 创建一个`Access -> Service Authentication -> Service Token`，并从仪表板获取`AUTH_CLIENT_ID`和`AUTH_CLIENT_SECRET`（设置为./secrets）。
4. 转到`Settings -> Warp Client -> Device settings`并添加一个新策略（例如：命名为“mdmPolicy”）。
5. 进入策略配置页面，在表达式中添加一个规则，让`email` - `is` - `non_identity@[your_org_name].cloudflareaccess.com`。 （或者按设备UUID过滤）
6. 向下滚动，找到`Service mode`，设置为`Gateway with WARP`模式。 [为什么必须在策略中设置Gateway with WARP模式？](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/parameters/#service_mode)
7. 根据需要修改其他设置。
8. 然后保存。

## 本地构建镜像

```bash
docker build -t paperdragon/warp-tproxy .
```

## 示例

在 ubuntu 23.04 上使用 docker 进行测试运行：

```bash
# 或者从docker hub下载
# docker pull jockerdragon/warp-tproxy

# 检查镜像
root@user-VirtualBox:/home/user# docker images
REPOSITORY                 TAG       IMAGE ID       CREATED        SIZE
jockerdragon/warp-tproxy   latest    1cce82cba813   10 hours ago   570MB


# 仅供测试使用环境变量，您可以在./secrets中设置它
export WARP_ORG_ID=paperdragon
export WARP_AUTH_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx.access
export WARP_AUTH_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

docker run -d --name warp \
  -e WARP_ORG_ID=WARP_ORG_ID \
  -e WARP_AUTH_CLIENT_ID=WARP_AUTH_CLIENT_ID \
  -e WARP_AUTH_CLIENT_SECRET=WARP_AUTH_CLIENT_SECRET \
  --cap-add NET_ADMIN \
  -v /dev/net/tun:/dev/net/tun \
  jockerdragon/warp-tproxy
  
# 在 warp 容器中进行测试
docker exec -it warp curl http://cloudflare.com/cdn-cgi/trace

# 在容器外部的 gost 进行测试
curl http://ifconfig.icu
```

您可以看到类似以下的输出：

```text
[+] Starting dbus...
[+] Bypassing warp's TOS...
[+] Starting warp-svc...
```

## 技巧

添加环境变量到命令行

- **DEBUG** - 将 `DEBUG=True` 设置为 env 以显示更多细节。

## 致谢

- 本项目是修改自[Warpod](https://github.com/deepwn/warpod.git)项目，该项目实现了使用一个Warp容器，用于将HTTP代理暴露给外部使用。

## 许可证

[MIT](./LICENSE)
