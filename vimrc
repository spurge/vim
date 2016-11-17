execute pathogen#infect()

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
let g:js_context_colors_enabled=1
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

set background=dark
color gruvbox
hi Normal ctermbg=none
let g:airline_powerline_fonts=1

hi link LineTooLong ColorColumn
call matchadd('LineTooLong', '\%>70v.\+')

hi link ExtraWhitespace ColorColumn
call matchadd('ExtraWhitespace', '\s\+$\| \+\ze\t\|[^\t]\zs\t\+')
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

" NerdTree
nmap <Leader>n <Esc>:NERDTreeToggle<CR>

" Neovim's terminal
tnoremap <Leader>e <C-\><C-n>

" Tagbar
let g:tagbar_usearrows=1
nnoremap <Leader>l <Esc>:TagbarToggle<CR>
