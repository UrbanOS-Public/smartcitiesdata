#! /bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color
exit_code=0

#Check that version in README.md matches what is in mix.exs
build_output=$(mix hex.build) 
current_version=$(echo "$build_output" | grep 'Version:' | awk '{print $2}')
app_name=$(echo "$build_output" | grep 'Building' | awk '{print $2}')
grep -q "{:$app_name, \"~> $current_version" README.md
if [ $? == 1 ]; then 
    echo -e "${RED}Update the version number in README.md to $current_version\r\n" 
    exit_code=1
fi

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
    exit_code=1
fi

exit $exit_code