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
    if [[ -z "$*" ]] ; then
        exit 0
    fi
    exit 2
}

DEFAULT_BUILD_JOBS=4
BUILD_JOBS=$DEFAULT_BUILD_JOBS

DEFAULT_COMPILER=intel
COMPILER=$DEFAULT_COMPILER

MPAS_BUILDTARGET=OFF
unset MACHINE_ID MACHINE

declare -a CMAKE_OPTIONS
CMAKE_OPTIONS=( )

while getopts "dvhc:j:m:D:" opt ; do
    case $opt in
        d)  CMAKE_OPTIONS+=( "-DCMAKE_BUILD_TYPE=Debug" )
            ;;
        j)  if ! [[ "$OPTARG" =~ ^[1-9][0-9]*$ ]] ; then
                usage "ERROR: Script is exiting due to bad -j option \"$OPTARG\". You must have at least 1 build job."
            fi
            BUILD_JOBS=$OPTARG
            ;;
        m)  MACHINE_ID="$OPTARG"
            ;;
        D)  CMAKE_OPTIONS+=( "-D$OPTARG" )
            ;;
        c)  COMPILER="$OPTARG"
            ;;
        v)  CMAKE_OPTIONS+=( "-DCMAKE_VERBOSE_MAKEFILE=ON" )
            ;;
        h)  usage
            ;;
        \?|:)
            usage "Script is exiting due to invalid arguments. See prior messages for details"
    esac
done

if [[ OPTIND < "$#" ]] ; then
    usage "$OPTIND $# Script is exiting due to unrecognized arguments: $*"
fi

# Are we on a known machine?
if [[ -z "$MACHINE_ID" ]] ; then
    source src/tools/detect_machine.sh
fi

if [[ "$MACHINE_ID" != UNKNOWN ]] ; then
    echo "Looking for modules for machine \"$MACHINE_ID\" compiler \"$COMPILER\"."

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
        echo WARNING: "Using cmake defaults since I have no presets for machine \"${MACHINE_ID}\" compiler \"${COMPILER}\"."
    fi
else
    echo "You aren't on a supported machine, so I won't load any modules."
fi

set -x
rm -rf build
mkdir build
cd build

if ( ! cmake -DMPAS_CORES='atmosphere;init_atmosphere' \
       -DMPAS_BUILDTARGET="$MPAS_BUILDTARGET" \
       "${CMAKE_OPTIONS[@]}" \
       .. ) ; then
    set +x
    echo "Running \"cmake\" failed. Check earlier log lines for messages. Sorry."
    exit 1
fi

if ( ! make -j "$BUILD_JOBS" ) ; then
    set +x
    echo "Running \"make\" failed. Check earlier log lines for messages. Sorry."
    exit 1
fi

set +x
echo MPAS-Model build process is complete.
ls -l $PWD/bin/
echo Enjoy your MPAS.
