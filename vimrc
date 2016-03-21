execute pathogen#infect()

set backup
set backupdir=/tmp
set dir=/tmp

syntax enable
syntax on

filetype plugin indent on

" Filetypes & Completion & Syntax & Lint
au Filetype javascript set dictionary+=$HOME/.vim/dict/node/dict/node.dict
au Filetype python set omnifunc=pythoncomplete#Complete
au BufNewFile,BufRead *.xaml setf xml
let g:pyflakes_use_quickfix=0
let g:pep8_map='<Leader>8'
let g:SuperTabDefaultCompletionType='context'
set completeopt=menuone,longest,preview
let g:syntastic_always_populate_loc_list=1
"let g:jsx_ext_required=0
"let g:jshintprg="jsxhint"
let g:neomake_javascript_enabled_makers=['eslint']
"let g:syntastic_javascript_checkers=['eslint']
"let g:syntastic_javascript_eslint_exec='eslint'
"let g:syntastic_javascript_eslint_args='-f compact'
"let g:syntastic_debug=1
"let g:syntastic_cursor_column=0

let g:OmniSharp_timeout = 1
set noshowmatch
set splitbelow
let g:syntastic_cs_checkers = ['syntax', 'semantic', 'issues']

augroup omnisharp_commands
	autocmd!
	autocmd FileType cs setlocal omnifunc=OmniSharp#Complete
	"autocmd FileType cs nnoremap <leader>b :wa!<cr>:OmniSharpBuildAsync<cr>
	autocmd BufEnter,TextChanged,InsertLeave *.cs SyntasticCheck
	autocmd BufWritePost *.cs call OmniSharp#AddToProject()
	autocmd CursorHold *.cs call OmniSharp#TypeLookupWithoutDocumentation()
	autocmd FileType cs nnoremap gd :OmniSharpGotoDefinition<cr>
	autocmd FileType cs nnoremap <leader>fi :OmniSharpFindImplementations<cr>
	autocmd FileType cs nnoremap <leader>ft :OmniSharpFindType<cr>
	autocmd FileType cs nnoremap <leader>fs :OmniSharpFindSymbol<cr>
	autocmd FileType cs nnoremap <leader>fu :OmniSharpFindUsages<cr>
	autocmd FileType cs nnoremap <leader>fm :OmniSharpFindMembers<cr>
	autocmd FileType cs nnoremap <leader>x  :OmniSharpFixIssue<cr>
	autocmd FileType cs nnoremap <leader>fx :OmniSharpFixUsings<cr>
	autocmd FileType cs nnoremap <leader>tt :OmniSharpTypeLookup<cr>
	autocmd FileType cs nnoremap <leader>dc :OmniSharpDocumentation<cr>
	autocmd FileType cs nnoremap <C-K> :OmniSharpNavigateUp<cr>
	autocmd FileType cs nnoremap <C-J> :OmniSharpNavigateDown<cr>
augroup END

set updatetime=500
set cmdheight=2

nnoremap <leader><space> :OmniSharpGetCodeActions<cr>
vnoremap <leader><space> :call OmniSharp#GetCodeActions('visual')<cr>
nnoremap <leader>nm :OmniSharpRename<cr>
nnoremap <F2> :OmniSharpRename<cr>
command! -nargs=1 Rename :call OmniSharp#RenameTo("<args>")
nnoremap <leader>rl :OmniSharpReloadSolution<cr>
nnoremap <leader>cf :OmniSharpCodeFormat<cr>
nnoremap <leader>tp :OmniSharpAddToProject<cr>
nnoremap <leader>ss :OmniSharpStartServer<cr>
nnoremap <leader>sp :OmniSharpStopServer<cr>
nnoremap <leader>th :OmniSharpHighlightTypes<cr>
set hidden

set background=dark
color gruvbox
hi Normal ctermbg=none

hi link LineTooLong ColorColumn
call matchadd('LineTooLong', '\%>80v.\+')

hi link ExtraWhitespace ColorColumn
call matchadd('ExtraWhitespace', '\s\+$\| \+\ze\t\|[^\t]\zs\t\+')
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
