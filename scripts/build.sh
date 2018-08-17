#!/bin/bash
set -e
[[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" ]] && set -x

cd "$(readlink -f "$(dirname "${BASH_SOURCE}")")"/..

BUILD_DATE=$( date --iso-8601=seconds --utc )
BASE="homeautomationstack/dhas-pki-${ARCH}_linux"

if [[ -n "${ARCH}" && "${ARCH}" != "amd64" ]]; then
  if [ "${ARCH}" != "i386" ]; then
    echo "Starting QEMU environment for multi-arch build ..."
    docker run --rm --privileged --name qemu multiarch/qemu-user-static:register --reset
  fi
fi

IMAGE_VERSION=$(git describe --tags --dirty --match "v[0-9]*")
IMAGE_VERSION=${IMAGE_VERSION:1}
IMAGE_BRANCH=$( [[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" && "${TRAVIS_BRANCH}" != "${TRAVIS_TAG}" ]] && echo -n "${TRAVIS_BRANCH}" || echo -n "" )
VARIANT="${IMAGE_VERSION}$( [ -n "${IMAGE_BRANCH}" ] && echo -n "-${IMAGE_BRANCH}" || echo -n "" )"

echo -e "\n\nNow building variant ${VARIANT} ...\n\n"

# Only run build if not existing on Docker hub yet
function docker_tag_exists() {
  set +x
  TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKER_USER}'", "password": "'${DOCKER_PASS}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
  EXISTS=$(curl -s -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/$1/tags/?page_size=10000 | jq -r "[.results | .[] | .name == \"$2\"] | any")
  [[ -n "${TRAVIS_BRANCH}" && "${TRAVIS_BRANCH}" != "master" ]] && set -x
  test $EXISTS = true
}
if docker_tag_exists ${BASE} ${VARIANT}; then
  echo "Variant ${VARIANT} already existig on Docker Hub - skipping build."
  continue
fi

# Detect rolling tag for this build
if [ -n "${TRAVIS_BRANCH}" ]; then
  if [ "${TRAVIS_BRANCH}" == "master" ] || [ "${TRAVIS_BRANCH}" == "${TRAVIS_TAG}" ]; then
    TAG="latest"
  else
    TAG="${TRAVIS_BRANCH}"
  fi
else
  TAG="latest"
fi

# Check for image availability on Docker hub registry
if docker_tag_exists ${BASE} ${TAG}; then
  echo "Found prior build ${BASE}:${TAG} on Docker Hub registry"
  CACHE_TAG=${TAG}
  docker pull "${BASE}:${CACHE_TAG}"
else
  echo "No prior build found for ${BASE}:${TAG} on Docker Hub registry"
fi

docker build \
  $( [ -n "${CACHE_TAG}" ] && echo -n "--cache-from "${BASE}:${CACHE_TAG}"" ) \
  --tag "${BASE}:${VARIANT}" \
  --build-arg ARCH=${ARCH} \
  --build-arg PLATFORM="linux" \
  --build-arg BUILD_DATE=${BUILD_DATE} \
  --build-arg TAG=${VARIANT} \
  --build-arg TAG_ROLLING=${TAG} \
  --build-arg IMAGE_VERSION=${VARIANT} \
  --build-arg IMAGE_VCS_REF=${TRAVIS_COMMIT} \
  --build-arg VCS_REF=${REVISION} \
  .

# Add rolling tag to this build
[ -n "${TAG}" ] && docker tag "${BASE}:${VARIANT}" "${BASE}:${TAG}"

exit 0
