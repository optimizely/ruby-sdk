# helper functions

function trigger_job {

  local repo_slug=$1

  local body=$(cat <<EOF
{
  "request": {
    "message": "Override the commit message: this is an api request",
    "branch": "jtong/travisci",
    "config": {
      "merge_mode": "replace",
      "env": {
        "UPSTREAM_SHA": "$TRAVIS_PULL_REQUEST_SHA",
        "UPSTREAM_REPO": "$TRAVIS_PULL_REQUEST_SLUG",
        "global": {
          "DOCKER_COMPOSE_VERSION": "1.22.0",
          "DEFAULT_RUN_ALL": false,
          "DEFAULT_SDK_BRANCH": "master",
          "DEFAULT_TESTAPP_TAG": "latest",
          "TESTAPP_IMAGE": "",
          "TESTAPP_REPO": "quay.io/optimizely",
          "PERF": false,
          "PERF_NUM_RUNS": 50,
          "RESULTS_DIR": "./test_results",
          "COMPOSE_PROJECT_NAME": "fullstack-compat-${TRAVIS_BRANCH}-${TRAVIS_BUILD_NUMBER}",
          "TESTAPP_PORT_BINDING": 3000
        },
        "matrix": {
          "COMPOSE_PROJECT_NAME": "${COMPOSE_PROJECT_NAME}-ruby"
        }
      },
      "before_script": "STATE=pending ./update_build_status.sh",
      "script": ["./ci.sh"],
      "after_success": "STATE=success ./update_build_status.sh",
      "after_failure": "STATE=failure ./update_build_status.sh"
    }
  }
}
EOF
)

echo $body

local REPO="https://api.travis-ci.com/repo/$repo_slug/requests"

local results=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -H "Travis-API-Version: 3" \
  -H "Authorization: token $TOKEN" \
  -d "$body" \
  $REPO)

echo $results

echo $results | jq .id
