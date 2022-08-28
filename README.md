# Pihole + Dokku - Installation Guide

<p>
    <a href="https://github.com/Rikj000/Pihole-Dokku-Installation/blob/master/README.md">
        <img src="https://img.shields.io/badge/Docs-Pihole+Dokku-blue?logo=libreoffice&logoColor=white" alt="The current place where you can find Pihole Dokku Installation Documentation!">
    </a> <a href="https://github.com/Rikj000/Pihole-Dokku-Installation/blob/master/LICENSE.md">
        <img src="https://img.shields.io/github/license/Rikj000/Pihole-Dokku-Installation?label=License&logo=gnu" alt="GNU General Public License">
    </a> <a href="https://www.iconomi.com/register?ref=JdFzz">
        <img src="https://img.shields.io/badge/Join-ICONOMI-blue?logo=bitcoin&logoColor=white" alt="ICONOMI - The world’s largest crypto strategy provider">
    </a> <a href="https://www.buymeacoffee.com/Rikj000">
        <img src="https://img.shields.io/badge/-Buy%20me%20a%20Coffee!-FFDD00?logo=buy-me-a-coffee&logoColor=black" alt="Buy me a Coffee as a way to sponsor this project!">
    </a>
</p>

I've struggled quite a bit to host [`pihole`](https://pi-hole.net/) in a [`dokku`](https://dokku.com/) container,   
accessible over my LAN network and over the web through an allocated sub-domain name.

Due to no clear documentation for this being available on the web,   
I've decided to write out some of my own after finally succeeding with my own setup.


## Prerequisites

Following prerequisites fall out of the scope of this installation guide:
- [Docker](https://www.docker.com/)
- [Dokku](https://dokku.com/)
    - Linked domain name *(e.g. my-dokku-server.com)*
    - SSL Certification *(e.g. LetsEncrypt, Cloudflare, ...)*
- [Ledokku](https://www.ledokku.com/) *(Optional)*


## Network Properties

| Device           | Fixed-IP Address                         |
| ---------------- | ---------------------------------------- |
| Router / Gateway | 192.168.0.1                              |
| Dokku Server     | 192.168.0.101 *(Yours may be different)* |
| Pihole App       | 192.168.0.212                            |

### Domain Names

*(Yours will likely be different)*

| Device       | Value                      |
| ------------ | -------------------------- |
| Dokku Server | my-dokku-server.com        |
| Pihole App   | pihole.my-dokku-server.com |


### `macvlan0` Network Properties

| Property                         | Value            |
| -------------------------------- | ---------------- |
| Network / DHCP scope reservation | 192.168.0.210/28 |
| Host Min                         | 192.168.0.211    |
| Host Max                         | 192.168.0.224    |
| Hosts/Net                        | 14               |


## Installation

### **1.** Setup `macvlan0` network
- **1.1.** Create a synology `macvlan0` bridge network attached to the physical `eth0` adapter:   

    ```bash
    sudo ip link add macvlan0 link eth0 type macvlan mode bridge
    ```

- **1.2.** Reserve part of the `eth0` IP-range scope for the `macvlan0`:   

    ```bash
    sudo ip addr add 192.168.0.210/28 dev macvlan0
    ```

- **1.3.** Bring up the virtual `macvlan0` adapter:   

    ```bash
    sudo ip link set macvlan0 up
    ```

- **1.4.** Check virtual adapter status with `ifconfig`:

    ```bash
    ifconfig
    ```

    Output should be something like this:   

    ```properties
    macvlan0  Link encap:Ethernet  HWaddr 92:8D:43:0E:E2:D8
    inet addr:192.168.0.210  Bcast:0.0.0.0  Mask:255.255.255.240
    inet6 addr: fe80::908d:43ff:fe0e:e2d8/64 Scope:Link
    UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
    RX packets:79 errors:0 dropped:0 overruns:0 frame:0
    TX packets:48 errors:0 dropped:0 overruns:0 carrier:0
    collisions:0 txqueuelen:1
    RX bytes:34863 (34.0 KiB)  TX bytes:16322 (15.9 KiB)
    ```

### **2.** Create a `macvlan-pihole` Docker network using `eth0`

```bash
docker network create \
    --driver=macvlan \
    --gateway=192.168.0.1 \
    --subnet=192.168.0.0/24 \
    --ip-range=192.168.0.210/28 \
    -o parent=eth0 \
    macvlan-pihole
```

### **3.** Create a `pihole` Dokku app using `macvlan-pihole`

- **3.1.** Create a `pihole` dokku app:   
    ***(If using `ledokku`, then use GUI instead, to create the `pihole` app!)***   

    ```bash
    dokku apps:create pihole
    ```

- **3.2.** Disable default `--init` process injection:   
    ```bash
    dokku scheduler-docker-local:set pihole init-process false
    ```

- **3.3.** Setup `volumes` to assure settings & storage will stick upon container re-creation:   

    ```bash
    dokku storage:mount pihole ~/pihole-data/etc-pihole:/etc/pihole
    dokku storage:mount pihole ~/pihole-data/etc-dnsmasq.d:/etc/dnsmasq.d
    ```

- **3.4.** Configure the required environment variables for the `pihole`,   
    adjust `TZ`, `ADMIN_EMAIL`, `VIRTUAL_HOST` and `CORS_HOSTS` as needed:   

    ```bash
    dokku config:set --no-restart pihole TZ='UTC'; \
    dokku config:set --no-restart pihole ADMIN_EMAIL='my-admin@email.com'; \
    dokku config:set --no-restart pihole REV_SERVER_TARGET='192.168.0.1'; \
    dokku config:set --no-restart pihole FTLCONF_LOCAL_IPV4='192.168.0.212'; \
    dokku config:set --no-restart pihole VIRTUAL_HOST='pihole.my-dokku-server.com'; \
    dokku config:set --no-restart pihole CORS_HOSTS='my-dokku-server.com,pihole.my-dokku-server.com,192.168.0.212'
    ```

- **3.5.** Setup forwarding of the required ports for the `pihole`:

    ```bash
    dokku proxy:ports-add http:80:80 https:443:80 http:53:53 tcp:53:53 udp:53:53 udp:67:67
    ```


- **3.6.** Setup the static `pihole` container IP as an additional `domain-name` for the app:   

    ```bash
    dokku domains:add pihole 192.168.0.212
    ```

- **3.7.** Setup additional `deploy` and `run` `docker-options` required for the `pihole` app:   

    ```bash
    # Allow modification of network interfaces on the host system:
    dokku docker-options:add pihole deploy,run '--cap-add NET_ADMIN'

    # Set the static IP address for the pihole app:
    dokku docker-options:add pihole deploy,run '--ip "192.168.0.212"'

    # Set a static MAC address for the pihole app (Use this one, or a random other):
    dokku docker-options:add pihole deploy,run '--mac-address "02:42:c0:a8:01:d7"'
    ```

- **3.8.** Make the `pihole` app directly accessible by other hosts on your network:   

    ```bash
    dokku network:set pihole bind-all-interfaces true
    ```

- **3.9.** Attach the `pihole` app to the `macvlan-pihole` network:   

    ```bash
    dokku network:set pihole attach-post-create macvlan-pihole
    dokku network:set pihole attach-post-deploy macvlan-pihole
    dokku network:set pihole initial-network macvlan-pihole
    ```

- **3.10.** Rebuild the network of the `pihole` app:   

    ```bash
    dokku network:rebuild pihole
    ```

- **3.11.** Deploy the latest `pihole` docker tag:   

    ```bash
    dokku git:from-image pihole pihole/pihole:latest
    ```

## Updates

```bash
dokku git:from-image pihole pihole/pihole:latest
```

## Used Sources
- [Docs - Dokku](https://dokku.com/docs/getting-started/installation/)
- [Docs - Pihole](https://docs.pi-hole.net/)
- [Github - Docker-Pi-Hole](https://github.com/pi-hole/docker-pi-hole)
- [Github Gist - Pihole-Macvlan-Synology-Docker](https://gist.github.com/xirixiz/ecad37bac9a07c2a1204ab4f9a17db3c)
- [Blog - Free your Synology ports for Docker](https://tonylawrence.com/posts/unix/synology/free-your-synology-ports/)
- [Blog - Set up a PiHole using Docker MacVlan Networks](https://blog.ivansmirnov.name/set-up-pihole-using-docker-macvlan-network/)