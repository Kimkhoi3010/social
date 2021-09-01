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

# get addons path for given or default version
get_addons_path() {
    # override config.sh VERSION
    if [[ ! -z "$1" ]]; then
	VERSION="$1"
    fi
    export OCA_ADDONS_PATH=$(find $(pwd) -mindepth 2 -maxdepth 2 -type d -name "${VERSION}" | tr '\n' ',' | head -c-1)
    export ODOO_ADDONS_PATH=$(dirname $(pwd))/odoo/odoo/${VERSION}/addons
    export ADDONS_PATH="${ODOO_ADDONS_PATH},${OCA_ADDONS_PATH}"
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
    venv="venv-odoo$major"

    # you can force an IP in config.sh
    if [[ -z "${IP}" ]]; then
	IP="127.0.$major.1"
    fi

    # server_wide_modules
    if [[ -z "${LOAD}" ]]; then
	LOAD="web,base"
    fi

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Running odoo in ${venv}, will be listening on ${IP}:8069"
    fi

    get_addons_path ${VERSION}

    DB="v${major}c_${module}"

    log_and_run pew in $venv odoo \
	-d ${DB} \
	--db_host=localhost --db_user=openerp --db_password=openerp \
	--load=${LOAD} \
	--workers=0 --max-cron-threads=0 \
	--limit-time-cpu=3600 \
	--http-interface=${IP} \
	--addons-path=${ADDONS_PATH} \
	-i ${module}
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
    venv="venv-odoo$major"

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Running odoo in ${venv}"
    fi

    get_addons_path ${VERSION}

    DB="v${major}c_${module}"

    log_and_run pew in $venv odoo \
	-d ${DB} \
	--db_host=localhost --db_user=openerp --db_password=openerp \
	--workers=0 --max-cron-threads=0 \
	--limit-time-cpu=3600 \
	--addons-path=${ADDONS_PATH} \
	--test-enable \
	--http-interface=127.0.0.1 \
	--http-port=$((1024+$RANDOM)) \
	--stop-after-init \
	-u ${module}
}

shell() {
    module=$1

    # VERSION
    if [[ ! -z "$2" ]]; then
	VERSION="$2"
    fi

    major=(${VERSION/.0/})
    venv="venv-odoo$major"

    if [[ "${DEBUG}" == "1" ]]; then
	echo "Running odoo in ${venv}"
    fi

    get_addons_path ${VERSION}

    DB="v${major}c_${module}"

    log_and_run pew in $venv odoo \
		shell \
		-d ${DB} \
		--db_host=localhost --db_user=openerp --db_password=openerp \
		--workers=0 --max-cron-threads=0 \
		--addons-path=${ADDONS_PATH} \
		--no-http
}

##
# MAIN
##

if [[ "$1" == "pull" ]]; then
    pull "$2"
elif [[ "$1" == "pull-pr" ]]; then
    pull_pr "$2" "$3"
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
