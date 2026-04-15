#!/bin/bash
set -euo pipefail

echo "=== [1/7] repo バックアップ ==="
sudo cp -a /etc/yum.repos.d /etc/yum.repos.d.bak.$(date +%Y%m%d%H%M%S)

echo "=== [2/7] CentOS repo を vault 向けに修正 ==="
for f in /etc/yum.repos.d/CentOS-*.repo; do
  [ -f "$f" ] || continue

  sudo sed -i \
    -e 's/^[[:space:]]*mirrorlist=/#mirrorlist=/g' \
    -e 's/^[[:space:]]*metalink=/#metalink=/g' \
    -e 's/^[[:space:]]*#[[:space:]]*baseurl=/baseurl=/g' \
    -e 's|mirror\.centos\.org/centos/\$releasever|vault.centos.org/7.9.2009|g' \
    -e 's|mirror\.centos\.org/centos/7|vault.centos.org/7.9.2009|g' \
    -e 's|ftp\.sakura\.ad\.jp/pub/linux/centos/\$releasever|vault.centos.org/7.9.2009|g' \
    -e 's|ftp\.sakura\.ad\.jp/pub/linux/centos/7|vault.centos.org/7.9.2009|g' \
    "$f"
done

echo "=== [3/7] yum キャッシュ削除 ==="
sudo yum clean all
sudo rm -rf /var/cache/yum

echo "=== [4/7] CentOS 側キャッシュ再構築 ==="
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 || true
sudo yum makecache

echo "=== [5/7] epel-release 導入 ==="
sudo yum install -y epel-release

echo "=== [6/7] EPEL repo を archive 向けに修正 ==="
for f in /etc/yum.repos.d/epel*.repo; do
  [ -f "$f" ] || continue

  sudo sed -i \
    -e 's/^[[:space:]]*mirrorlist=/#mirrorlist=/g' \
    -e 's/^[[:space:]]*metalink=/#metalink=/g' \
    -e 's/^[[:space:]]*#[[:space:]]*baseurl=/baseurl=/g' \
    -e 's|https\?://download\.fedoraproject\.org/pub/epel|https://archive.fedoraproject.org/pub/archive/epel|g' \
    -e 's|https\?://dl\.fedoraproject\.org/pub/epel|https://archive.fedoraproject.org/pub/archive/epel|g' \
    "$f"
done

echo "=== [7/7] ezstream インストール ==="
sudo yum clean all
sudo rm -rf /var/cache/yum
sudo yum makecache
sudo yum install -y ezstream

echo "=== [完了] バージョン確認 ==="
ezstream -V

