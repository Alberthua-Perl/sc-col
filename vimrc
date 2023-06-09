"term
" 设置行号
set nu
" 按下 tab 键时的空格数
set tabstop=4
"set softtabstop=4
" 按下 tab 键自动转换为空格
set expandtab
" 自动缩进 4 个空格
set shiftwidth=4
" 支持使用鼠标操作
"set mouse=a
" 不创建备份文件
set nobackup
set cursorcolumn
"set cursorline
" 启用 UTF-8 编码格式
set encoding=utf-8
" 在状态栏显示当前光标的行列位置
set ruler
" 遇到括号自动识别匹配的括号
set showmatch
" 自动缩进，按下回车键后，下一行与上一行的缩进保持一致。
set autoindent
" 复制粘贴时保留原有的缩进
set copyindent
" 保持复制的原有格式（对 YAML 格式由其有用）
set paste
" 发生错误时屏幕闪烁提醒
"set visualbell

" 自动补全花括号
inoremap { {<CR>}<ESC>O
" 启用语法高亮自动识别代码
syntax on
colorscheme elflord
autocmd FileType yaml setlocal ai ts=2 sw=2 et

" 设置 NerdTree 使用 F3 按键启用与关闭
map <F3> :NERDTreeMirror<CR>
map <F3> :NERDTreeToggle<CR>
" 进入 Vim 自动启用 NERDTree 左侧边栏
"autocmd VimEnter * NERDTree
