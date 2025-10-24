#! /bin/bash

usage() {
cat<<EOF
Synopsis: ./build.sh [ options ]

On supported machines, this script detects the machine, loads needed modules, runs cmake, and make.
For unsupported machines, all the script does is cmake and make.

Options:
-v                Have "make" print all commands that are run.
-d                Build in debug mode (cmake -DCMAKE_BUILD_TYPE=Debug)
-j job_count      Number of "make" threads (ie. make -j $DEFAULT_BUILD_JOBS)
                  Default: $DEFAULT_BUILD_JOBS
-DOPTION=VALUE    An option passed to cmake
-m machine_id     Skip machine detection and build for this machine.
-c compiler       Use the modulefile for this compiler. Default: $DEFAULT_COMPILER
-h                Print this message and exit
EOF
    echo "$@"
    exit 2
}

initialize_variables() {
    DEFAULT_BUILD_JOBS=4
    DEFAULT_COMPILER=intel

    COMPILER=$DEFAULT_COMPILER
    BUILD_JOBS=$DEFAULT_BUILD_JOBS

    declare -a CMAKE_OPTIONS
    CMAKE_OPTIONS=( )

    unset MACHINE_ID MACHINE
}

scan_command_line() {
    local opt
    while getopts "dvhc:j:m:D:" opt ; do
        case $opt in
            d)
                CMAKE_OPTIONS+=( "-DCMAKE_BUILD_TYPE=Debug" )
                ;;
            j)
                BUILD_JOBS=$(( 0 + OPTARG ))
                if (( BUILD_JOBS < 1 )) ; then
                    usage ERROR: Script is exiting due to bad -j option. You must have at least 1 build job.
                fi
                ;;
            m)
                MACHINE_ID="$OPTARG"
                ;;
            D)
                if [[ "$OPTARG" =~ \' ]] ; then
                    usage ERROR: Script is exiting because of a \' in the -D option. Options cannot include a \' due to shell limitations.
                fi
                CMAKE_OPTIONS+=( "-D$OPTARG" )
                ;;
            c)
                COMPILER="$OPTARG"
                ;;
            v)
                CMAKE_OPTIONS+=( "-DCMAKE_VERBOSE_MAKEFILE=ON" )
                ;;
            h|\?|:)
                usage
                ;;
        esac
    done

    if [[ OPTIND < "$#" ]] ; then
        usage "$OPTIND $# Script is exiting due to unrecognized arguments: $*"
    fi
}

decide_build_target() {
    # Are we on a known machine?
    if [[ -z "$MACHINE_ID" ]] ; then
        source src/tools/detect_machine.sh
    fi

    MPAS_BUILDTARGET=OFF
    if [[ "$MACHINE_ID" != UNKNOWN ]] ; then
        echo "Looking for modules for machine \"$MACHINE_ID\"."

        # Load the module command and purge or reset modules
        source src/tools/module-setup.sh

        # Find a modulefile for this machine and compiler.
        chosen_module="mpas_model_${MACHINE_ID}.${COMPILER}"
        if ( ls "$PWD/modulefiles/$chosen_module"* > /dev/null 2>&1 ) ; then
            echo Using module "$chosen_module"
            module use "$PWD/modulefiles"
            module load "$chosen_module"
            module list
        else
            echo WARNING: "$chosen_module": No modulefile found.
            echo WARNING: Using cmake defaults since I have no presets for machine $MACHINE_ID compiler $COMPILER.
        fi
    else
        echo "You aren't on a supported machine, so I won't load any modules."
    fi

    echo MPAS_BUILDTARGET is "$MPAS_BUILDTARGET"
}

configure_mpas() {
    echo Running cmake.

    set -x
    rm -rf build
    mkdir build
    cd build
    cmake -DMPAS_CORES='atmosphere;init_atmosphere' \
          -DMPAS_BUILDTARGET="$MPAS_BUILDTARGET" \
          "${CMAKE_OPTIONS[@]}" \
          ..
    set +x

    if [[ "$?" != 0 ]] ; then
        echo "Running \"cmake\" failed. Check earlier log lines for messages. Sorry."
        exit 1
    fi
}

build_mpas() {
    echo Compiling with $BUILD_JOBS jobs.

    set -x
    cd build
    make -j "$BUILD_JOBS"
    set +x

    if [[ "$?" != 0 ]] ; then
        echo "Running \"make\" failed. Check earlier log lines for messages. Sorry."
        exit 1
    fi
}

initialize_variables
scan_command_line "$@"
decide_build_target
( configure_mpas ) || exit 1
( build_mpas ) || exit 1

echo MPAS-Model build process is complete.
ls -l $PWD/build/bin/
echo Enjoy your MPAS.
