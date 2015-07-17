execute pathogen#infect()

set backup
set backupdir=/tmp
set dir=/tmp

syntax enable
syntax on

filetype plugin indent on

au FileType javascript set dictionary+=$HOME/.vim/dict/node/dict/node.dict
au Filetype python set omnifunc=pythoncomplete#Complete

let g:pyflakes_use_quickfix=0
let g:pep8_map='<Leader>8'
let g:SuperTabDefaultCompletionType='context'
set completeopt=menuone,longest,preview
let g:syntastic_always_populate_loc_list=1

set background=dark
color gruvbox

"highlight colorcolumn term=bold cterm=bold ctermbg=none
"let &colorcolumn=join(range(81,999),",")
":hi LineTooLong cterm=bold ctermbg=red guibg=LightYellow
hi link LineTooLong ColorColumn
call matchadd('LineTooLong', '\%>80v.\+')
"syn match LineTooLong '\%>80v.\+'

hi link ExtraWhitespace ColorColumn
call matchadd('ExtraWhitespace', '\s\+$\|^\t*\zs \+')
set list listchars=tab:\ \ ,trail:·

set et!
set cursorline cursorcolumn
set ts=4 sts=0 sw=4 noexpandtab
set number ruler
set autoindent
set encoding=utf-8
set mouse=a

nmap ,n <Esc>:tabn<CR>
nmap ,p <Esc>:tabp<CR>
nmap ,t <Esc>:tabnew<CR>
