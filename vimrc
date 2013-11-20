execute pathogen#infect()

set backup
set backupdir=/tmp
set dir=/tmp

syntax enable
syntax on

filetype plugin indent on

au FileType javascript set dictionary+=$HOME/.vim/dict/node/dict/node.dict

set background=dark
color mango

highlight colorcolumn cterm=NONE ctermbg=234
let &colorcolumn=join(range(81,999),",")

set et!
set cursorline cursorcolumn
set ts=4 sts=0 sw=4 noexpandtab
set number ruler
set autoindent
set list listchars=tab:\ \ ,trail:·
set encoding=utf-8
set mouse=a

let g:syntastic_always_populate_loc_list=1

nmap ,n <Esc>:tabn<CR>
nmap ,p <Esc>:tabp<CR>
nmap ,t <Esc>:tabnew<CR>
