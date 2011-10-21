" RepeatableYank.vim: Repeatable appending yank to a named register. 
"
" DEPENDENCIES:
"   - Requires Vim 7.0 or higher. 
"   - RepeatableYank.vim autoload script. 
"
" Copyright: (C) 2011 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	003	21-Oct-2011	Introduce g:RepeatableYank_DefaultRegister to
"				avoid error when using gy for the first time
"				without specifying a register. 
"	002	21-Oct-2011	Note: <SID>Reselect swallows register repeat set
"				by repeat.vim. This doesn't matter here, because
"				we don't invoke repeat#setreg() and the default
"				register is treated as an append, anyway.
"				However, let's get rid of the
"				<SID>RepeatableYankVisual mapping and duplicate
"				the short invocation instead. 
"	001	21-Oct-2011	Split off functions to autoload file. 
"				file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_RepeatableYank') || (v:version < 700)
    finish
endif
let g:loaded_RepeatableYank = 1

"- configuration ---------------------------------------------------------------

if ! exists('g:RepeatableYank_DefaultRegister')
    let g:RepeatableYank_DefaultRegister = 'a'
endif


"- mappings --------------------------------------------------------------------

" This mapping repeats naturally, because it just sets global things, and Vim is
" able to repeat the g@ on its own. 
nnoremap <expr> <Plug>RepeatableYankOperator RepeatableYank#OperatorExpression()
" This mapping needs repeat.vim to be repeatable, because it contains of
" multiple steps (visual selection + 'c' command inside
" s:RepeatableYankOperator). 
nnoremap <silent> <Plug>RepeatableYankLine     :<C-u>call RepeatableYank#SetRegister()<Bar>execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>call RepeatableYank#Operator('visual', "\<lt>Plug>RepeatableYankLine")<CR>
" Repeat not defined in visual mode. 
vnoremap <silent> <Plug>RepeatableYankVisual :<C-u>call RepeatableYank#SetRegister()<Bar>call RepeatableYank#Operator('visual', "\<lt>Plug>RepeatableYankVisual")<CR>

" A normal-mode repeat of the visual mapping is triggered by repeat.vim. It
" establishes a new selection at the cursor position, of the same mode and size
" as the last selection. We do not need to handle the register first, because we
" don't want the register repeated (and therefore don't invoke repeat#setreg()).
" After <SID>(Reselect), v:register will contain the unnamed register, and that
" will trigger the desired append to s:activeRegister. 
nnoremap <expr> <SID>(Reselect) '1v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : '')
nnoremap <silent> <script> <Plug>RepeatableYankVisual <SID>(Reselect):<C-u>call RepeatableYank#SetRegister()<Bar>call RepeatableYank#Operator('visual', "\<lt>Plug>RepeatableYankVisual")<CR>

if ! hasmapto('<Plug>RepeatableYankOperator', 'n')
    nmap gy <Plug>RepeatableYankOperator
endif
if ! hasmapto('<Plug>RepeatableYankLine', 'n')
    nmap gyy <Plug>RepeatableYankLine
endif
if ! hasmapto('<Plug>RepeatableYankVisual', 'x')
    xmap gy <Plug>RepeatableYankVisual
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
