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
"	002	21-Oct-2011	Introduce g:RepeatableYank_DefaultRegister to
"				avoid error when using gy for the first time
"				without specifying a register. 
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
" as the last selection. The register must be handled first, though. 
nnoremap <expr> <SID>(Reselect) '1v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : '')
nnoremap <silent> <script> <Plug>RepeatableYankVisual :<C-u>call RepeatableYank#SetRegister()<CR><SID>(Reselect):<C-u>call RepeatableYank#Operator('visual', "\<lt>Plug>RepeatableYankVisual")<CR>

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
