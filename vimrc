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
Plugin 'tpope/vim-fugitive'
Plugin 'ervandew/supertab'
Plugin 'tpope/vim-surround'
Plugin 'Shougo/vimproc.vim'
" Plugin 'roxma/nvim-completion-manager'
Plugin 'autozimu/LanguageClient-neovim'
Plugin 'junegunn/fzf'
Plugin 'scrooloose/nerdtree'

" Themes
Plugin 'morhetz/gruvbox'

" Languages
Plugin 'vim-scripts/actionscript'
" Plugin 'yuratomo/dotnet-complete'
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
Plugin 'leafgarland/typescript-vim'
Plugin 'Quramy/tsuquyomi'
Plugin 'fatih/vim-go'
Plugin 'jparise/vim-graphql'
Plugin 'posva/vim-vue'
Plugin 'derekwyatt/vim-scala'
Plugin 'udalov/kotlin-vim'
Plugin 'dart-lang/dart-vim-plugin'

call vundle#end()

set backup
set backupdir=/tmp
set dir=/tmp
set undodir=/tmp/nvim/undodir
set undofile

syntax enable
syntax on

filetype plugin indent on

"let g:SuperTabDefaultCompletionType='context'
set completeopt=menuone,longest,preview
let g:OmniSharp_timeout=1
set noshowmatch
set splitbelow
"set shell=bash
set autoread

" LSP
let g:LanguageClient_autoStart=1
let g:LanguageClient_serverCommands={}

" Neomake
autocmd! BufWritePost,BufReadPost * Neomake
let g:neomake_warning_sign={
			\ 'text': 'w»',
			\ 'texthl': 'Question',
			\ }
let g:neomake_error_sign={
			\ 'text': 'e»',
			\ 'texthl': 'WarningMsg',
			\ }
let g:neomake_open_list=0

" JavaScript
let g:LanguageClient_serverCommands['javascript']=['javascript-typescript-stdio']
"autocmd BufWritePost *.js silent !standard --fix %
au Filetype javascript set dictionary+=$HOME/.vim/dict/node/dict/node.dict
let g:neomake_javascript_enabled_makers=['eslint']
let g:js_context_colors_enabled=0
let javascript_highlight_all=1
let g:javascript_plugin_jsdoc=1
autocmd BufReadPre *.js let b:javascript_lib_use_underscore=1
autocmd BufReadPre *.js let b:javascript_lib_use_chai=1
autocmd BufReadPre *.js let b:javascript_lib_use_react=1

" TypeScript
let g:LanguageClient_serverCommands['typescript']=['javascript-typescript-stdio']
autocmd BufWritePost *.ts silent !tslint -o /dev/null --fix %
let g:neomake_typescript_enabled_makers=['tslint', 'tsc']
let g:neomake_typescript_tslint_maker={
 \ 'exe': 'tslint',
 \ 'args': ['-t', 'msbuild']
 \ }

" Vue
let g:LanguageClient_serverCommands['vue']=['vls']

" Python
let g:LanguageClient_serverCommands['python']=['pyls']
let g:neomake_python_enabled_makers=['pylint']
" au Filetype python set omnifunc=pythoncomplete#Complete
" let g:pyflakes_use_quickfix=0
" let g:pep8_map='<Leader>8'
" let python_highlight_all=1

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

" Go
let g:LanguageClient_serverCommands['go']=['go-langserver']
let g:go_highlight_functions=1
let g:go_highlight_methods=1
let g:go_highlight_fields=1
let g:go_highlight_types=1
let g:go_highlight_operators=1
let g:go_highlight_build_constraints=1

" Rust
let g:LanguageClient_serverCommands['rust']=['rustup', 'run', 'stable', 'rls']
"au FileType rust compiler cargo
"let g:racer_cmd='/usr/bin/racer'
let g:rustfmt_autosave=1
"let g:neomake_rust_rustc_maker={
"  \ 'exe': 'rustc',
"  \ 'args': [
"  \   '-L', 'target/debug/deps',
"  \   '--crate-type', 'lib'
"  \ ]
"  \ }
"let g:ycm_rust_src_path='~/.rustup/toolchains/nightly-x86_64-unknown-linux-gnu/lib/rustlib/src'

" Dart
let dart_style_guide=2
let g:LanguageClient_serverCommands['dart']=['dart_language_server']

set background=light
let g:gruvbox_contrast_light="hard"
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
nmap <C-n> :NERDTreeToggle<CR>

" Tabs
nmap ,n <Esc>:tabn<CR>
nmap ,p <Esc>:tabp<CR>
nmap ,t <Esc>:tabnew<CR>
nmap <Leader><Tab> <Esc>:tabn<CR>

" Neovim's terminal
tnoremap <Leader>e <C-\><C-n>
au TermOpen * setlocal nonumber norelativenumber

" Tagbar
"let g:tagbar_usearrows=1
"nnoremap <Leader>l <Esc>:TagbarToggle<CR>

" Clipboard
vnoremap <leader>y  "+y
nnoremap <leader>Y  "+yg_
nnoremap <leader>y  "+y
nnoremap <leader>yy  "+yy
nnoremap <leader>p "+p
nnoremap <leader>P "+P
vnoremap <leader>p "+p
vnoremap <leader>P "+P
