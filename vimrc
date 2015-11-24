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
"let g:jsx_ext_required=0
"let g:jshintprg="jsxhint"
let g:syntastic_javascript_checkers=['eslint']
let g:syntastic_javascript_eslint_exec='eslint'
let g:syntastic_javascript_eslint_args='-f compact'
"let g:syntastic_debug=1

set background=dark
color gruvbox
hi Normal ctermbg=none

"highlight colorcolumn term=bold cterm=bold ctermbg=none
"let &colorcolumn=join(range(81,999),",")
":hi LineTooLong cterm=bold ctermbg=red guibg=LightYellow
hi link LineTooLong ColorColumn
call matchadd('LineTooLong', '\%>80v.\+')
"syn match LineTooLong '\%>80v.\+'

hi link ExtraWhitespace ColorColumn
call matchadd('ExtraWhitespace', '\s\+$\|^\t*\zs \+')
set list lcs=tab:\|\ ,trail:·

set et!
set cursorline cursorcolumn
set ts=4 sts=0 sw=4 noexpandtab
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
