export EDITOR=nvim

alias vim=nvim
alias nv=nvim
alias v=nvim
alias nvims='nvim /tmp/scratch'
alias nvs='nvim /tmp/scratch'

alias c='codex'
alias cy='codex --yolo'
alias cys='OLD_DIR_CLYS=$(pwd) && cd ~/agent-scratch && codex --yolo && cd "$OLD_DIR_CLYS"'
alias codex-config='nvim ~/.codex/config.toml'

alias cly='claude --dangerously-skip-permissions'
alias clys='OLD_DIR_CLYS=$(pwd) && cd ~/agent-scratch && claude --dangerously-skip-permissions && cd "$OLD_DIR_CLYS"'

alias ni='ntfy-osc9'
alias n9='ntfy-osc9'

alias glggo='git log --graph --oneline'

alias dp='docker ps'
alias dcl='docker container ls'
alias dcla='docker container ls -a'
alias dcr='docker container rm'
alias dil='docker image ls'
alias dir='docker image rm'

alias dcu='docker compose up'
alias dcud='docker compose up -d'
alias dcd='docker compose down'
alias dcps='docker compose ps'

unalias docker-image-clean docker-container-clean 2>/dev/null

docker-image-clean() {
  local images
  images=$(docker image ls | grep '<none>' | awk '{print $3}')
  [[ -n $images ]] && docker image rm $=images
}

docker-container-clean() {
  local containers
  containers=$(docker container ls -a | grep 'Exited (' | awk '{print $1}')
  [[ -n $containers ]] && docker container rm $=containers
}

alias dic=docker-image-clean
alias dcc=docker-container-clean
