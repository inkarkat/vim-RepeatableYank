" RepeatableYank.vim: Repeatable appending yank to a named register. 
"
" DEPENDENCIES:
"   - ingobuffer.vim autoload script. 
"   - repeat.vim (vimscript #2136) autoload script (optional). 
"   - visualrepeat.vim autoload script (optional). 
"   - EchoWithoutScrolling.vim autoload script (only for Vim 7.0 - 7.2 for
"     strdisplaywidth() emulation)
"
" Copyright: (C) 2011 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS 
"	004	21-Oct-2011	Introduce g:RepeatableYank_DefaultRegister to
"				avoid error when using gy for the first time
"				without specifying a register. 
"				Split off autoload script. 
"	003	27-Sep-2011	Use ingobuffer#CallInTempBuffer() to hide and
"				reuse the implementation details of safe
"				execution in a scratch buffer. 
"	002	13-Sep-2011	Factor out s:BlockwiseMergeYank() and
"				s:BlockAugmentedRegister(). 
"				Factor out s:AdaptRegtype() and don't adapt
"				unconditionally to avoid inserting an additional
"				empty line when doing linewise-linewise yanks. 
"	001	12-Sep-2011	file creation

function! RepeatableYank#SetRegister()
    let s:register = v:register
endfunction
function! s:AdaptRegtype( useRegister, yanktype )
    if a:yanktype ==# 'visual'
	let l:yanktype = visualmode()
    else
	" Adapt 'operatorfunc' string arguments to visualmode types. 
	let l:yanktype = {'char': 'v', 'line': 'V', 'block': "\<C-v>"}[a:yanktype]
    endif

    let l:regtype = getregtype(a:useRegister)[0]

    if l:regtype ==# 'V' && l:yanktype !=# 'V'
	" Once the regtype is 'V', subsequent characterwise yanks will be
	" linewise, too. Instead, we want them appended characterwise, after the
	" newline left by the previous linewise yank. 
	call setreg(a:useRegister, '', 'av')
    endif
endfunction
function! s:BlockAugmentedRegister( targetContent, content, type )
    " If the new block contains more rows than the register
    " contents, the additional blocks are put into the first column
    " unless we augment the register contents with spaced out lines. 
    let l:rowOffset = len(split(a:targetContent, "\n")) - len(split(a:content, "\n"))
    if len(a:type) > 1
	" The block width comes with the register. 
	let l:blockWidth = a:type[1:]
    else
	" If the register didn't contain a blockwise yank, we must determine the
	" width ourselves. 
	let l:blockWidth = max(
	\   map(
	\	split(a:content, "\n"),
	\	(exists('*strdisplaywidth') ?
	\	    'strdisplaywidth(v:val)' :
	\	    'EchoWithoutScrolling#DetermineVirtColNum(v:val)'
	\	)
	\   )
	\)
    endif
    let l:augmentedBlock = a:content . repeat("\n" . repeat(' ', l:blockWidth), max([0, l:rowOffset]))
"****D echomsg '****' l:rowOffset l:blockWidth string(l:augmentedBlock)
    return l:augmentedBlock
endfunction
function! s:BlockwiseMergeYank( useRegister, yankCmd )
    " Must do this before clobbering the register. 
    let l:save_reg = getreg(a:useRegister)
    let l:save_regtype = getregtype(a:useRegister)

    call s:AdaptRegtype(a:useRegister, 'visual')

    " When appending a blockwise selection to a blockwise register, we
    " want the individual rows merged (so the new block is appended to
    " the right), not (what is the built-in behavior) the new block
    " appended below the existing block. 
    let l:directRegister = tolower(a:useRegister)   " Cannot delete via uppercase register name. 
    call setreg(l:directRegister, '', '')
    execute 'normal! gv' . a:yankCmd

    " Merge the old, saved blockwise register contents with the new ones
    " by pasting both together in a scratch buffer. 
    call ingobuffer#CallInTempBuffer(function('RepeatableYank#TempMerge'), [l:directRegister, l:save_reg, l:save_regtype], 1)
endfunction
function! RepeatableYank#TempMerge(directRegister, save_reg, save_regtype)
    " First paste the new block, then paste the old register contents to
    " the left. Pasting to the right would be complicated when there's
    " an uneven right border; pasting to the left must account for
    " differences in the number of rows. 
    execute 'normal! "' . a:directRegister . 'P'

    call setreg(a:directRegister, s:BlockAugmentedRegister(getreg(a:directRegister), a:save_reg, a:save_regtype), "\<C-v>")
    execute 'normal! "' . a:directRegister . 'P'

    execute "normal! \<C-v>G$\"" . a:directRegister . 'y'
endfunction
function! RepeatableYank#Operator( type, ... )
    let l:isRepetition = 0
    if s:register ==# '"'
	let l:isRepetition = 1
	if ! exists('s:activeRegister')
	    " First-time use of gy, without an explicit register. 
	    let s:activeRegister = g:RepeatableYank_DefaultRegister
	    let l:useRegister = s:activeRegister
	else
	    " Append (in case of named registers) to the previously used
	    " register. Otherwise, overwrite the register contents. This can
	    " still be useful, e.g. to easily repeatedly yank to the clipboard. 
	    let l:useRegister = toupper(s:activeRegister)
	endif
    else
	let s:activeRegister = s:register
	let l:useRegister = s:register
    endif
    let l:yankCmd = '"' . l:useRegister . 'y'
"****D echomsg '****' s:register l:yankCmd
    if ! a:0
	" Repetition via '.' of the operatorfunc does not re-invoke
	" RepeatableYank#OperatorExpression, so s:register would not be
	" updated. The repetition also restores the original v:register, so we
	" cannot test that to recognize the repetition here, neither. To make
	" the repetition of the operatorfunc work as we want, we simply clear
	" s:register. All other (linewise, visual) invocations of this function
	" will set s:register again, anyhow. 
	let s:register = '"'
    endif

    if a:type ==# 'visual'
	if l:isRepetition && visualmode() ==# "\<C-v>"
	    call s:BlockwiseMergeYank(l:useRegister, l:yankCmd)
	else
	    call s:AdaptRegtype(l:useRegister, a:type)
	    execute 'normal! gv' . l:yankCmd
	endif
    else
	call s:AdaptRegtype(l:useRegister, a:type)

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
function! RepeatableYank#OperatorExpression()
    call RepeatableYank#SetRegister()
    set opfunc=RepeatableYank#Operator
    return 'g@'
endfunction

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :