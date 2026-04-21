#!/bin/bash
# CentOS 7 (EOL) ezstream installer
#
# What this script does:
#  1. Backs up /etc/yum.repos.d
#  2. Rewrites CentOS repos to vault.centos.org
#  3. Removes broken EPEL repo definitions
#  4. Downloads the EPEL GPG key from the Fedora archive
#  5. Writes a clean archive-based /etc/yum.repos.d/epel.repo
#  6. Verifies CentOS and EPEL metadata
#  7. Installs ezstream
#
# Notes:
#  - This script does NOT use epel-release, because CentOS 7 / EPEL 7 paths
#    and release RPM availability are inconsistent now.
#  - Console messages are intentionally English-only.

set -euo pipefail

log() {
  echo
  echo "=== $* ==="
}

die() {
  echo
  echo "[ERROR] $*" >&2
  exit 1
}

if [ "${EUID}" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

need_cmd yum
need_cmd rpm
need_cmd sed
need_cmd grep
need_cmd cp
need_cmd rm
need_cmd tee
need_cmd curl

log "[1/9] Backup yum repository files"
BACKUP_DIR="/etc/yum.repos.d.bak.$(date +%Y%m%d%H%M%S)"
$SUDO cp -a /etc/yum.repos.d "$BACKUP_DIR"
echo "Backup created: $BACKUP_DIR"

log "[2/9] Rewrite CentOS repositories to vault.centos.org"
for f in /etc/yum.repos.d/CentOS-*.repo; do
  [ -f "$f" ] || continue
  $SUDO sed -i \
    -e 's/^[[:space:]]*mirrorlist=/#mirrorlist=/g' \
    -e 's/^[[:space:]]*metalink=/#metalink=/g' \
    -e 's/^[[:space:]]*#[[:space:]]*baseurl=/baseurl=/g' \
    -e 's|mirror\.centos\.org/centos/\$releasever|vault.centos.org/7.9.2009|g' \
    -e 's|mirror\.centos\.org/centos/7|vault.centos.org/7.9.2009|g' \
    -e 's|ftp\.sakura\.ad\.jp/pub/linux/centos/\$releasever|vault.centos.org/7.9.2009|g' \
    -e 's|ftp\.sakura\.ad\.jp/pub/linux/centos/7|vault.centos.org/7.9.2009|g' \
    "$f"
done

log "[3/9] Disable broken EPEL definitions before any yum access"
for f in /etc/yum.repos.d/*.repo; do
  [ -f "$f" ] || continue
  if grep -qiE 'download\.example|^\[epel([^-].*)?\]|^\[epel\]|^\[epel-debuginfo\]|^\[epel-source\]|^\[epel-testing.*\]|^\[epel-playground.*\]' "$f"; then
    echo "Disabling broken or legacy EPEL settings in: $f"
    $SUDO sed -i \
      -e 's/^[[:space:]]*enabled=.*/enabled=0/g' \
      -e 's/^[[:space:]]*mirrorlist=/#mirrorlist=/g' \
      -e 's/^[[:space:]]*metalink=/#metalink=/g' \
      "$f"
  fi
done

log "[4/9] Clean yum cache"
$SUDO yum clean all
$SUDO rm -rf /var/cache/yum

log "[5/9] Verify CentOS vault repositories"
$SUDO rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 || true
$SUDO yum --disablerepo='epel*' makecache \
  || die "CentOS vault makecache failed. Check network, DNS, time sync, and CA certificates."

log "[6/9] Remove all EPEL repo files and install archive-based EPEL configuration"
$SUDO rm -f /etc/yum.repos.d/epel*.repo

$SUDO curl -L --fail -o /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 \
  https://archive.fedoraproject.org/pub/archive/epel/RPM-GPG-KEY-EPEL-7 \
  || die "Failed to download RPM-GPG-KEY-EPEL-7 from the Fedora archive."

$SUDO tee /etc/yum.repos.d/epel.repo > /dev/null <<'REPOEOF'
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
name=Extra Packages for Enterprise Linux 7 - Source (archive)
baseurl=https://archive.fedoraproject.org/pub/archive/epel/7/SRPMS
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
REPOEOF

echo "Installed /etc/yum.repos.d/epel.repo:"
$SUDO cat /etc/yum.repos.d/epel.repo

if grep -q 'download.example' /etc/yum.repos.d/epel.repo; then
  die "epel.repo still contains download.example. Aborting."
fi

log "[7/9] Verify EPEL archive repository only"
$SUDO yum clean all
$SUDO rm -rf /var/cache/yum
$SUDO yum --disablerepo='*' --enablerepo='epel' makecache \
  || die "EPEL archive makecache failed. Check network, DNS, time sync, and CA certificates."

log "[8/9] Rebuild full yum metadata and install ezstream"
$SUDO yum makecache \
  || die "Full yum makecache failed."
$SUDO yum install -y ezstream \
  || die "Failed to install ezstream."

log "[9/9] Done"
ezstream -V || true
echo
echo "Repository backup directory: $BACKUP_DIR"
echo "You can remove it later if everything works: ${SUDO:+sudo }rm -rf $BACKUP_DIR"
