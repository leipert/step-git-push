#!/bin/sh
set -e
set +o pipefail

info "using 3.14 settings $WERCKER_GIT_BRANCH $WERCKER_GIT_PUSH_BASEDIR $WERCKER_GIT_PUSH_BRANCH $WERCKER_GIT_PUSH_DISCARD_HISTORY $WERCKER_GIT_PUSH_GH_PAGES $WERCKER_GIT_PUSH_GH_PAGES_DOMAIN $WERCKER_GIT_PUSH_HOST $WERCKER_GIT_PUSH_REPO $WERCKER_GIT_REPOSITORY $WERCKER_STARTED_BY $WERCKER_GIT_USER"

# use repo option or guess from git info
if [ -n "$WERCKER_GIT_PUSH_REPO" ]
then
  repo="$WERCKER_GIT_PUSH_REPO"
else
  repo="$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY"
fi

if [ -n "$WERCKER_GIT_PUSH_USER"]
then
  git_user="git"
else
  git_user="$WERCKER_GIT_PUSH_USER"
fi

info "using github repo \"$repo\""

# remote path
# use repo option or guess from git info
if [ -n "$WERCKER_GIT_PUSH_GH_TOKEN" ]
then
  remote="https://$WERCKER_GIT_PUSH_GH_TOKEN@github.com/$repo.git"
  info "using github token"
elif [ -n "$WERCKER_GIT_PUSH_HOST" ]
then
  remote="$git_user@$WERCKER_GIT_PUSH_HOST:$repo.git"
  info "using git ssh: $remote"
else
  fail "missing option \"gh_token\" or \"host\", aborting"
fi

sourceDir=$(pwd)/

# if directory provided, cd to it
if [ -d "$WERCKER_GIT_PUSH_BASEDIR" ]
then
  sourceDir="$sourceDir$WERCKER_GIT_PUSH_BASEDIR/"
fi

# setup branch
if [ -n "$WERCKER_GIT_PUSH_BRANCH" ]
then
  branch="$WERCKER_GIT_PUSH_BRANCH"
else
  branch="$WERCKER_GIT_BRANCH"
fi

# setup github pages
if [ -n "$WERCKER_GIT_PUSH_GH_PAGES" ]
then
  branch="gh-pages"
  if [[ "$repo" =~ $WERCKER_GIT_OWNER\/$WERCKER_GIT_OWNER\.github\.(io|com)$ ]]; then
     branch="master"
  fi
  # generate cname file
  if [ -n "$WERCKER_GIT_PUSH_GH_PAGES_DOMAIN" ]; then
     echo $WERCKER_GIT_PUSH_GH_PAGES_DOMAIN > "$sourceDirCNAME"
  fi
fi

if [ -n "$WERCKER_GIT_PUSH_TAG" ]
then
  case $WERCKER_GIT_PUSH_TAG in
    "bower") tag="$(cat bower.json | python -c 'import sys, json; print json.load(sys.stdin)["version"]')";;
    "node") tag="$(cat package.json | python -c 'import sys, json; print json.load(sys.stdin)["version"]')";;
    *) tag=$WERCKER_GIT_PUSH_TAG;;
  esac
  info "The commit will be tagged with $tag"
fi

cd $sourceDir
rm -rf .git

# remove existing files
targetDir="/tmp/git-push"
rm -rf $targetDir

# init repository
if [ -n "$WERCKER_GIT_PUSH_DISCARD_HISTORY" ]
then
  mkdir -p $targetDir
  cd $targetDir
  git init
  thisbranch="master"
else
  git clone $remote $targetDir
  cd $targetDir
  if git ls-remote --exit-code . origin/$branch
  then
    git checkout $branch
    thisbranch=$branch
    info "Branch $branch exists on remote"
  else
    cd
    rm -rf $targetDir
    mkdir -p $targetDir
    cd $targetDir
    git init
    thisbranch="master"
  fi
fi

git config user.email "pleasemailus@wercker.com"
git config user.name "werckerbot"

cp -rf $sourceDir* .

git add .

if git diff --cached --exit-code --quiet
then
  success "Nothing changed. We do not need to push"
else
  git commit -am "deploy from $WERCKER_STARTED_BY" --allow-empty
  result="$(git push -f $remote $thisbranch:$branch)"
  if [[ $? -ne 0 ]]
  then
    warning "$result"
    fail "failed pushing to $branch on $remote"
  else
    success "pushed to to $branch on $remote"
  fi
fi

if [ -n "$WERCKER_GIT_PUSH_TAG" ]
then
  if git tag -l | grep $tag
  then
    info "tag $tag exists"
    if [ -n "$WERCKER_GIT_PUSH_TAG_OVERWRITE" ]
    then
      info "tag $tag will be overwritten"
      git tag -d $tag
      git push origin :refs/tags/$tag
      git tag -a $tag -m "Tagged by $WERCKER_STARTED_BY" -f
      git push --tags
    fi
  else
    git tag -a $tag -m "Tagged by $WERCKER_STARTED_BY" -f
    git push --tags
  fi
fi

unset WERCKER_GIT_PUSH_BASEDIR
unset WERCKER_GIT_PUSH_BRANCH
unset WERCKER_GIT_PUSH_DISCARD_HISTORY
unset WERCKER_GIT_PUSH_GH_PAGES
unset WERCKER_GIT_PUSH_GH_PAGES_DOMAIN
unset WERCKER_GIT_PUSH_GH_TOKEN
unset WERCKER_GIT_PUSH_HOST
unset WERCKER_GIT_PUSH_REPO
unset WERCKER_GIT_PUSH_TAG
unset WERCKER_GIT_OVERWRITE_TAG
unset WERCKER_GIT_USER
