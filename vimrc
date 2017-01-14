set nocompatible
"set filetype off

" Vundle
set runtimepath+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'VundleVim/Vundle.vim'

" Util
Plugin 'benekastah/neomake'
Plugin 'bling/vim-airline'
Plugin 'tpope/vim-dispatch'
Plugin 'mattn/emmet-vim'
Plugin 'airblade/vim-gitgutter'
Plugin 'jamessan/vim-gnupg'
Plugin 'yggdroot/indentline'
Plugin 'neovim/node-host'
Plugin 'moll/vim-node'
Plugin 'mizuchi/vim-ranger'
Plugin 'tpope/vim-sleuth'
Plugin 'ervandew/supertab'
Plugin 'tpope/vim-surround'

" Themes
Plugin 'morhetz/gruvbox'

" Languages
Plugin 'vim-scripts/actionscript'
Plugin 'yuratomo/dotnet-complete'
Plugin 'lambdatoast/elm.vim'
Plugin 'artur-shaik/vim-javacomplete2'
Plugin 'rustushki/javaimp.vim'
Plugin 'othree/javascript-libraries-syntax.vim'
Plugin 'pangloss/vim-javascript'
Plugin 'bigfish/vim-js-context-coloring'
Plugin 'omnisharp/omnisharp-vim'
Plugin 'vim-scripts/pep8'
Plugin 'digitaltoad/vim-pug'
Plugin 'pycqa/pyflakes'
Plugin 'hdima/python-syntax'
Plugin 'rust-lang/rust.vim'
Plugin 'racer-rust/vim-racer'
Plugin 'cespare/vim-toml'

call vundle#end()

set backup
set backupdir=/tmp
set dir=/tmp
set undodir=/tmp/nvim/undodir
set undofile


syntax enable
syntax on

filetype plugin indent on

let g:SuperTabDefaultCompletionType='context'
set completeopt=menuone,longest,preview
let g:OmniSharp_timeout = 1
set noshowmatch
set splitbelow

" Neomake
autocmd! BufWritePost,BufEnter * Neomake
let g:neomake_warning_sign={
  \ 'text': 'w»',
  \ 'texthl': 'Question',
  \ }
let g:neomake_error_sign={
  \ 'text': 'e»',
  \ 'texthl': 'WarningMsg',
  \ }

" Javascript
au Filetype javascript set dictionary+=$HOME/.vim/dict/node/dict/node.dict
let g:neomake_javascript_enabled_makers=['eslint']
let g:js_context_colors_enabled=0
let javascript_highlight_all=1
let g:javascript_plugin_jsdoc=1
autocmd BufReadPre *.js let b:javascript_lib_use_underscore=1
autocmd BufReadPre *.js let b:javascript_lib_use_chai=1
autocmd BufReadPre *.js let b:javascript_lib_use_react=1

" Python
au Filetype python set omnifunc=pythoncomplete#Complete
let g:pyflakes_use_quickfix=0
let g:pep8_map='<Leader>8'
let python_highlight_all=1

" C#
let g:OmniSharp_timeout=1
set noshowmatch
set completeopt=longest,menuone,preview
set splitbelow
au BufNewFile,BufRead *.xaml setf xml

" Java
autocmd FileType java setlocal omnifunc=javacomplete#Complete
let g:neomake_java_javac_options=['-d', '.']
let java_highlight_all=1
let java_highlight_functions=1
let java_highlight_java_lang_ids=1
let g:JavaImpPaths=
  \ $HOME . "/.m2/repository," .
  \ "./src/main/java"
let g:JavaImpDataDir="/tmp/javaimp"

set background=dark
color gruvbox
hi Normal ctermbg=none
let g:airline_powerline_fonts=1


set list lcs=tab:\|\ ,trail:·
set et!
set cursorline cursorcolumn
set ts=2 sts=0 sw=2 expandtab
set number ruler
set autoindent
set encoding=utf-8
set mouse=a

" Tabs
nmap ,n <Esc>:tabn<CR>
nmap ,p <Esc>:tabp<CR>
nmap ,t <Esc>:tabnew<CR>
nmap <Leader><Tab> <Esc>:tabn<CR>

" Neovim's terminal
tnoremap <Leader>e <C-\><C-n>

" Tagbar
let g:tagbar_usearrows=1
nnoremap <Leader>l <Esc>:TagbarToggle<CR>
