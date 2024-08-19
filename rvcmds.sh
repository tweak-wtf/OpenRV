# Ensure file is sourced and not executed

SOURCED=0
if [ -n "$ZSH_EVAL_CONTEXT" ]; then
  [[ $ZSH_EVAL_CONTEXT =~ :file$ ]] && SOURCED=1
  SCRIPT=$0
elif [ -n "$KSH_VERSION" ]; then
  [[ "$(cd $(dirname -- $0) && pwd -P)/$(basename -- $0)" != "$(cd $(dirname -- ${.sh.file}) && pwd -P)/$(basename -- ${.sh.file})" ]] && SOURCED=1
  SCRIPT=$0
elif [ -n "$BASH_VERSION" ]; then
  [[ $0 != "$BASH_SOURCE" ]] && SOURCED=1
  SCRIPT=${BASH_SOURCE[0]}
elif grep -q dash /proc/$$/cmdline; then
  case $0 in *dash*) SOURCED=1 ;; esac
  x=$(lsof -p $$ -Fn0 | tail -1); SCRIPT=${x#n}
fi

SCRIPT_HOME=`readlink -f $(dirname $SCRIPT)`
if [[ $SOURCED == 0 ]]; then
  echo "Please call: source $SCRIPT"
  exit 1
fi

# Linux
if [[ "$OSTYPE" == "linux"* ]]; then
  CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"

# MacOS
elif [[ "$OSTYPE" == "darwin"* ]]; then
  CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"

# Windows
elif [[ "$OSTYPE" == "msys"* ]]; then
  CMAKE_GENERATOR="${CMAKE_GENERATOR:-Visual Studio 17 2022}"
  WIN_PERL="${WIN_PERL:-c:/Strawberry/perl/bin}"
  CMAKE_WIN_ARCH="${CMAKE_WIN_ARCH:--A x64}"
  SETUPTOOLS_USE_DISTUTILS=stdlib

else
  echo "OS does not seem to be linux, darwin or msys. Exiting."
  exit 1
fi

# Searching for a Qt installation path if it has not already been set
if [ -z "$QT_HOME" ]; then
  echo "Searching for Qt installation..."

  if [[ "$OSTYPE" == "linux"* ]]; then
    QT_HOME=$(find ~/Qt/5.15* -type d -maxdepth 4 -path '*/gcc_64' | sort -V | tail -n 1)
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    QT_HOME=$(find ~/Qt/5.15* -type d -maxdepth 4 -path '*/macos' | sort -V | tail -n 1)

    # If no macos installation found, try clang_64
    if [ -z "$QT_HOME" ]; then
      QT_HOME=$(find ~/Qt/5.15* -type d -maxdepth 4 -path '*/clang_64' | sort -V | tail -n 1)
    fi

  elif [[ "$OSTYPE" == "msys"* ]]; then
    QT_HOME=$(find c:/Qt/5.15* -type d -maxdepth 4 -path '*/msvc2019_64' | sort -V | tail -n 1)
  fi

  # Could not find Qt installation
  if [ -z "$QT_HOME" ]; then
    echo "Could not find Qt installation. Please set QT_HOME to the correct path in your environment variables."
  else 
    echo "Found Qt installation at $QT_HOME"
  fi

# Qt installation path already set
else 
  echo "Using Qt installation already set at $QT_HOME"
fi

# VARIABLES
RV_HOME="${RV_HOME:-$SCRIPT_HOME}"
RV_BUILD="${RV_BUILD:-${RV_HOME}/_build}"
RV_INST="${RV_INST:-${RV_HOME}/_install}"
RV_BUILD_PARALLELISM="${RV_BUILD_PARALLELISM:-$(python3 -c 'import os; print(os.cpu_count())')}"

# ALIASES: Basic commands

alias rvenv="[ -d "_virtualenv" ] && source _virtualenv/bin/activate || (python3 -m venv _virtualenv && source _virtualenv/bin/activate)"
alias rvsetup="rvenv && SETUPTOOLS_USE_DISTUTILS=${SETUPTOOLS_USE_DISTUTILS} python3 -m pip install --upgrade -r ${RV_HOME}/requirements.txt"
alias rvcfg="rvenv && cmake -B ${RV_BUILD} -G \"${CMAKE_GENERATOR}\" ${CMAKE_WIN_ARCH} -DCMAKE_BUILD_TYPE=Release -DRV_DEPS_QT5_LOCATION=${QT_HOME} -DRV_DEPS_WIN_PERL_ROOT=${WIN_PERL}"
alias rvcfgd="rvenv && cmake -B ${RV_BUILD} -G \"${CMAKE_GENERATOR}\" ${CMAKE_WIN_ARCH} -DCMAKE_BUILD_TYPE=Debug -DRV_DEPS_QT5_LOCATION=${QT_HOME} -DRV_DEPS_WIN_PERL_ROOT=${WIN_PERL}"
alias rvbuildt="rvenv && cmake --build ${RV_BUILD} --config Release -v --parallel=${RV_BUILD_PARALLELISM} --target "
alias rvbuildtd="rvenv && cmake --build ${RV_BUILD} --config Debug -v --parallel=${RV_BUILD_PARALLELISM} --target "
alias rvbuild="rvenv && rvbuildt main_executable"
alias rvbuildd="rvenv && rvbuildtd main_executable"
alias rvtest="rvenv && ctest --test-dir ${RV_BUILD} --extra=verbose"
alias rvinst="rvenv && cmake --install ${RV_BUILD} --prefix ${RV_INST} --config Release"
alias rvinstd="rvenv && cmake --install ${RV_BUILD} --prefix ${RV_INST} --config Debug"
alias rvclean="rm -rf ${RV_BUILD} && rm -rf _virtualenv"

# ALIASES: Config and Build

echo 'alias rvmk="rvcfg && rvbuild"' >> $HOME/.bashrc
echo 'alias rvmkd="rvcfgd && rvbuildd"' >> $HOME/.bashrc

# ALIASES: Setup, Config and Build

echo 'alias rvbootstrap="rvsetup && rvmk"' >> $HOME/.bashrc
echo 'alias rvbootstrapd="rvsetup && rvmkd"' >> $HOME/.bashrc

echo "Please ensure you have installed any required dependencies from doc/build_system/config_[os]"
echo
echo "CMake parameters:"

echo "RV_BUILD_PARALLELISM is $RV_BUILD_PARALLELISM"
echo "RV_HOME is $RV_HOME"
echo "RV_BUILD is $RV_BUILD"
echo "RV_INST is $RV_INST"
echo "CMAKE_GENERATOR is $CMAKE_GENERATOR"
echo "QT_HOME is $QT_HOME"
if [[ "$OSTYPE" == "msys"* ]]; then echo "WIN_PERL is $WIN_PERL"; fi

echo "To override any of them do unset [name]; export [name]=value; source $SCRIPT"
echo
echo "If this is your first time building RV try rvbootstrap (release) or rvbootstrapd (debug)"
echo "To build quickly after bootstraping try rvmk (release) or rvmkd (debug)"

rvenv() {
  [ -d "_virtualenv" ] && source _virtualenv/bin/activate || (python3 -m venv _virtualenv && source _virtualenv/bin/activate)
}

rvsetup() {
  rvenv && SETUPTOOLS_USE_DISTUTILS=${SETUPTOOLS_USE_DISTUTILS} python3 -m pip install --user --upgrade -r ${RV_HOME}/requirements.txt
}

rvbuild() {
  rvenv && cmake --build ${RV_BUILD} --config Release -v --parallel=${RV_BUILD_PARALLELISM} --target $1
}

rvcfg() {
  rvenv && cmake -B ${RV_BUILD} -G "${CMAKE_GENERATOR}" ${CMAKE_WIN_ARCH} -DCMAKE_BUILD_TYPE=Release -DRV_DEPS_QT5_LOCATION=${QT_HOME} -DRV_DEPS_WIN_PERL_ROOT=${WIN_PERL}
}

rvcfgd() {
  rvenv && cmake -B ${RV_BUILD} -G "${CMAKE_GENERATOR}" ${CMAKE_WIN_ARCH} -DCMAKE_BUILD_TYPE=Debug -DRV_DEPS_QT5_LOCATION=${QT_HOME} -DRV_DEPS_WIN_PERL_ROOT=${WIN_PERL}
}

rvbuildt() {
  rvenv && cmake --build ${RV_BUILD} --config Release -v --parallel=${RV_BUILD_PARALLELISM} --target $1
}

rvbuildtd() {
  rvenv && cmake --build ${RV_BUILD} --config Debug -v --parallel=${RV_BUILD_PARALLELISM} --target $1
}

rvbuildd() {
  rvenv && cmake --build ${RV_BUILD} --config Debug -v --parallel=${RV_BUILD_PARALLELISM} --target $1
}

rvbuildd() {
  rvenv && cmake --build ${RV_BUILD} --config Debug -v --parallel=${RV_BUILD_PARALLELISM} --target $1
}

rvtest() {
  rvenv && ctest --test-dir ${RV_BUILD} --extra=verbose
}

rvinst() {
  rvenv && cmake --install ${RV_BUILD} --prefix ${RV_INST} --config Release
}

rvinstd() {
  rvenv && cmake --install ${RV_BUILD} --prefix ${RV_INST} --config Debug
}

rvclean() {
  rvenv && rm -rf ${RV_BUILD}
}

rvmk() {
  rvcfg && rvbuild
}

rvmkd() {
  rvcfgd && rvbuildd
}

rvbootstrap() {
  rvsetup && rvmk
}

rvbootstrapd() {
  rvsetup && rvmkd
}

export -f rvenv
export -f rvsetup
export -f rvcfg
export -f rvcfgd
export -f rvbuildt
export -f rvbuildtd
export -f rvbuild
export -f rvbuildd
export -f rvtest
export -f rvinst
export -f rvinstd
export -f rvclean
export -f rvmk
export -f rvmkd
export -f rvbootstrap
export -f rvbootstrapd
