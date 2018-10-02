#!/usr/bin/env bash

set -ex

. "./ci/functions.sh"

repo="optimizely/fullstack-sdk-compatibility-suite"
id=$(trigger_job $repo)
