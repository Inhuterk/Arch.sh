# Prepare alpine linux, which can be configured to run from ram only.
# Alpine is leveraged to do the conversion.
# In any linux(ubuntu/debian/arch tested) become root first:
sudo su -
cd /tmp && wget https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/alpine-virt-3.18.0-aarch64.iso
dd if=alpine-virt-3.18.0-aarch64.iso of=/dev/sda && sync && reboot

# In Alpine with console:
# [Bring up networking]
ip li set eth0 up
udhcpc eth0
# [Setup SSH, answer RET, yes, RET]
setup-sshd
# [set temp password]
passwd
# [At this point it's easier to use SSH to copy & paste]

# [Per Ref #3]
mkdir /media/setup
cp -a /media/sda/* /media/setup
mkdir /lib/setup
cp -a /.modloop/* /lib/setup
/etc/init.d/modloop stop
umount /dev/sda
mv /media/setup/* /media/sda/
mv /lib/setup/* /.modloop/

# [Setup apk and bring in pacman]
setup-apkrepos
# [enable community]
vi /etc/apk/repositories

apk update
apk add dosfstools e2fsprogs findmnt pacman arch-install-scripts

# [Disk partitioning & mounting]
# (use gpt table, set esp partition 15 size 256M), set root partition 1 size remaining)
# g, n, 15, RET, +256m, t, 1, n, RET, RET, RET, p, w
fdisk /dev/sda

ls /dev/sda*
# if sda1 or sda15 is missing, do "/etc/init.d/devfs restart"

mkfs.vfat /dev/sda15
mkfs.ext4 /dev/sda1

mount -t ext4 /dev/sda1 /mnt
mkdir /mnt/boot
mount /dev/sda15 /mnt/boot

cd /mnt && wget http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
bsdtar -xpf /mnt/ArchLinuxARM-aarch64-latest.tar.gz -C /mnt
genfstab -U /mnt >> /mnt/etc/fstab

cd /; arch-chroot /mnt/
# This is your arch root password. Choose carefully and remember it
# do the same for user `alarm` if you prefer to use that account and lots of `sudo`
passwd
cat > ~/.ssh/authorized_keys << EOF
<ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCQ+QEWVIrT9izvp6odnik5Glec3pyIXWEnyfUv8o1UtwmAmXWlZvnUo086p1ExWnGGamShK05vW+UHRWcyRC7HVQOe8/USfJ3CeQ07VFgUQnQfXCS2BiP0WtL2qMWdSdKeYJtbxxOaJIvUpR2dagRk8rQsjdAsHko5Dhma0eYR8W5QItr63IB4INFDhTcbJ/YqRCogZQtdY/Yc9ve35Apdz2uTgi5oGjWzZrWv7HzZfvGqF1FzBqk2lDFm5172EgBPXZhv/cEdCAIulvKgNMg4byhYitffT2koPXcF+N0irjwSJPrC4Y3TkBWRHIzzVKs4og315zXZGRqfARW6sEut>
EOF

cat > /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 4.2.2.2
nameserver 8.8.8.8
EOF

pacman-key --init
pacman-key --populate archlinuxarm
pacman --noconfirm -Syu grub efibootmgr vi

# [EFI boot]
grub-install --efi-directory=/boot --bootloader-id=GRUB
vi /etc/default/grub
# Better console. Comparison below:
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 console=ttyS0,115200"
# Or use perl/sed to replace
#   perl -pi.bak -e "s/quiet/console=ttyS0,115200/" /etc/default/grub
#   sed   -i.bak -e "s/quiet/console=ttyS0,115200/" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
exit
reboot
