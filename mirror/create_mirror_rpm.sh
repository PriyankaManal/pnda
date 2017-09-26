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

yum install -y createrepo
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

# yumdownloader doesn't download dependencies that are already installed, for instance if git is installed, it won't download perl
# To enumerate the dependencies reliably therefore, repoquery is used to generate the set of packages to download
# Additionally, the cloudera packages cannot be processed by repoquery when the main repos are enabled (unsure as to the reason) so
# these are handled separately, with the main repos disabled.
RPM_PACKAGE_LIST_CM=$(echo "$RPM_PACKAGE_LIST" | grep cloudera)
RPM_PACKAGE_LIST=$(echo "$RPM_PACKAGE_LIST" | grep -v cloudera)
echo "number of non-Cloudera RPMS:"
echo "$RPM_PACKAGE_LIST" | wc -l
echo "number of Cloudera RPMS:"
echo "$RPM_PACKAGE_LIST_CM" | wc -l

RPM_PACKAGE_LIST_DEPS=$(repoquery --arch=x86_64 --requires --resolve --recursive $RPM_PACKAGE_LIST)
echo "number of non-Cloudera dependency RPMS:"
echo "$RPM_PACKAGE_LIST_DEPS" | wc -l

yum-config-manager --disable rhui-REGION-client-config-server-7 rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional rhui-REGION-rhel-server-releases rhui-REGION-rhel-server-rh-common
RPM_PACKAGE_LIST_DEPS_CM=$(repoquery --arch=x86_64 --requires --resolve --recursive $RPM_PACKAGE_LIST_CM)
echo "number of Cloudera dependency RPMS:"
echo "$RPM_PACKAGE_LIST_DEPS_CM" | wc -l
yum-config-manager --enable rhui-REGION-client-config-server-7 rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional rhui-REGION-rhel-server-releases rhui-REGION-rhel-server-rh-common

RPM_PACKAGE_LIST_ALL="$RPM_PACKAGE_LIST $RPM_PACKAGE_LIST_DEPS $RPM_PACKAGE_LIST_DEPS_CM"
RPM_PACKAGE_LIST_ALL=$(echo "$RPM_PACKAGE_LIST_ALL" | sort | uniq)
echo "Total number of RPMS:"
echo "$RPM_PACKAGE_LIST_ALL" | wc -l
(yumdownloader --archlist=x86_64 --destdir $RPM_REPO_DIR $RPM_PACKAGE_LIST_ALL 2>&1) | tee -a yum-downloader.log; cmd_result=${PIPESTATUS[0]} && if [ ${cmd_result} != '0' ]; then exit ${cmd_result}; fi
if grep -q 'No Match for argument' "yum-downloader.log"; then
    echo "missing rpm detected:"
    echo $(cat yum-downloader.log | grep 'No Match for argument')
    exit -1
fi
rm yum-downloader.log
createrepo --database $RPM_REPO_DIR
