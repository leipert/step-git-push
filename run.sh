#!/bin/sh
set -e
set +o pipefail

# LOAD OUR FUNCTIONS
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${DIR}/functions.sh

# Start work
for variable in $(getAllStepVars)
do
  if [ "${!variable}" == "false" ]; then
    s_info "\"$variable\" was set to false, we will unset it therefore"
    unset $variable
  fi
done

if [ -n "$WERCKER_GIT_PUSH_GH_TOKEN" ]; then
  setMessage "Your gh_token may be compromised. Please check https://github.com/leipert/step-git-push for more info"
  fail "Your gh_token may be compromised. Please check https://github.com/leipert/step-git-push for more info"
fi

repo=$(getRepoPath)

info "using github repo \"$repo\""

remoteURL=$(getRemoteURL)
if [ -z $remoteURL ]; then
  s_fail "missing option \"gh_oauth\" or \"host\", aborting"
fi
s_info "remote URL will be $remoteURL"

baseDir=$(getBaseDir)

# setup branch
remoteBranch=$(getBranch)

cd $baseDir
rm -rf .git

localBranch="master"

# remove existing files
targetDir="/tmp/git-push"
rm -rf $targetDir

destDir=$targetDir

if [ -n "$WERCKER_GIT_PUSH_DESTDIR" ]; then
  destDir=$targetDir/$WERCKER_GIT_PUSH_DESTDIR
fi

s_debug "before init"

# init repository
if [ -n "$WERCKER_GIT_PUSH_DISCARD_HISTORY" ]; then
  initEmptyRepoAt $targetDir
else
  cloneRepo $remoteURL $targetDir
  if checkBranchExistence $targetDir $remoteBranch; then
    checkoutBranch $targetDir $remoteBranch
    localBranch=$remoteBranch
    s_info "branch $remoteBranch exists on remote $remoteURL"
  else
    initEmptyRepoAt $targetDir
  fi
fi

info "Initialized Repo in $targetDir"

cd $targetDir
mkdir -p $destDir

cd $destDir

echo $destDir $targetDir

s_debug "before clean"

if [ -n "$WERCKER_GIT_PUSH_CLEAN_REMOVED_FILES" ]; then
  info "We will clean in $destDir"
  ls -A | grep -v .git | xargs rm -rf
  mkdir -p $destDir
fi

cd $targetDir

ls -A

cp -rf $baseDir* $destDir

s_debug "before config"

git config user.email "pleasemailus@wercker.com"
git config user.name "werckerbot"

# generate cname file
createCNAME $targetDir
s_debug "base:" $baseDir: `ls -A $baseDir`
s_debug "target:" $targetDir: `ls -A $targetDir`
s_debug "dest:" $destDir: `ls -A $destDir`

tag=$WERCKER_GIT_PUSH_TAG
s_debug "before tagExtraction: $tag"

tag=$(getTag $tag $targetDir/)
s_debug "Tag after targetDir $tag"
tag=$(getTag $tag $destDir/)
s_debug "Tag after destDir $tag"
tag=$(getTag $tag $baseDir/)
s_debug "Tag after baseDir $tag"

if [ -n "$tag" ]; then
  s_info "The commit will be tagged with $tag"
fi

cd $targetDir

git add --all . > /dev/null

if git diff --cached --exit-code --quiet; then
  s_success "Nothing changed. We do not need to push"
else
  git commit -am "[ci skip] deploy from $WERCKER_STARTED_BY" --allow-empty > /dev/null
  pushBranch $remoteURL $localBranch $remoteBranch
fi

if [ -n "$WERCKER_GIT_PUSH_TAG" ]; then
  tags="$(git tag -l)"
  if [[ "$tags" =~ "$tag" ]]; then
    s_info "tag $tag already exists"
    if [ -n "$WERCKER_GIT_PUSH_TAG_OVERWRITE" ]; then
      if git diff --exit-code --quiet $localBranch $tag; then
        s_success "Nothing changed. We do not need to overwrite tag $tag"
      else
        s_info "tag $tag will be overwritten"
        deleteTag $remoteURL $tag
        pushTag $remoteURL $tag
      fi
    fi
  else
      pushTag $remoteURL $tag
  fi
fi


s_debug "before unset"

for variable in $(getAllStepVars)
do
  unset $variable
done
