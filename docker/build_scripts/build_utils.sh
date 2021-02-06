#!/bin/bash
# Helper utilities for build


function check_var {
    if [ -z "$1" ]; then
        echo "required variable not defined"
        exit 1
    fi
}


function lex_pyver {
    # Echoes Python version string padded with zeros
    # Thus:
    # 3.2.1 -> 003002001
    # 3     -> 003000000
    echo $1 | awk -F "." '{printf "%03d%03d%03d", $1, $2, $3}'
}


function pyver_dist_dir {
    # Echoes the dist directory name of given pyver, removing alpha/beta prerelease
    # Thus:
    # 3.2.1   -> 3.2.1
    # 3.7.0b4 -> 3.7.0
    echo $1 | awk -F "." '{printf "%d.%d.%d", $1, $2, $3}'
}


function do_cpython_build {
    local py_ver=$1
    check_var $py_ver
    tar -xzf Python-$py_ver.tgz
    pushd Python-$py_ver
    local prefix="/opt/_internal/cpython-${py_ver}"
    mkdir -p ${prefix}/lib
    ./configure --prefix=${prefix} --disable-shared --with-ensurepip=no > /dev/null
    make -j$(nproc) > /dev/null
    make -j$(nproc) install > /dev/null
    popd
    rm -rf Python-$py_ver
}


function build_cpython {
    local py_ver=$1
    check_var $py_ver
    check_var $PYTHON_DOWNLOAD_URL
    local py_dist_dir=$(pyver_dist_dir $py_ver)
    curl -fsSLO $PYTHON_DOWNLOAD_URL/$py_dist_dir/Python-$py_ver.tgz
    curl -fsSLO $PYTHON_DOWNLOAD_URL/$py_dist_dir/Python-$py_ver.tgz.asc
    gpg --verify Python-$py_ver.tgz.asc
    do_cpython_build $py_ver
    rm -f Python-$py_ver.tgz
    rm -f Python-$py_ver.tgz.asc
}


function build_cpythons {
    # Import public keys used to verify downloaded Python source tarballs.
    # https://www.python.org/static/files/pubkeys.txt
    gpg --import ${MY_DIR}/cpython-pubkeys.txt
    # Add version 3.8, 3.9 release manager's key
    gpg --import ${MY_DIR}/ambv-pubkey.txt
    for py_ver in $@; do
        build_cpython $py_ver
    done
    # Remove GPG hidden directory.
    rm -rf /root/.gnupg/
}


function fetch_source {
    # This is called both inside and outside the build context (e.g. in Travis) to prefetch
    # source tarballs, where curl exists (and works)
    local file=$1
    check_var ${file}
    local url=$2
    check_var ${url}
    if [ -f ${file} ]; then
        echo "${file} exists, skipping fetch"
    else
        curl -fsSL -o ${file} ${url}/${file}
    fi
}


function check_sha256sum {
    local fname=$1
    check_var ${fname}
    local sha256=$2
    check_var ${sha256}

    echo "${sha256}  ${fname}" > ${fname}.sha256
    sha256sum -c ${fname}.sha256
    rm -f ${fname}.sha256
}


function do_standard_install {
    ./configure "$@" > /dev/null
    make -j$(nproc) > /dev/null
    make -j$(nproc) install > /dev/null
}

function strip_ {
	# Strip what we can -- and ignore errors, because this just attempts to strip
	# *everything*, including non-ELF files:
	find $1 -type f -print0 | xargs -0 -n1 strip --strip-unneeded 2>/dev/null || true
}
