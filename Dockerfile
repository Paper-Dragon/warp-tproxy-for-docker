FROM ubuntu:22.04

# install deps
RUN apt-get update && apt-get -y install curl gnupg2 dbus

# install warp
RUN curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main" | tee /etc/apt/sources.list.d/cloudflare-client.list \
    && apt-get update \
    # && apt-get -y upgrade \
    && apt-get -y install cloudflare-warp


ADD mdm.xml.example /var/lib/cloudflare-warp/mdm.xml.example

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
