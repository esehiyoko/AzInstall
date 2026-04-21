#!/bin/bash
cat >/etc/yum.repos.d/epel.repo <<'EOF'
[epel]
name=Extra Packages for Enterprise Linux 7 - $basearch
baseurl=https://archive.fedoraproject.org/pub/archive/epel/7/$basearch
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - $basearch - Debug
baseurl=https://archive.fedoraproject.org/pub/archive/epel/7/$basearch/debug
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-source]
name=Extra Packages for Enterprise Linux 7 - $basearch - Source
baseurl=https://archive.fedoraproject.org/pub/archive/epel/7/SRPMS
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
EOF

yum clean all
rm -rf /var/cache/yum
yum --disablerepo='*' --enablerepo='epel' makecache
grep -nE 'download\.example' /etc/yum.repos.d/epel.repo
