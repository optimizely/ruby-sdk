# helper functions

function trigger_job {

  local repo_slug=$1

  local body=$(cat <<EOF
{
  "request": {
    "message": "Override the commit message: this is an api request",
    "branch": "jtong/travisci",
    "config": {
      "sudo": "required",
      "merge_mode": "replace",
      "env": {
        "global": {
          "UPSTREAM_SHA": "${TRAVIS_PULL_REQUEST_SHA}",
          "UPSTREAM_REPO": "${TRAVIS_PULL_REQUEST_SLUG}",
          "DOCKER_COMPOSE_VERSION": "1.22.0",
          "DEFAULT_RUN_ALL": false,
          "DEFAULT_SDK_BRANCH": "master",
          "DEFAULT_TESTAPP_TAG": "latest",
          "TESTAPP_IMAGE": "",
          "TESTAPP_REPO": "quay.io/optimizely",
          "PERF": false,
          "PERF_NUM_RUNS": 50,
          "RESULTS_DIR": "./test_results",
          "SDK": "ruby",
          "COMPOSE_PROJECT_NAME": "fullstack-compat-${TRAVIS_BRANCH}-${TRAVIS_BUILD_NUMBER}-${SDK}",
          "TESTAPP_PORT_BINDING": 3000
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

local REPO="https://api.travis-ci.com/repo/$repo_slug/requests"

curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Travis-API-Version: 3" \
  -H "Authorization: token $TRAVIS_COM_TOKEN" \
  -d "$body" \
  $REPO
}
