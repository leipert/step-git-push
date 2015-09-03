#!/bin/bash
set +e
set -x

failed=false
throwError=false

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
. ${DIR}/../functions.sh

  function error {
      echo ERROR: $@
      throwError=true
  }

  function s_info {
    echo INFO: $@
  }

  function s_warning {
    echo > /dev/null
  }

  function success {
    echo SUCCESS: $@
  }

  function s_fail {
    failed=true
  }

  function fail {
    echo "FATAL: $@"
    exit -1
  }

currDir=$(pwd);

cd $currDir; rm -rf foo

# TEST URL SANITATION
[ $(sanitizeOutput "https://1234@gh") != "https://oauth-token@gh" ] && error "We should replace oauth token in https"
[ $(sanitizeOutput "http://1234@gh") != "http://oauth-token@gh" ] && error "We should replace oauth token in http"
[ $(sanitizeOutput "git://1234:1224@gh") != "git://oauth-token@gh" ] && error "We should replace oauth token in git url"
[ $(sanitizeOutput "git@github.com:leipert/step-git-push.git") != "git@github.com:leipert/step-git-push.git" ] && error "We should not replace oauth token in git url"

WERCKER_GIT_REPOSITORY="step-git-push"
WERCKER_GIT_OWNER="leipert"
WERCKER_GIT_BRANCH="default"

## TEST getRepoPath

WERCKER_GIT_PUSH_REPO="oxofrmbl"

[ $(getRepoPath) != "oxofrmbl" ] && error "$(getRepoPath) != oxofrmbl"

unset WERCKER_GIT_PUSH_REPO;

[ $(getRepoPath) != "leipert/step-git-push" ] && error "$(getRepoPath) != leipert/step-git-push"

## Test getGitSSHUser

WERCKER_GIT_PUSH_USER="foo"

[ $(getGitSSHUser) != "foo" ] && error "$(getGitSSHUser) != foo"

unset WERCKER_GIT_PUSH_USER

[ $(getGitSSHUser) != "git" ] && error "$(getGitSSHUser) != git"

## Test getRemoteURL

[ ! getRemoteURL ] && error "Script should error here"

WERCKER_GIT_PUSH_GH_OAUTH=1234

[ $(getRemoteURL) != "https://1234@github.com/leipert/step-git-push.git" ] && error "$(getRemoteURL) != https://1234@github.com/leipert/step-git-push.git"

unset WERCKER_GIT_PUSH_GH_OAUTH
WERCKER_GIT_PUSH_HOST="github.com"

[ $(getRemoteURL) != "git@github.com:leipert/step-git-push.git" ] && error "$(getRemoteURL) != git@github.com:leipert/step-git-push.git"

## TEST getBranch

[ $(getBranch) != "default" ] && error "$(getBranch) != default"

WERCKER_GIT_PUSH_BRANCH="dist"

[ $(getBranch) != "dist" ] && error "$(getBranch) != dist"

WERCKER_GIT_PUSH_GH_PAGES="true"

[ $(getBranch) != "gh-pages" ] && error "$(getBranch) != gh-pages"

WERCKER_GIT_PUSH_REPO="leipert/leipert.github.io"
[ $(getBranch) != "master" ] && error "$(getBranch) != master"

## TEST getBaseDir

WERCKER_GIT_PUSH_BASEDIR="foo"

[ $(getBaseDir) != $(pwd)/foo/ ] && error "$(getBaseDir) != "$(pwd)/foo/

unset WERCKER_GIT_PUSH_BASEDIR

[ $(getBaseDir) != $(pwd)/ ] && error "$(getBaseDir) != "$(pwd)/

## TEST init empty Repo

#cd $(pwd); rm -rf foo

initEmptyRepoAt $(pwd)/foo
[ ! -d .git ] && error "Could not initialize empty repo"
cd $currDir; rm -rf foo

## Test cloning of repo
if [ -n "$GH_TOKEN" ]; then
  WERCKER_GIT_PUSH_GH_OAUTH="$GH_TOKEN"
else
  WERCKER_GIT_PUSH_HOST="github.com"
fi

WERCKER_GIT_PUSH_REPO="leipert/non-existing"

cloneRepo $(getRemoteURL) $currDir/foo
[ $failed != "true" ] && error "A non existing repository should have not be cloned"
failed=false; cd $currDir; rm -rf foo

WERCKER_GIT_PUSH_REPO="leipert/step-git-push"

cloneRepo $(getRemoteURL) $currDir/foo
cd $currDir;

## Test of whether branch existence test works
checkBranchExistence $currDir/foo "master"
[ $? != "0" ] && error "master branch should exist"

checkBranchExistence $currDir/foo "non-existing"
[ $? == "0" ] && error "non existing branch should not exist"

## Test if we can checkout branches
checkoutBranch $currDir/foo "master"
[ $? != "0" ] && error "Should be able to checkout existing master branch"

checkoutBranch $currDir/foo "non-existing"
[ $failed != "true" ] && error "Should not be able to checkout non-existing branch"
failed=false

## Test if we get the right tags

[ $(getTag "foo") != "foo" ] && error "$(getTag) != foo"

[ $(getTag "bower" $currDir/fixtures/) != "0.1.1" ] && error "$(getTag "bower" $currDir/fixtures/) != 0.1.1"

getTag "node" $currDir/fixtures/
[ $failed != "true" ] && error "Malformatted package.json should fail"
failed=false

## TEST CNAME Creation
WERCKER_GIT_PUSH_GH_PAGES_DOMAIN="foo.bar"
createCNAME $currDir/ > /dev/null
[ ! -f $currDir/CNAME ] && error "This should create a CNAME file"
rm -rf $currDir/CNAME

rm -rf $currDir/foo
if [ $throwError == "true" ]; then
  fail "Something failed"
else
  success "UNIT TESTS RAN SUCCESSFUL"
fi
