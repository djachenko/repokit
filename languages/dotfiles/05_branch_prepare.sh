#!/bin/bash

# shellcheck disable=SC2034  # variables are set for the parent shell via source
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE_BRANCH="$BRANCH"
BRANCH_ON_REMOTE=false
LOCAL_BRANCH_EXISTS=false
