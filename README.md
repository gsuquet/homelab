# HomeLab

## Configuration
```bash
sudo nano /boot/cmdline.txt
// add at the end of the line:
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1

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
