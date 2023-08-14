# HomeLab

## Manual Installation
### Install Docker
Update and install packages
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git ca-certificates curl gnupg libnss3-tools
```

Add Docker’s official GPG key
```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/raspbian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

Add Docker apt repository
```bash
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/raspbian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
```

Install Docker Engine
```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Add user to docker group
```bash
sudo groupadd docker && sudo usermod -aG docker $USER
```

Create docker network
```bash
docker network create homelab
```

### Configure the Raspberry Pi for Docker
```bash
sudo nano /boot/cmdline.txt
# Add at the end of the line:
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```

### Configure Git
Set the global config
```bash
git config --global pull.rebase true
```

### Harden the Raspberry Pi
Disable unused wifi and bluetooth (optional)
```bash
echo "dtoverlay=disable-wifi" | sudo tee -a /boot/config.txt
echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt
```

Add user to ssh group
```bash
sudo groupadd ssh && sudo usermod -aG ssh $USER
```

### Configure the Raspberry Pi for Pi-hole
Set backup static DNS:
```bash
echo "
static domain_name_servers=127.0.0.1
" | sudo tee -a /etc/dhcpcd.conf
```
Set IP as env variable:
```bash
echo 'export IP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)' >> ~/.bashrc
```

### Reboot to apply changes
```bash
sudo reboot
```

## Startup
```bash
bash launch.sh
```

## Shutdown
```bash
bash shutdown.sh
```
