# setup local user PS1 in /etc/profile.d/
# modified by hualongfeiyyy@163.com
if [[ $UID -eq 0 ]]; then
  #export PS1="\[\e[35m\]\u\[\e[m\]@\[\e[36m\]\h\[\e[m\]:\[\e[33m\]\w\[\e[m\] \[\e[1;31m\]#\[\e[m\] "
  export PS1="\u@\h:\w # "
else
  export PS1="\u@\h:\w \$ "
fi
