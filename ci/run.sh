#!/usr/bin/env bash

set -ex

. "./ci/functions.sh"

repo="optimizely%2Ffullstack-sdk-compatibility-suite"
id=$(trigger_job $repo)
