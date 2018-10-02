#!/usr/bin/env bash

. "./ci/functions.sh"

repo="optimizely%2Ffullstack-sdk-compatibility-suite"
id=$(trigger_job $repo)
