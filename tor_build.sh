#!/bin/bash

#####
# This is a script to pull Tor git repo, ask for tag to build, verify its signature
# and build the respective RPMs for architectures selected below.
#
# arg1 - tag name to build; if not given, script will display latest tags and prompt
#
# Recognized parameters:
# -h --help     help
# -p            do not pull the repo in $CLEAN_GIT (useful when we have local branch)

#####
# Settings

# These envvars must be set by caller's environment, otherwise
# check_env_settings() will complain:
#
#  WORKDIR, CLEAN_GIT, WATCHED_TAG_RE
#
# Sample setting for the above variables:
# - directory where we can create some temp dirs
#   WORKDIR=~/TorBuildWorkspace/
#
# - existing unmodified cloned repo, doesn't have to be up-to-date
#   CLEAN_GIT="$WORKDIR/Tor.git.rpm-release-0.2.3-branch"
#
# - perl-style regexp for grepping tags we are interested in
#   WATCHED_TAG_RE='^rpm-tor-0\.2\.3\.\d+(-[^-]*)?$'

#new-style rpms must support newer hashes like SHA256 in signatures and checksums
NEW_STYLE_RPMS="epel-6-x86_64 epel-6-i386 fedora-17-x86_64 fedora-17-i386 fedora-16-x86_64 fedora-16-i386"
OLD_STYLE_RPMS="epel-5-x86_64 epel-5-i386"

#This should be almost always 'yes', but it may be useful to use 'no' if you make 
#non-substantial change like increasing %specver to fix a build bug on already
#published rpm.
#The default below sets it to yes unless overridden in shell this script is run like
#VERIFY_TAG=no ./this_script
VERIFY_TAG=${VERIFY_TAG-yes}

#### End settings

function check_env_settings()
{
    if [ -z "$WORKDIR" -o -z "$CLEAN_GIT" -o -z "$WATCHED_TAG_RE" ]; then
        cat<<END
Envvar settings not set, we see (apostrophes added):

        WORKDIR         : '$WORKDIR'
        CLEAN_GIT       : '$CLEAN_GIT'
        WATCHED_TAG_RE  : '$WATCHED_TAG_RE'
END
    exit 3
    fi
}

function usage()
{
cat <<ENDUSAGE
Builds RPMs for Tor using mock. See README-Tor_build_environment

Usage: tor_build.sh [-p] [tag_to_build]

If tag is not specified, script will ask.

Parameters:
 -p            do not pull the repo in CLEAN_GIT (useful when we have local branch)
ENDUSAGE
}

#Exit with error code 2, args are passed to echo
function fatal()
{
    echo $@ 1>&2
    exit 2
}

#Clone repo into directory named in arg1
function prepare_repo()
{
    #checkout tag, verify signature
    REPO_CLONE="$1"
    git clone "$CLEAN_GIT" "$REPO_CLONE" || fatal "Repo clone to working copy failed"
    cd "$REPO_CLONE"
    git checkout -q "$TAG" || fatal "Failed to checkout tag $TAG"

    if [ '!' "$VERIFY_TAG" = "no" ]; then
        git tag -v "$TAG" || fatal "Verification of $TAG signature failed"
    fi
}

#Build source rpm, then rebuild with mock for each architecture given in args
#args - architecture config names (e.g. epel-6-x86_64; look in /etc/mock)
function build_rpms()
{
    #build initial source rpm
    LIBS=-lrt && ./autogen.sh && ./configure && make dist-rpm || fatal "Failed to build initial RPM"

    CONFIGS=$@
    for CONFIG in $CONFIGS; do
        echo ">>> Going to build RPMs for $CONFIG"
        mock -r "$CONFIG" *.src.rpm
        echo "=== Finished building RPMs for $CONFIG, error code: $?"
        if [ $? = 0 ]; then
            RPMS_SUCCESSFUL=$((RPMS_SUCCESSFUL+1))
        else
            RPMS_FAILED=$((RPMS_FAILED+1))
        fi
    done
}

#Copy resulting RPMs from /var/lib/mock/*/result to destdir
#arg1 - dest dir for the RPMs
#arg[2..n] - architecture config names (e.g. epel-6-x86_64; look in /etc/mock)
function copy_resulting_rpms()
{
    DESTDIR="$1"
    shift
    CONFIGS=$@

    for CONFIG in $CONFIGS; do
        cp -a /var/lib/mock/"$CONFIG"/result/*.rpm "$DESTDIR"
    done
}

#####
# __main__ begin

RPMS_SUCCESSFUL=0
RPMS_FAILED=0
PULL_REPO=yes

if [ "$1" = "-h" -o "$1" = "--help" ]; then
    usage
    exit 1
fi

check_env_settings

if [ "$1" = "-p" ]; then
    PULL_REPO=no
    shift
fi

#pull the repo up-to-date
cd "$CLEAN_GIT" || fail "Cannot enter directory $CLEAN_GIT"
if [ "$PULL_REPO" = "yes" ]; then 
    git pull || fatal "Git pull failed"
fi

if [ -z "$1" ]; then
    #print the tag list with tagged date
    echo "=== Latest tags sorted from newest:"
    git for-each-ref --format="%(refname)" --sort=-taggerdate refs/tags | cut -f 3 -d / | grep -P "$WATCHED_TAG_RE" | head -n 10

    LATEST=$(git for-each-ref --format="%(refname)" --sort=-taggerdate refs/tags | cut -f 3 -d / | grep -P "$WATCHED_TAG_RE" | head -n 1)
    echo "Select one, inputting empty string will default to the latest tag $LATEST"
    read TAG

    if [ -z "$TAG" ]; then
        TAG="$LATEST"
    fi
else
    TAG="$1"
fi

echo "Going to build tag $TAG"


DATE=$(date "+%Y-%m-%d")
TORDIR=$(mktemp -d "$WORKDIR/tor_$DATE_$TAG.XXXX")
RESULTDIR="$TORDIR.result"
TORDIR_OLDRPM="$TORDIR.old_style_rpm"
mkdir -p "$RESULTDIR"
mkdir -p "$TORDIR_OLDRPM"

echo " === Build dir is $TORDIR, results will be in $RESULTDIR === "

#new style RPMs
prepare_repo "$TORDIR"
build_rpms $NEW_STYLE_RPMS
copy_resulting_rpms "$RESULTDIR" $NEW_STYLE_RPMS

#old style RPMs - changing RPMBUILD is how we force the old checksums in
export RPMBUILD=rpmbuild-md5
prepare_repo "$TORDIR_OLDRPM"
build_rpms $OLD_STYLE_RPMS
copy_resulting_rpms "$RESULTDIR" $OLD_STYLE_RPMS

echo "=== Final stats ==="
echo "Successful: $RPMS_SUCCESSFUL"
echo "Failed: $RPMS_FAILED"

#rm -rf "$TORDIR"
