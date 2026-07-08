#!/bin/bash

BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE_BRANCH="$BRANCH"
BRANCH_ON_REMOTE=false
LOCAL_BRANCH_EXISTS=false
