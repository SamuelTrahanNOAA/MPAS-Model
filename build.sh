#! /bin/bash

usage() {
cat<<EOF
Synopsis: ./build.sh [ options ] [ list of cores ]

Builds MPAS using the cmake-based build system.  Can detect NOAA and
NCAR machines, using their preset options.  Older Makefile-like build
targets are available too (-t).

Options:
list of cores     Select these mpas cores.
                  Default: atmosphere init_atmosphere
-v                Have "make" print all commands that are run.
-j job_count      Number of "make" threads (ie. make -j $DEFAULT_BUILD_JOBS)
                  Default: $DEFAULT_BUILD_JOBS
-DOPTION=VALUE    An option passed to cmake
-t buildtarget    Select a specific build target, as in the Makefile build system.
                  Default: If a machine with presets is found, use those presets.
                           Otherwise, let cmake decide options automatically.
-t OFF            No build target, and no machine detection. Just a simple build.
-c compiler       Used to decide what modulefile to use, if a machine is detected
                  Default: $DEFAULT_COMPILER
-h                Print this message and exit
EOF
    exit 1
}

initialize_variables() {
    DEFAULT_BUILD_JOBS=4
    DEFAULT_COMPILER=intel

    MPAS_BUILDTARGET=UNKNOWN
    COMPILER=$DEFAULT_COMPILER
    CMAKE_OPTIONS=" "
    BUILD_JOBS=$DEFAULT_BUILD_JOBS
}

scan_command_line() {
    local opt
    while getopts "vhp:c:j:t:D:" opt ; do
        case $opt in
            j)
                BUILD_JOBS=$(( 0 + OPTARG ))
                ;;
            t)
                check_for_quote -t
                MPAS_BUILDTARGET="$OPTARG"
                ;;
            t)
                check_for_quote -t
                MPAS_BUILDTARGET="$OPTARG"
                ;;
            D)
                check_for_quote -D
                CMAKE_OPTIONS+=" '-D$OPTARG'"
                ;;
            c)
                COMPILER="$OPTARG"
                ;;
            v)
                CMAKE_OPTIONS+=" -DCMAKE_VERBOSE_MAKEFILE=ON"
                ;;
            h|\?|:)
                usage
                ;;
        esac
    done


    if [[ OPTIND > 1 ]] ; then
        shift $(( OPTIND - 1 ))
    fi

    if [[ "$#" -gt 0 ]] ; then
        echo Selecting MPAS_CORES "'$*'"
        CMAKE_OPTIONS+=" -DMPAS_CORES='$( spaces_to_semi $* )'"
    else
        CMAKE_OPTIONS+=" -DMPAS_CORES='atmosphere;init_atmosphere'" # make sure this matches usage()
    fi
}

spaces_to_semi() {
    local cores="$*"
    echo $cores | sed 's:  *:;:g'
}

check_for_quote() {
    if [[ "$OPTARG" =~ \' ]] ; then
        echo ERROR: Found \' in this argument: "$OPTARG"
        echo ERROR: Cannot include \' in $1 argument due to shell language limitations.
        exit 1
    fi
}

decide_build_target() {
    if [[ "$MPAS_BUILDTARGET" == UNKNOWN ]] ; then
        # Are we on a known machine?
        source src/tools/detect_machine.sh

        if [[ "$MACHINE_ID" == UNKNOWN ]] ; then
            MPAS_BUILDTARGET=OFF # Use cmake defaults
        else
            echo "You appear to be on the machine \"$MACHINE_ID\". I will use its preset options for compiler $COMPILER, if any exist."

            source src/tools/module-setup.sh

            if ( ls $PWD/modulefiles/mpas_model_$MACHINE_ID* > /dev/null 2>&1 ) ; then
                module use $PWD/modulefiles
               #module spider mpas_model_$MACHINE_ID.$COMPILER
                module load mpas_model_$MACHINE_ID.$COMPILER
                echo Loaded modules:
                module list
            else
                echo WARNING: No modulefile for machine $MACHINE_ID compiler $COMPILER
                MPAS_BUILDTARGET=OFF
            fi
        fi
    fi

    echo MPAS_BUILDTARGET is "$MPAS_BUILDTARGET"
}

configure_mpas() {
    set -x
    rm -rf build
    mkdir build
    cd build
    cmake -DMPAS_BUILDTARGET="$MPAS_BUILDTARGET" $CMAKE_OPTIONS ..
    status=$?
    cd ..
    return $status
}

build_mpas() {
    set -x
    cd build
    if [[ "$BUILD_JOBS" -gt 0 ]] ; then
        echo Compiling with $BUILD_JOBS jobs.
        make -j "$BUILD_JOBS"
        status=$?
    else
        make
        status=$?
    fi
    cd ..
    return $status
}

initialize_variables
scan_command_line "$@"
decide_build_target
if ( ! configure_mpas ) ; then
    echo "Running \"cmake\" failed. Check earlier log lines for messages. Sorry."
    exit 1
fi
if ( ! build_mpas ) ; then
    echo "Running \"make\" failed. Check earlier log lines for messages. Sorry."
    exit 1
fi
echo MPAS-Model build process is complete.
echo Executables are in $PWD/build/bin:
ls -l $PWD/build/bin
echo Enjoy your MPAS.
