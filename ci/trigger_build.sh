#!/usr/bin/env bash

set -e

repo_slug=$1

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
          "SDK": "ruby",
          "COMPOSE_PROJECT_NAME": "fullstack-compat-${TRAVIS_BRANCH}-${TRAVIS_BUILD_NUMBER}-ruby",
        }
      },
      "before_script": "STATE=pending ci/update_build_status.sh",
      "script": ["ci/before_install.sh", "./ci.sh"],
      "after_success": "STATE=success ci/update_build_status.sh",
      "after_failure": "STATE=failure ci/update_build_status.sh"
    }
  }
}
EOF
)

REPO="https://api.travis-ci.com/repo/$repo_slug/requests"

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Travis-API-Version: 3" \
  -H "Authorization: token $TRAVIS_COM_TOKEN" \
  -d "$body" \
  $REPO
