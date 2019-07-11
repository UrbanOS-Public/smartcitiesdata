#! /bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color
exit_code=0

mix format

echo -e "${NC}mix credo - compiling code there may be a delay"
compile_output=$(mix compile 2>/dev/null) ##Supress compile output and warnings

credo_output=$(mix credo --format=oneline)
if [ $? != 0 ]; then
    echo -e "${RED}$credo_output${NC}\r\n"
    exit_code=1
fi

outdated_output=$(mix hex.outdated)
if [ $? == 1 ]; then
    echo -e "${NC}Outdated dependencies"
    echo -e "$outdated_output" | grep "Dependency"
    echo -en "${RED}"
    echo -e "$outdated_output" | grep " No"
    echo -e "$outdated_output" | grep " Yes"
    echo -e "${NC}"
fi

echo -e "Running Sobelow Security Checks"
mix sobelow -i Config.HTTPS --skip --compact --exit low
if [ $? == 1 ]; then
    exit_code=1
fi

exit $exit_code
