"################
" 常规 vimrc 配置
"################

"保存 .vimrc 文件时自动重启加载，即让此文件立即生效。
autocmd BufWritePost $MYVIMRC source $MYVIMRC
"自动识别 YAML 格式文件并自动对齐
"autocmd FileType yaml setlocal ai ts=2 sw=2 et
"重新打开文件时，跳到上次的位置。
au BufReadPost *
\ if line("'\"") > 1 && line("'\"") <= line("$") |
\ exe "normal! g'\"" |
\ endif


"设置状态行显示的内容
"%F: 显示当前文件的完整路径
"%r: 如果 readonly 会显示 [RO]
"%B: 显示光标下字符的编码值，十六进制。
"%l: 光标所在的行号
"%v: 光标所在的虚拟列号
"%P: 显示当前内容在整个文件中的百分比
"%H 和 %M 是 strftime() 函数的参数，获取时间。
set statusline=%F%r\ [HEX=%B][%l,%v,%P]\ %{strftime(\"%H:%M\")}
"1：启动显示状态行
"2：总是显示状态行
"设置总是显示状态行方便看到当前文件名
set laststatus=2
"在状态栏显示当前光标的行列位置
set ruler

"发生错误时屏幕闪烁提醒
"set visualbell

"默认按下 Esc 后，需要等待 1 秒才生效，设置 Esc 超时时间为 100ms，尽快生效。
set ttimeout
set ttimeoutlen=100

"命令模式下显示输入的命令
set showcmd

"设置编码
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
set termencoding=utf-8
set encoding=utf-8

"设置语法高亮
syntax on

"设置行号
set nu  "等同于 set number

"突出显示当前行
set cursorline  "等同于 set cul
"突出显示当前列
set cursorcolumn  "等同于 set cuc

"按下 tab 键时占用的空格数
"set tabstop=4
"按下 tab 键自动转换为空格
set expandtab
"tab 键转换为多少个空格
set softtabstop=4
"自动缩进 4 个空格
set shiftwidth=4
"自动缩进，按下回车键后，下一行与上一行的缩进保持一致。
set autoindent
"智能缩进
"set smartindent
"复制粘贴时保留原有的缩进
set copyindent
"保持复制的原有格式（对 YAML 格式由其有用）
set paste
"显示空格和 tab 键
"set list
"set listchars=tab:>>,trail:.
set listchars=tab:>-,trail:-

"支持使用鼠标操作
"set mouse=a

"不创建备份文件
set nobackup
"自动保存
set autowrite

"遇到括号自动识别匹配的括号（高亮显示括号匹配）
set showmatch

"自动补全花括号
inoremap { {<CR>}<ESC>O

"设置字体
"set guifont=Courier_New:h10:cANSI
"设置背景主题
"color asmanian2
"设置颜色主题（适用于黑色背景）
colorscheme elflord

"设置 NerdTree 使用 F3 按键启用与关闭
map <F3> :NERDTreeMirror<CR>
map <F3> :NERDTreeToggle<CR>
" 进入 Vim 自动启用 NERDTree 左侧边栏
"autocmd VimEnter * NERDTree

