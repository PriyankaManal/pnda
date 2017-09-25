#!/bin/bash -ev
export DISTRO=$(cat /etc/*-release|grep ^ID\=|awk -F\= {'print $2'}|sed s/\"//g)

[[ -z ${MIRROR_BUILD_DIR} ]] && export MIRROR_BUILD_DIR=${PWD}
[[ -z ${MIRROR_OUTPUT_DIR} ]] && export MIRROR_OUTPUT_DIR=${PWD}/mirror-dist

RPM_PACKAGE_LIST=$(<${MIRROR_BUILD_DIR}/dependencies/pnda-rpm-package-dependencies.txt)

RPM_REPO_DIR=$MIRROR_OUTPUT_DIR/mirror_rpm
RPM_EXTRAS=rhui-REGION-rhel-server-extras
RPM_OPTIONAL=rhui-REGION-rhel-server-optional
RPM_EPEL=https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
MY_SQL_REPO=https://repo.mysql.com/yum/mysql-5.5-community/el/7/x86_64/
MY_SQL_REPO_KEY=https://repo.mysql.com/RPM-GPG-KEY-mysql
CLOUDERA_MANAGER_REPO=http://archive.cloudera.com/cm5/redhat/7/x86_64/cm/5.9.0/
CLOUDERA_MANAGER_REPO_KEY=https://archive.cloudera.com/cm5/redhat/7/x86_64/cm/RPM-GPG-KEY-cloudera
SALT_REPO=https://repo.saltstack.com/yum/redhat/7/x86_64/archive/2015.8.11
SALT_REPO_KEY=https://repo.saltstack.com/yum/redhat/7/x86_64/archive/2015.8.11/SALTSTACK-GPG-KEY.pub
SALT_REPO_KEY2=http://repo.saltstack.com/yum/redhat/7/x86_64/2015.8/base/RPM-GPG-KEY-CentOS-7
AMBARI_REPO=http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.5.1.0/ambari.repo
AMBARI_REPO_KEY=http://public-repo-1.hortonworks.com/ambari/centos7/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins

yum install -y $RPM_EPEL || true
yum-config-manager --enable $RPM_EXTRAS $RPM_OPTIONAL
yum-config-manager --add-repo $MY_SQL_REPO
yum-config-manager --add-repo $CLOUDERA_MANAGER_REPO
yum-config-manager --add-repo $SALT_REPO
yum-config-manager --add-repo $AMBARI_REPO

yum install -y yum-plugin-downloadonly createrepo
rm -rf $RPM_REPO_DIR
mkdir -p $RPM_REPO_DIR

cd $RPM_REPO_DIR
cp /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7 $RPM_REPO_DIR
cp /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release $RPM_REPO_DIR
curl -LOJf $MY_SQL_REPO_KEY
curl -LOJf $CLOUDERA_MANAGER_REPO_KEY
curl -LOJf $SALT_REPO_KEY
curl -LOJf $SALT_REPO_KEY2
curl -LOJf $AMBARI_REPO_KEY

RPM_CHROOT_DIR=/tmp/pnda_rpm_root/
rm -rf $RPM_CHROOT_DIR
mkdir $RPM_CHROOT_DIR

(yum install --nogpg --downloadonly --downloaddir=$RPM_REPO_DIR --installroot=$RPM_CHROOT_DIR --releasever=/ --setopt=protected_multilib=false $RPM_PACKAGE_LIST 2>&1) | tee -a yum-download.log; cmd_result=${PIPESTATUS[0]} && if [ ${cmd_result} != '0' ]; then exit ${cmd_result}; fi
if grep -q 'No package ' "yum-download.log"; then
    echo "missing rpm detected:"
    echo $(cat yum-download.log | grep 'No package ')
    exit -1
fi
rm yum-download.log
createrepo --database $RPM_REPO_DIR
