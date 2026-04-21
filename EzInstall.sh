#!/bin/bash
# CentOS 7 (EOL) 環境向け ezstream インストールスクリプト
# - CentOS repo を vault.centos.org に向け直す
# - epel-release を導入後、epel*.repo を全削除し archive 向け epel.repo を直接配置する
# - ezstream を導入する
set -euo pipefail

log()  { echo -e "\n=== $* ==="; }
die()  { echo -e "\n[ERROR] $*" >&2; exit 1; }

# ------------------------------------------------------------
log "[1/8] repo バックアップ"
BACKUP_DIR="/etc/yum.repos.d.bak.$(date +%Y%m%d%H%M%S)"
sudo cp -a /etc/yum.repos.d "$BACKUP_DIR"
echo "backup: $BACKUP_DIR"

# ------------------------------------------------------------
log "[2/8] CentOS repo を vault.centos.org 向けに修正"
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

# ------------------------------------------------------------
log "[3/8] yum キャッシュ削除"
sudo yum clean all
sudo rm -rf /var/cache/yum

# ------------------------------------------------------------
log "[4/8] CentOS 側キャッシュ再構築"
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 || true
sudo yum makecache \
  || die "CentOS vault からの makecache に失敗。ネットワーク / DNS / 時刻 (ca-certificates) を確認してください。"

# ------------------------------------------------------------
log "[5/8] epel-release 導入"
sudo yum install -y epel-release \
  || die "epel-release のインストールに失敗しました。"

# ------------------------------------------------------------
# [6/8] epel*.repo を全削除し、archive 向け epel.repo を直接配置
#   - さくらイメージの baseurl=http://download.example/... のような
#     不定なプレースホルダに依存しない
#   - epel-release が入れた mirrorlist= ベースの設定を丸ごと置き換える
# ------------------------------------------------------------
log "[6/8] epel.repo を archive.fedoraproject.org 向けに再作成"

sudo rm -f /etc/yum.repos.d/epel*.repo

sudo tee /etc/yum.repos.d/epel.repo > /dev/null <<'EOF'
[epel]
name=Extra Packages for Enterprise Linux 7 - $basearch (archive)
baseurl=https://archive.fedoraproject.org/pub/archive/epel/7/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - $basearch - Debug (archive)
baseurl=https://archive.fedoraproject.org/pub/archive/epel/7/$basearch/debug
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-source]
name=Extra Packages for Enterprise Linux 7 - $basearch - Source (archive)
baseurl=https://archive.fedoraproject.org/pub/archive/epel/7/SRPMS
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
EOF

echo "--- 配置した epel.repo 内容 ---"
sudo cat /etc/yum.repos.d/epel.repo

# 念のため、何らかの理由で他に EPEL 系 repo が残っていれば無効化
# (今回は上で rm しているので通常は何も残らないが、将来的な保険)
for f in /etc/yum.repos.d/epel-testing*.repo /etc/yum.repos.d/epel-playground*.repo; do
  [ -f "$f" ] || continue
  echo "disable: $f"
  sudo sed -i 's/^enabled=.*/enabled=0/g' "$f"
done

# ------------------------------------------------------------
log "[7/8] EPEL 単体で makecache 検証"
sudo yum clean all
sudo rm -rf /var/cache/yum

sudo yum --disablerepo='*' --enablerepo='epel' makecache \
  || die "EPEL archive への makecache に失敗しました。ネットワーク / https (ca-certificates) / 時刻同期を確認してください。"

log "全体キャッシュ再構築"
sudo yum makecache \
  || die "全体の makecache に失敗しました。"

# ------------------------------------------------------------
log "[8/8] ezstream インストール"
sudo yum install -y ezstream \
  || die "ezstream のインストールに失敗しました。"

# ------------------------------------------------------------
log "[完了] バージョン確認"
ezstream -V
echo
echo "backup は $BACKUP_DIR に残っています。問題なければ削除可: sudo rm -rf $BACKUP_DIR"
