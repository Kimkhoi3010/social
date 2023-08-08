#!/bin/bash

##
# CONFIG/HELP
##

if [[ -f config.sh ]]; then
    source config.sh
fi

read -r -d '' USAGE <<EOF

OCA helpers

Commands:
- ./oca.sh find: find MODULE: find MODULE locally or on github
- ./oca.sh pull: pull all repos (VERSIONS: $VERSIONS)
- ./oca.sh pull REPO: pull given REPO only
- ./oca.sh pull-pr LINK: pull given PR
- ./oca.sh cloc DIR: count lines of code of given module located in DIR, the odoo way

EOF

##
# UTILS
##

if [[ -n "${ZSH_VERSION}" ]]; then
  # to be able to run a complex command stored in a variable
  setopt shwordsplit
elif [[ -n "${BASH_VERSION}" ]]; then
  # make sure aliases are expanded even when the shell is not interactive
  shopt -s expand_aliases
fi

log_and_run() {
  echo $*
  $*
}

##
# COMMANDS
##

# find module
find_module() {
    module=$1

    echo "Looking for module locally:"
    log_and_run find -mindepth 3 -maxdepth 3 -type d -name "${module}"

    echo "Looking also for hints on github:"
    gh api -X GET search/issues -F per_page=100 --paginate -f q="org:OCA type:pull ${module}" --jq '.items[] | [.number, .state, .title, .html_url] | @tsv'
}

# pull latest changes from upstream OCA repos
pull() {
    # override config.sh REPOS
    if [[ ! -z "$1" ]]; then
	REPOS="$1"
    fi

    if [[ -z "${REPOS}" ]]; then
	REPOS=$(ls -1 -d */ | tr -d '/')
    fi

    for repo in ${REPOS}; do
	for version in ${VERSIONS}; do
	    tree="$repo/$version"
	    if [[ "${DRY_RUN}" == "1" ]]; then
		echo "Pulling $tree"
	    else
		if [[ -d $tree/.git ]]; then
		    echo "Pulling $tree"
		    (cd $tree && git checkout $version && git pull)
		else
		    echo "Cloning $tree"
		    git clone git@github.com:OCA/$repo -b $version $tree
		fi
	    fi
	done
    done
}

pull_pr() {
    # override config.sh VERSION
    if [[ ! -z "$2" ]]; then
	VERSION="$2"
    fi

    # grep -Eo 'https://github.com/OCA/([a-z\-]+)/pull/([0-9]+)'
    url=$1
    repo=$(echo $url | cut -f5 -d'/')
    pr_id=$(echo $url | cut -f7 -d'/')

    echo "${repo}/${VERSION}"
    cd "${repo}/${VERSION}" &&
        git branch -D pr-${pr_id} &> /dev/null
    git checkout ${VERSION} &&
        git fetch origin pull/${pr_id}/head:pr-${pr_id} &&
        git checkout pr-${pr_id}
}

merge_pr() {
    # override config.sh VERSION
    if [[ ! -z "$2" ]]; then
	VERSION="$2"
    fi

    # grep -Eo 'https://github.com/OCA/([a-z\-]+)/pull/([0-9]+)'
    url=$1
    repo=$(echo $url | cut -f5 -d'/')
    pr_id=$(echo $url | cut -f7 -d'/')

    git rebase --autosquash -i origin/${VERSION} &&
    git checkout -b ${VERSION}-ocabot-merge-pr-${pr_id}-by-trobz-bump-nobump origin/${VERSION} &&
    # Merge PR #${pr_id} into ${VERSION}
    git merge --no-ff -m "test" pr-${pr_id}
}

# count lines of codes, the odoo way
cloc() {
    pew in ${VENV_TOOLS:-oca} cloc-odoo.py $1
}

##
# MAIN
##

if [[ "$1" == "find" ]]; then
    find_module "$2"
elif [[ "$1" == "pull" ]]; then
    pull "$2"
elif [[ "$1" == "pull-pr" ]]; then
    pull_pr "$2" "$3"
elif [[ "$1" == "merge-pr" ]]; then
    pull_pr "$2" "$3"
    merge_pr "$2" "$3"
elif [[ "$1" == "cloc" ]]; then
    cloc "$2"
else
    echo "$USAGE"
fi
