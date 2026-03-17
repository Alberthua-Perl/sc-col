#!/bin/bash

read -p "请输入 autrace 追踪的进程：" PID

function title_line() {
    line1=$(printf "%*s" 60 "-" | tr ' ' '-')
    line2=$(printf "%*s" 30 "-" | tr ' ' '-')
    printf "+%-60s+%-30s+\n" $line1 $line2
    printf "| %-58s | %-28s |\n" "autrace: file" "autrace: syscall"
    printf "+%-60s+%-30s+\n" $line1 $line2
}

function tail_line() {
    line1=$(printf "%*s" 60 "-" | tr ' ' '-')
    line2=$(printf "%*s" 30 "-" | tr ' ' '-')
    printf "+%60s+%30s+\n" $line1 $line2
}

### 方法1 ###
title_line
ausearch --raw -p $PID | aureport -i -f | tail -n+6 | while IFS= read -r line; do
    file=$(echo $line | awk '{print $4}')
    syscall=$(echo $line | awk '{print $5}')
    [[ $file != "newfstatat" ]] && printf "| %-58s | %-28s |\n" $file $syscall
done
# 去除文件头部的 6 行；整行读入格式化；分别使用 awk 截取字段赋值；printf 命令格式化输出
tail_line

echo -e "\n ---------- 分隔线 ----------\n"
### 方法2 ###
title_line
ausearch --raw -p $PID | aureport -i -f | tail -n+6 | while IFS= read -r line; do
    awk '{ if ($4 != "newfstatat") printf "| %-58s | %-28s |\n", $4, $5 }'
done
# 简化方法1的写法
tail_line