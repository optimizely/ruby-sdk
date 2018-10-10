#!/usr/bin/env bash

set -e

repo_slug=$1

# why travis creates two builds for every commit push:
# https://stackoverflow.com/questions/34974925/travis-ci-creates-two-builds-for-each-github-commit-push
#
# one build is event type "push", the other is event type "pull request" we can only use the latter type
if [ "$TRAVIS_EVENT_TYPE" == "push" ]; then
  echo "push events do not set values for TRAVIS_PULL_REQUEST_SHA or TRAVIS_PULL_REQUEST_SLUG so there's no point triggering build without these values"
  exit 1
elif [ "$TRAVIS_EVENT_TYPE" == "pull_request" ]; then
  echo "pull_request event detected. continuing..."
else
  echo "i do not understand TRAVIS_EVENT_TYPE=$TRAVIS_EVENT_TYPE"
  exit 2
fi

body=$(cat <<EOF
{
  "request": {
    "message": "Override the commit message: this is an api request",
    "branch": "jtong/travisci",
    "config": {
      "sudo": "required",
      "merge_mode": "deep_merge",
      "env": {
        "global": {
          "UPSTREAM_SHA": "${TRAVIS_PULL_REQUEST_SHA}",
          "UPSTREAM_REPO": "${TRAVIS_PULL_REQUEST_SLUG}",
          "SDK": "${SDK}"
        },
        "matrix": {
          "COMPOSE_PROJECT_NAME": "fullstack-compat-${TRAVIS_BRANCH}-${TRAVIS_BUILD_NUMBER}-${SDK}"
        }
      },
      "install": ["ci/install.sh"],
      "script": ["./ci.sh"],
      "after_success": "STATE=success ci/update_build_status.sh",
      "after_failure": "STATE=failure ci/update_build_status.sh"
    }
  }
}
EOF
)

REPO="https://api.travis-ci.com/repo/$repo_slug/requests"

output=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Travis-API-Version: 3" \
  -H "Authorization: token $TRAVIS_COM_TOKEN" \
  -d "$body" \
  $REPO
)

if [[ "$output" == *"error"* ]]; then
  exit 1
fi
