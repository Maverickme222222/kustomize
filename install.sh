#!/bin/bash

set -eEu -o pipefail

# This script will parse a list of applications in the Kappa dev environment,
# and generate a new tagged release for any applications that have untagged
# commits.
#
# Required environment variables:
#
# * GITHUB_TOKEN - an authorised token that has permissions to checkout, tag
#   and raise pull requests against Kappa private repos
#
# Required tools installed:
#
# * yq v.4+

GITHUB_TOKEN=${GITHUB_TOKEN}
GITHUB_ORG="kappapay"

# Define some colours so we can log slightly more noticeable messages
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

trap 'echo "** FATAL: Something went wrong - exiting"' ERR

# github_release requests a release/tag from the Github API
function github_release {
  local org=${1}
  local repo=${2}
  local tag=${3}

  read -r -d '' BODY <<- EOF || true
  {
    "tag_name": "${new_tag}",
    "name": "${new_tag}",
    "generate_release_notes": true
  }
EOF

  echo ${BODY} | curl -s -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d @- \
    https://api.github.com/repos/${org}/${repo}/releases
}

# github_create_pull_request requests a new pull request from the Github API.
# It assumes a branch with changes has been pushed.
function github_create_pull_request {
  local org=${1}
  local repo=${2}
  local branch=${3}

  read -r -d '' BODY <<- EOF | true
  {
    "title": "Release Kappa Applications",
    "head": "${branch}",
    "body": "This pull request tags and releases Kappa apps that have new commits since the last release cycle.",
    "base": "main"
  }
EOF

  echo ${BODY} | curl -s -L \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -d @- \
    https://api.github.com/repos/${org}/${repo}/pulls
}

# tag_repo expects to be called with cwd set to a checked out repo. It will
# determine the current latest tag, then increment the appropriate part of the
# semver, and push a release via the Github API
function tag_repo {
    local application=${1}
    local repo=${2}
    local container_image_key=${3}

    local latest_commit=$(git rev-parse HEAD)
    local current_main_image=$(yq ".images.${container_image_key}.main" ${CONTAINER_IMAGES})

    # Check whether we can lookup an image in the images file for this
    # application. If we can't, something is very wrong
    if [[ ${current_main_image} == "null" ]]; then
      echo -e "${RED}ERROR:${RESET} Cannot lookup value for ${container_image_key} in ${CONTAINER_IMAGES} - something went wrong - bailing"
      exit 1
    fi

    # It is important to determine the current latest commit in this repo and
    # verify that we have a built image in container-images.yaml. If not, we
    # are either currently building an image, or something has gone wrong with
    # CICD. Either way we should not release.
    if [[ "${latest_commit}" == "${current_main_image}" ]]; then
      local current_tag=$(git tag --sort v:refname | tail -1)
      if [ -z "${current_tag}" ]; then
        current_tag="v0.0.0"
      fi

      # Determine current semver, remove 'v'
      local current_semver=$(echo ${current_tag} | sed -e 's/^v//')

      # Split semver into an array
      local v=(${current_semver//./ })

      # Increment the appropriate part of the semver. Note use of ++var - because
      # we are in set -e mode here we must increment before returning to avoid
      # throwing an error
      if [[ ${RELEASE_TYPE} == 'major' ]]
      then
        ((++v[0]))
        v[1]=0
        v[2]=0
      elif [[ ${RELEASE_TYPE} == 'minor' ]]
      then
        ((++v[1]))
        v[2]=0
      elif [[ ${RELEASE_TYPE} == 'patch' ]]
      then
        ((++v[2]))
      else
        # We should never get to this point - we verify these values at startup
        exit 1
      fi

      new_tag="v${v[0]}.${v[1]}.${v[2]}"

      # We generate a release by posting to the Github API - that way we can generate release notes
      # github_release ${GITHUB_ORG} $repo $new_tag

      # Assuming tagging succeeds, let's modify the container-images file to contain our new tag
      yq -i ".images.${container_image_key}.[\"${new_tag}\"] = \"${latest_commit}\"" ${CONTAINER_IMAGES}
      echo -e "${GREEN}TAG:${RESET} Bumped ${repo} from ${current_tag} to ${new_tag} (commit ${latest_commit})"
  else
    echo -e "${RED}ERROR:${RESET} Current main image for ${repo} has hash ${current_main_image} which does not match proposed tagged commit of ${latest_commit}. Possible ongoing build - bailing${RESET}"
    exit 1
  fi

}

# process_repo will check out a given Kappa repository and determine if it
# requires tagging. If so, we pass to tag_repo()
function process_repo {
  local application=${1}
  local repo=${2}
  local container_image_key=${3}

  local temp_dir=$(mktemp -d)

  git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_ORG}/${repo}" ${temp_dir} 2> /dev/null

  pushd ${temp_dir} >/dev/null
  local tag_with_head=$(git tag --contains HEAD)

  # If git returns a tag which contains the commit on HEAD, no need to do
  # antying. If it doesn't return anything that tells us there is at least 1
  # untagged commnit, and we should proceed with releasing the repo.
  if [ -z "${tag_with_head}" ]; then
    tag_repo ${application} ${repo} ${container_image_key}
  else
    echo "SKIP: ${repo} doesn't need tagging"
  fi

  popd >/dev/null
}

## Begin main

# Determine and validate params
while getopts t: opt
do
  case "${opt}" in
    t) RELEASE_TYPE=${OPTARG};;
  esac
done

if [[ "${RELEASE_TYPE}" != "major" ]] && [[ ${RELEASE_TYPE} != "minor" ]] && [[ ${RELEASE_TYPE} != "patch" ]]; then
  echo "Release type (-t) must be one of: major, minor, patch"
  exit 1
fi

# Checkout a fresh copy of the ArgoCD repo
ARGOCD_REPO_ROOT=$(mktemp -d)
echo "SETUP: Cloning Kappa ArgoCD repo into ${ARGOCD_REPO_ROOT}"
git clone "https://${GITHUB_TOKEN}@github.com/${GITHUB_ORG}/argocd" ${ARGOCD_REPO_ROOT} 2> /dev/null

BRANCH_NAME=Release/$(date +%Y%m%d%H%M%S)
echo "SETUP: Checking out branch ${BRANCH_NAME} for committing changes to container-images.yaml"
cd ${ARGOCD_REPO_ROOT}
git checkout -b ${BRANCH_NAME} 2>/dev/null

# Read list of applications in QA to determine which apps are candidates for
# tagging
# ARGOCD_REPO_ROOT="${HOME}/src/kappapay/argocd"
APPLICATION_PATH=${ARGOCD_REPO_ROOT}/applications/dev
CONTAINER_IMAGES=${ARGOCD_REPO_ROOT}/services/values-images.yaml

if [ ! -f "${CONTAINER_IMAGES}" ]; then
  echo "${CONTAINER_IMAGES} file does not exist - something went wrong - exiting"
  exit 1
fi

# For each application, determine the github repo by reading the appropriate
# annotation
for app_file in ${APPLICATION_PATH}/application-kappa-*; do
  application=$(yq ".metadata.name" ${app_file})
  application_repository=$(yq ".metadata.annotations.[\"kappapay.com/repository\"]" ${app_file})
  application_container_image_key=$(yq ".metadata.annotations.[\"kappapay.com/containerImageKey\"]" ${app_file})
  if [[ "${application_repository}" == "null" ]]; then
    echo "SKIP: No repo found for ${application}"
    continue
  fi
  process_repo ${application} ${application_repository} ${application_container_image_key}
done

echo "PUSH: Pushing new version of container-images.yaml on branch ${BRANCH_NAME}"
echo "ArgoCD repo: ${ARGOCD_REPO_ROOT}"
# git add .
# git commit -m 'Releasing new tagged images from branch ${BRANCH_BAME}'
# git push
