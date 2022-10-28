export AWS_PAGER=""

aws-profile() {
  if [ -z $1 ]; then
    echo $AWS_PROFILE
  else
    export AWS_PROFILE=$1
  fi
}

eval "$(starship init bash)"

source <(kubectl completion bash)

alias k=kubectl
complete -o default -F __start_kubectl k