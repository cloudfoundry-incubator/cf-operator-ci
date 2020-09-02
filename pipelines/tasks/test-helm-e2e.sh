#!/usr/bin/env sh

exec 3> `basename "$0"`.trace
BASH_XTRACEFD=3

set -eux

: "${ibmcloud_apikey:?}"
: "${ibmcloud_server:?}"
: "${ibmcloud_region:?}"
: "${ibmcloud_cluster:?}"
: "${OPERATOR_TEST_STORAGE_CLASS:?}"
: "${DOCKER_IMAGE_REPOSITORY:?}"

export PATH=$PATH:$PWD/bin
export GOPATH=$PWD
export TEST_NAMESPACE="test$(date +%s)"

upload_debug_info() {
  if ls /tmp/env_dumps/* &> /dev/null; then
    cd $GOPATH 
    TARBALL_NAME="env_dump-$(date +"%s").tar.gz"
    echo "Env dumps will be uploaded as ${TARBALL_NAME}"
    tar cfzv env_dumps/"$TARBALL_NAME" -C /tmp/env_dumps/ .
  fi
}

cleanup () {
  upload_debug_info
}
trap cleanup EXIT

echo "Setting up bluemix access"
ibmcloud login -r "$ibmcloud_region" -a "$ibmcloud_server" --apikey "$ibmcloud_apikey"
export BLUEMIX_CS_TIMEOUT=500
ibmcloud ks cluster config --cluster "$ibmcloud_cluster"

cd src/code.cloudfoundry.org/quarks-operator

bin/tools
bin/build-helm

echo "Running e2e tests in the ${ibmcloud_cluster} cluster."
echo "--------------------------------------------------------------------------------"
bin/test-helm-e2e
echo "Running e2e storage tests in the ${ibmcloud_cluster} cluster."
echo "--------------------------------------------------------------------------------"
export TEST_NAMESPACE="test-storage$(date +%s)"
bin/test-helm-e2e-storage
