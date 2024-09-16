#!/bin/bash

#---------------------Directory---------------------#
# this handy piece of code determines the relative
# directory that this script is in.
SOURCE="${BASH_SOURCE[0]}"
# resolve $SOURCE until the file is no longer a symlink
while [ -h "$SOURCE" ]; do 
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  # if $SOURCE was a relative symlink, we need to resolve it relative 
  # to the path where the symlink file was located
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" 
done
LARSOFT_ANALYSIS_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )/../"

#---------------------Installation Directory--------#
USERNAME=`whoami`
export WORKDIR=/exp/dune/app/users/${USERNAME}
if [ ! -d "$WORKDIR" ]; then
  export WORKDIR=`echo ~`
fi
INSTALL_DIRECTORY=$WORKDIR/custom_nest_build
rm -rf $INSTALL_DIRECTORY
mkdir -p $INSTALL_DIRECTORY

#--------------------Versioning---------------------#
# specify the version of the larsoft packages.
export DUNE_VERSION=v09_88_00d00
export LARSOFT_VERSION=v09_88_00
export LAREXAMPLES_VERSION=v09_09_02
export LARSIM_VERSION=v09_41_02
export LARG4_VERSION=v09_19_02
export PROTODUNEANA_VERSION=$DUNE_VERSION
export DUNESIM_VERSION=$DUNE_VERSION
QUALS=e26:prof

#--------------------Setup LArSoft------------------#
source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup larsoft $LARSOFT_VERSION -q $QUALS

#----------------Setup everything else we need-----------------#
# These packages will setup all of their dependencies as well
# eg. setting up dune-sw will set up duneana and dunedataprep as well
setup dunesw $DUNE_VERSION -q $QUALS

#--------------------Create new development---------#
cd $INSTALL_DIRECTORY
mrb newDev
source localProducts*/setup

#-----------------Specifying packages---------------#
cd $MRB_SOURCE
# here we check out the packages we intend to modify
# e.g. larg4, where LArNEST lives
# current dependency tree is larg4->larsim->larexamples->larsoft->dunecore
mrb g dunecore@$DUNE_VERSION
mrb g dunesim@$DUNE_VERSION
mrb g larsoft@$LARSOFT_VERSION
mrb g larexamples@$LAREXAMPLES_VERSION
mrb g larsim@$LARSIM_VERSION
mrb g larg4@$LARG4_VERSION

# cleanly add local copy of larsim to the CMakeLists.txt file for building
mrb uc

#------------------Custom code part-----------------#
# here we put any special code that needs to
# be executed for the custom package.
cd $MRB_SOURCE/larsim/larsim/
git clone https://github.com/NESTCollaboration/larnest.git
cd larnest
git pull
# # checkout the tagged version for this version of LArsoft
# # TODO: should add a check for the tag
git checkout main

# copy LArNEST IonAndScint code to larsim
cp larsoft/*.* $MRB_SOURCE/larsim/larsim/IonizationScintillation/

cd $MRB_SOURCE/larsim/larsim/
sed -i '$ a add_subdirectory(larnest)' CMakeLists.txt

#------------------Installation and ninja-----------#
cd $MRB_BUILDDIR
mrbsetenv
mrb install -j 16 --generator ninja