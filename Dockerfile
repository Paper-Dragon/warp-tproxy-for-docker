FROM ubuntu:22.04

# install warp
RUN apt-get update && apt-get -y install curl gnupg2 dbus && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | tee /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update \
    && apt-get -y install cloudflare-warp \
    && apt clean all && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD mdm.xml.example /var/lib/cloudflare-warp/mdm.xml.example

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
