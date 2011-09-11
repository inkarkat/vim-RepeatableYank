" RepeatableYank.vim: Repeatable appending yank to a named register. 
"
" DEPENDENCIES:
"
" Copyright: (C) 2011 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	001	12-Sep-2011	file creation

" Avoid installing twice or when in unsupported Vim version. 
if exists('g:loaded_RepeatableYank') || (v:version < 700)
    finish
endif
let g:loaded_RepeatableYank = 1

function! s:SetRegister()
    let s:register = v:register
endfunction
function! s:RepeatableYankOperator( type, ... )
    if s:register == '"'
	" This is a repetition, append to the last register. 
	let l:useRegister = toupper(s:activeRegister)
    else
	let s:activeRegister = s:register
	let l:useRegister = s:register
    endif
    let l:yankCmd = '"' . l:useRegister . 'y'
"****D echomsg '****' s:register l:yankCmd
    if ! a:0
	" Repetition of the operatorfunc does not re-invoke
	" s:RepeatableYankOperatorExpression, so s:register would not be
	" updated. The repetition also restores the original v:register, so we
	" cannot use that for the update here, neither. To make the repetition
	" of the operatorfunc work as we want, we simply clear s:register. All
	" other (linewise, visual) invocations of this function will set
	" s:register again, anyhow. 
	let s:register = '"'
    endif

    " Must do this before clobbering the register. 
    let l:save_reg = getreg(l:useRegister)
    let l:save_regtype = getregtype(l:useRegister)

    " Once the regtype is 'V', subsequent characterwise yanks will be
    " linewise, too. Instead, we want them appended characterwise, in the
    " newline left by the previous linewise yank. 
    call setreg(l:useRegister, '', 'av')

    if a:type ==# 'visual'
	if visualmode() ==# "\<C-v>" && l:save_regtype[0] ==# "\<C-v>"
	    " When appending a blockwise selection to a blockwise register, we
	    " want the individual rows merged (so the new block is appended to
	    " the right), not (what is the built-in behavior) the new blocked
	    " appended below the existing block. 
	    let l:directRegister = tolower(l:useRegister)   " Cannot delete via uppercase register name. 
	    call setreg(l:directRegister, '', '')
	    execute 'normal! gv' . l:yankCmd

	    " Merge the old, saved blockwise register contents with the new ones
	    " by pasting both together in a scratch buffer. 

	    hide enew
	    execute 'normal! "' . l:directRegister . 'P'

	    " If the new block contains more rows than the register contents,
	    " the additional blocks are put into the first column unless we
	    " augment the register contents with empty lines. 
	    let l:rowOffset = len(split(getreg(l:directRegister), "\n")) - len(split(l:save_reg, "\n"))
	    let l:augmentedBlock = l:save_reg . repeat("\n", max([0, l:rowOffset]))
	    echomsg '**** augment' l:rowOffset string(l:augmentedBlock)
	    call setreg(l:directRegister, l:augmentedBlock, l:save_regtype)
	    execute 'normal! "' . l:directRegister . 'P'

	    execute "normal! \<C-v>G$\"" . l:directRegister . 'y'
	    buffer #
	    bdelete! #
	else
	    execute 'normal! gv' . l:yankCmd
	endif
    else
	" Note: Need to use an "inclusive" selection to make `] include the
	" last moved-over character. 
	let l:save_selection = &selection
	set selection=inclusive
	try
	    execute 'normal! `[' . (a:type ==# 'line' ? 'V' : 'v') . '`]' . l:yankCmd
	finally
	    let &selection = l:save_selection
	endtry
    endif

    if a:0
	silent! call repeat#set(a:1)
	silent! call visualrepeat#set_also("\<Plug>RepeatableYankVisual")
    else
	silent! call visualrepeat#set("\<Plug>RepeatableYankVisual")
    endif
endfunction
function! s:RepeatableYankOperatorExpression( opfunc )
    call s:SetRegister()
    let &opfunc = a:opfunc
    return 'g@'
endfunction

" This mapping repeats naturally, because it just sets global things, and Vim is
" able to repeat the g@ on its own. 
nnoremap <expr> <Plug>RepeatableYankOperator <SID>RepeatableYankOperatorExpression('<SID>RepeatableYankOperator')
" This mapping needs repeat.vim to be repeatable, because it contains of
" multiple steps (visual selection + 'c' command inside
" s:RepeatableYankOperator). 
nnoremap <silent> <Plug>RepeatableYankLine     :<C-u>call <SID>SetRegister()<Bar>execute 'normal! V' . v:count1 . "_\<lt>Esc>"<Bar>call <SID>RepeatableYankOperator('visual', "\<lt>Plug>RepeatableYankLine")<CR>
" Repeat not defined in visual mode. 
vnoremap <silent> <SID>RepeatableYankVisual :<C-u>call <SID>SetRegister()<Bar>call <SID>RepeatableYankOperator('visual', "\<lt>Plug>RepeatableYankVisual")<CR>
vnoremap <silent> <script> <Plug>RepeatableYankVisual <SID>RepeatableYankVisual
nnoremap <expr> <SID>Reselect '1v' . (visualmode() !=# 'V' && &selection ==# 'exclusive' ? ' ' : '')
nnoremap <silent> <script> <Plug>RepeatableYankVisual <SID>Reselect<SID>RepeatableYankVisual

if ! hasmapto('<Plug>RepeatableYankOperator', 'n')
    nmap <silent> gy <Plug>RepeatableYankOperator
endif
if ! hasmapto('<Plug>RepeatableYankLine', 'n')
    nmap <silent> gyy <Plug>RepeatableYankLine
endif
if ! hasmapto('<Plug>RepeatableYankVisual', 'x')
    xmap <silent> gy <Plug>RepeatableYankVisual
endif

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
