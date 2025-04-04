#!/bin/bash
sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
sed -i s/^#.*baseurl=http/baseurl=http/g /etc/yum.repos.d/*.repo
sed -i s/^mirrorlist=http/#mirrorlist=http/g /etc/yum.repos.d/*.repo
echo "sslverify=false" >> /etc/yum.conf

read -p "Nhap dia chi IPv6: " IPV6ADDR
read -p "Nhap Default Gateway cua IPv6: " IPV6_DEFAULTGW

echo "IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
IPV6ADDR=$IPV6ADDR/64
IPV6_DEFAULTGW=$IPV6_DEFAULTGW" >> /etc/sysconfig/network-scripts/ifcfg-eth0
service network restart
echo "Da tao ipv6 thanh cong"
