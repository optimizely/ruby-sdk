#!/usr/bin/env bash

set -xe

. "./ci/functions.sh"

repo="optimizely%2Ffullstack-sdk-compatibility-suite"
id=$(trigger_job $repo)
