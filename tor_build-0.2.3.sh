#!/bin/bash

CONFIG_NAME="Build 0.2.3 branch"
CONFIG_BASE_FNAME="rpm-release-0.2.3"

# directory where we can create some temp dirs
export WORKDIR="/home/makerpm/TorBuildWorkspace"
# existing unmodified cloned repo, doesn't have to be up-to-date
export CLEAN_GIT="/home/makerpm/TorBuildRepos/Tor.git.rpm-release-allbranches/"

#perl-style regexp for grepping tags we are interested in
export WATCHED_TAG_RE='^rpm-tor-0\.2\.3\.\d+(-[^-]*)?$'

# we created the rpm-tor-* tag
export VERIFY_TAG=no

BUILD_SCRIPT="${0%/*}/tor_build.sh"
TIMESTAMP=$(date +'%Y-%m-%d_%H.%M.%S')
BUILD_LOG="$WORKDIR/$CONFIG_BASE_FNAME-$TIMESTAMP.log" #doesn't matter much it can be nonunique

cat<<END
== Tor_build CONFIG: $CONFIG_NAME ==
    Settings:

        WORKDIR         : '$WORKDIR'
        CLEAN_GIT       : '$CLEAN_GIT'
        WATCHED_TAG_RE  : '$WATCHED_TAG_RE'

Exec'ing $BUILD_SCRIPT
Tee'ing output to $BUILD_LOG
END

exec "$BUILD_SCRIPT" -p 2>&1 | tee "$BUILD_LOG"
