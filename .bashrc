export AWS_PAGER=""

aws-profile() {
    if [ -z $1 ]; then
        echo $AWS_PROFILE
    else
        export AWS_PROFILE=$1
    fi
}