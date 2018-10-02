#!/usr/bin/env bash

. "./functions.sh"

repo="optimizely/fullstack-sdk-compatibility-suite"
id=$(trigger_job $repo)
