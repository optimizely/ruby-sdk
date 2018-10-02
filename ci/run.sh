#!/usr/bin/env bash

. "./ci/functions.sh"

repo="optimizely/fullstack-sdk-compatibility-suite"
id=$(trigger_job $repo)
