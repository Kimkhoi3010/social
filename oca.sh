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
- ./oca.sh deps MODULE [VERSION]: show dependency tree of given MODULE
- ./oca.sh cloc DIR: count lines of code of given module located in DIR, the odoo way
- ./oca.sh try MODULE [VERSION]: run an odoo instance to try given MODULE (in given VERSION)
- ./oca.sh shell MODULE [VERSION]: run an odoo shell on the db created for given MODULE (in given VERSION)
- ./oca.sh tests MODULE [VERSION]: run the tests of a given MODULE (in given VERSION)

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

# get addons path for given or default version
get_addons_path() {
    # override config.sh VERSION
    if [[ ! -z "$1" ]]; then
	VERSION="$1"
    fi

    # defaults for OCA_ROOT_DIR, ODOO_ROOT_DIR
    # based on current location
    if [[ -z "${OCA_ROOT_DIR}" ]]; then
	export OCA_ROOT_DIR=$(pwd)
    fi
    if [[ -z "${ODOO_ROOT_DIR}" ]]; then
	export ODOO_ROOT_DIR=$(dirname $(pwd))
    fi

    # OCA_ROOT_DIR_MODE: repo_module
    # i.e. ${OCA_ROOT_DIR}/server-tools/auditlog
    if [[ "${OCA_ROOT_DIR_MODE}" == "repo_module" ]]; then
	DIRS=$(find "${OCA_ROOT_DIR}" -mindepth 1 -maxdepth 1 -type d -not -empty)
    else
	# OCA_ROOT_DIR_MODE: repo_version_module (default)
	# i.e. ${OCA_ROOT_DIR}/server-tools/14.0/auditlog
	DIRS=$(find "${OCA_ROOT_DIR}" -mindepth 2 -maxdepth 2 -type d -name "${VERSION}" -not -empty)
    fi

    # filter out folders that don't have at least one module
    OCA_ADDONS_PATH=""
    for d in ${DIRS}; do
	if $(find "$d" -mindepth 1 -maxdepth 1 -type d | grep -v .git >/dev/null); then
	    export OCA_ADDONS_PATH="${OCA_ADDONS_PATH},$d"
	else
	    echo "Ignoring $d: doesn't contain any module"
	fi
    done

    export ODOO_ADDONS_PATH="${ODOO_ROOT_DIR}/odoo/odoo/${VERSION}/addons"
    # note: ${OCA_ADDONS_PATH} starts by , already
    export ADDONS_PATH="${ODOO_ADDONS_PATH}${OCA_ADDONS_PATH}"
    if [[ ! -z "${EXTRA_ADDONS_PATH}" ]]; then
	export ADDONS_PATH="${ADDONS_PATH},${EXTRA_ADDONS_PATH}"
    fi
}

# show dependency tree of given module
deps() {
    module=$1

    # this
    if [[ "${module}" == "this" ]] || [[ "${module}" == "." ]]; then
        module=$(basename $(pwd))
        VERSION=$(basename $(dirname $(pwd)))
        cd ../../..
    fi

    # VERSION
    if [[ ! -z "$2" ]]; then
	VERSION="$2"
    fi

    get_addons_path ${VERSION}

    if [[ "${DEBUG}" == "1" ]]; then
	echo ADDONS_PATH=${ADDONS_PATH}
    fi

    pew in oca manifestoo --no-addons-path-from-import-odoo --odoo-series "${VERSION}" --addons-path "${ADDONS_PATH}" --select "$module" tree
}

# count lines of codes, the odoo way
cloc() {
    pew in oca cloc-odoo.py $1
}

try() {
    module=$1

    # this
    if [[ "${module}" == "this" ]] || [[ "${module}" == "." ]]; then
        module=$(basename $(pwd))
        VERSION=$(basename $(dirname $(pwd)))
        cd ../../..
    fi

    # VERSION
    if [[ ! -z "$2" ]]; then
	VERSION="$2"
    fi

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Trying ${module} in odoo ${VERSION}"
    fi

    major=(${VERSION/.0/})

    # you can force a venv in config.sh
    if [[ -z "${VENV}" ]]; then
	VENV="venv-odoo$major"
    fi

    # you can force an IP in config.sh
    if [[ -z "${IP}" ]]; then
	IP="127.0.$major.1"
    fi

    # server_wide_modules
    if [[ -z "${LOAD}" ]]; then
	LOAD="web,base"
    fi

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Running odoo in ${VENV}, will be listening on ${IP}:8069"
    fi

    get_addons_path ${VERSION}

    # you can force a DB in config.sh
    if [[ -z "${DB}" ]]; then
	DB="v${major}c_${module}"
    fi

    log_and_run pew in ${VENV} odoo \
	-d ${DB} \
	--db_host=localhost --db_user=openerp --db_password=openerp \
	--load=${LOAD} \
	--workers=0 --max-cron-threads=0 \
	--limit-time-cpu=3600 \
	--limit-time-real=3600 \
	--http-interface=${IP} \
	--addons-path=${ADDONS_PATH} \
	-i ${module} \
	${EXTRA_PARAMS}
}

tests() {
    module=$1

    # this
    if [[ "${module}" == "this" ]] || [[ "${module}" == "." ]]; then
        module=$(basename $(pwd))
        VERSION=$(basename $(dirname $(pwd)))
        cd ../../..
    fi

    # VERSION
    if [[ ! -z "$2" ]]; then
	VERSION="$2"
    fi

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Running ${module} tests in odoo ${VERSION}"
    fi

    major=(${VERSION/.0/})

    # you can force a venv in config.sh
    if [[ -z "${VENV}" ]]; then
	VENV="venv-odoo$major"
    fi

    # port
    if [[ -z "${HTTP_PORT}" ]]; then
	HTTP_PORT=$((1024+$RANDOM))
    fi

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Running odoo in ${VENV}"
    fi

    get_addons_path ${VERSION}

    # you can force a DB in config.sh
    if [[ -z "${DB}" ]]; then
	DB="v${major}c_${module}"
    fi

    log_and_run pew in ${VENV} odoo \
	-d ${DB} \
	--db_host=localhost --db_user=openerp --db_password=openerp \
	--workers=0 --max-cron-threads=0 \
	--limit-time-cpu=3600 \
	--limit-time-real=3600 \
	--addons-path=${ADDONS_PATH} \
	--test-enable \
	--http-interface=127.0.0.1 \
	--http-port=${HTTP_PORT} \
	--stop-after-init \
	-u ${module} \
	${EXTRA_PARAMS}
}

shell() {
    module=$1

    # VERSION
    if [[ ! -z "$2" ]]; then
	VERSION="$2"
    fi

    major=(${VERSION/.0/})

    # you can force a venv in config.sh
    if [[ -z "${VENV}" ]]; then
	VENV="venv-odoo$major"
    fi

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Running odoo in ${venv}"
    fi

    get_addons_path ${VERSION}

    # you can force a DB in config.sh
    if [[ -z "${DB}" ]]; then
	DB="v${major}c_${module}"
    fi

    log_and_run pew in ${VENV} odoo \
		shell \
		-d ${DB} \
		--db_host=localhost --db_user=openerp --db_password=openerp \
		--workers=0 --max-cron-threads=0 \
		--addons-path=${ADDONS_PATH} \
		--no-http \
		${EXTRA_PARAMS}
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
elif [[ "$1" == "deps" ]]; then
    deps "$2" "$3"
elif [[ "$1" == "cloc" ]]; then
    cloc "$2"
elif [[ "$1" == "try" ]]; then
    try "$2" "$3"
elif [[ "$1" == "tests" ]]; then
    tests "$2" "$3"
elif [[ "$1" == "shell" ]]; then
    shell "$2" "$3"
else
    echo "$USAGE"
fi
