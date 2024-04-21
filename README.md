# Warpod

A containerized [WARP](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp) client proxy. (ubuntu:22.04 + warp-svc) for use Zero Trust and private network inside container project and k8s.

Working with `free` or `warp+` and `zero Trust` network.

- [Warpod](#warpod)
  - [Features](#features)
  - [Environment Variables](#environment-variables)
  - [Registration auto switch](#registration-auto-switch)
  - [Setting MDM in dashboard](#setting-mdm-in-dashboard)
  - [Build image locally](#build-image-locally)
  - [Example and tips](#example-and-tips)
  - [License](#license)

## Features
It can running with `docker` or `podman` or `k8s` on linux platform.


## Environment Variables

- **WARP_ORG_ID** - WARP MDM organization ID. (E.g. `paperdragon`)
- **WARP_AUTH_CLIENT_ID** - WARP MDM client ID. (E.g. `[a-z0-9]{32}` with subfix `.access`)
- **WARP_AUTH_CLIENT_SECRET** - WARP MDM client secret. (E.g. `[a-z0-9]{64}`)
- **WARP_UNIQUE_CLIENT_ID** - WARP MDM unique client ID.
- **WARP_LICENSE** - WARP MDM license key.


## Registration auto switch

- `free` mode is default if no `ID` or `LICENSE` be set. it will register new account (free network)

- `mdm` mode auto be using when `WARP_ORG_ID` `WARP_AUTH_CLIENT_ID` `WARP_AUTH_CLIENT_SECRET` set. (zero Trust network)

- `warp+` mode auto be using when `WARP_LICENSE` set. (warp+ network)

For some reason, highly recommend you use `mdm` mode with `WARP_ORG_ID` `WARP_AUTH_CLIENT_ID` `WARP_AUTH_CLIENT_SECRET` set.

And do set a policy of proxy from cloudflare Zero Trust dashboard, or use `warp+` mode with `WARP_LICENSE` set.

> if you need add other organization in `mdm` mode, or write more custom settings, you can modify this example file add a `<dict>` part.

cloudflare MDM document [here](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/). cloudflare MDM parameters document [here](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/parameters/#service_mode).

but for not break the `entrypoint.sh` flow. plase do **NOT** change this part:

```xml
<array>
  # don't modify this part
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
  # add your custom part down here
</array>
```

## Setting MDM in dashboard

1. go cloudflare Zero Trust dashboard.
1. create your org team in words range: `[a-zA-Z0-9-]` and remember your `ORGANIZATION` (set org name to ./secrets).
1. create a `Access -> Service Authentication -> Service Token` and get `AUTH_CLIENT_ID` and `AUTH_CLIENT_SECRET` from dashboard. (set to ./secrets)
1. goto `Settings -> Warp Client -> Device settings` and add a new policy (E.g.: named "mdmPolicy").
1. into the policy config page, add a rule to let `email` - `is` - `non_identity@[your_org_name].cloudflareaccess.com` in expression. (Or filter by device uuid)
1. go down and find `Service mode` to set `Gateway with WARP` mode. [why must set Gateway with WARP mode in policy?](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/warp/deployment/mdm-deployment/parameters/#service_mode)
1. modify other settings if your want.
1. then save it.


## Build image locally
```bash
docker build -t paperdragon/warp-tproxy .
```

## Example and tips

test run with docker on ubuntu 23.04:

```text

# Or download from docker hub
# docker pull jockerdragon/warp-tproxy

# check image
root@user-VirtualBox:/home/user# docker images
REPOSITORY                 TAG       IMAGE ID       CREATED        SIZE
jockerdragon/warp-tproxy   latest    1cce82cba813   10 hours ago   570MB


# use env just for test, you can set it in ./secrets
export WARP_ORG_ID=deepwn
export WARP_AUTH_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx.access
export WARP_AUTH_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

podman run -d --name warp \
  -e WARP_ORG_ID=WARP_ORG_ID \
  -e WARP_AUTH_CLIENT_ID=WARP_AUTH_CLIENT_ID \
  -e WARP_AUTH_CLIENT_SECRET=WARP_AUTH_CLIENT_SECRET \
  --cap-add NET_ADMIN \
  -v /dev/net/tun:/dev/net/tun \
  jockerdragon/warp-tproxy
  
# test in container for warp
docker exec -it warp curl http://cloudflare.com/cdn-cgi/trace

# test out container for gost
curl http://ifconfig.icu
```

and you can see the output like this:

```text
[+] Starting dbus...
[+] Bypassing warp's TOS...
[+] Starting warp-svc...

```


## License

[MIT](./LICENSE)
