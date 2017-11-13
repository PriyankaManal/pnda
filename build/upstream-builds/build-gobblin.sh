VERSION=${1}
ARG=${2}

EXCLUDES="-x test"
set -e
set -x

function error {
    echo "Not Found"
    echo "Please run the build dependency installer script"
    exit -1
}

export LC_ALL=en_US.utf8
HADOOP_VERSION=2.6.0-cdh5.9.0

echo -n "Java 1.8: "
if [[ $($JAVA_HOME/bin/javac -version 2>&1) != "javac 1.8"* ]]; then
    error
else
    echo "OK"
fi

git clone https://github.com/apache/incubator-gobblin
cp -R ../../upstream-builds/dependencies/gobblin-PNDA incubator-gobblin/gobblin-PNDA

# The javadoc generation isn't able to take the proxy setting into consideration,
# so we disable the generation in all submodules for now.
if ! fgrep -q 'tasks.withType(Javadoc).all { enabled = false }' build.gradle; then
cat >> build.gradle << EOF
subprojects {
  tasks.withType(Javadoc).all { enabled = false }
}
EOF
fi

if [ "$1" = "PNDA" ];  then
    VERSION='develop'
fi

mkdir -p pnda-build

cd incubator-gobblin
sed -i "/'gobblin-service',/ a\               \'gobblin-PNDA'," settings.gradle

cd gobblin-distribution
sed -i "/compile project(':gobblin-runtime-hadoop')/ a\ \ compile project(':gobblin-PNDA')" build.gradle
cd ..

./gradlew clean build -Pversion="${VERSION}" -PhadoopVersion="${HADOOP_VERSION}" -PexcludeHadoopDeps -PexcludeHiveDeps ${EXCLUDES}
mv gobblin-distribution-${VERSION}.tar.gz ../pnda-build/
cd ..
sha512sum pnda-build/gobblin-distribution-${VERSION}.tar.gz > pnda-build/gobblin-distribution-${VERSION}.tar.gz.sha512.txt

