" RepeatableYank.vim: Repeatable appending yank to a named register.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"   - repeat.vim (vimscript #2136) autoload script (optional)
"   - visualrepeat.vim (vimscript #3848) autoload script (optional)
"   - visualrepeat/reapply.vim autoload script (optional)
"
" Copyright: (C) 2011-2024 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.21.014	23-Aug-2016	BUG: {count}gyy does not repeat the count.
"				Add RepeatableYank#SetCount() and new
"				a:isRepeatCount argument to
"				ReplaceWithRegister#Operator() that then passes
"				the stored s:count to repeat#set()..
"   1.20.013	11-Jun-2013	Move ingobuffer#CallInTempBuffer() to
"				ingo#buffer#temp#Call().
"   1.20.012	18-Apr-2013	Add RepeatableYank#VisualMode() wrapper around
"				visualrepeat#reapply#VisualMode().
"   1.11.011	04-Apr-2013	Use ingo/compat.vim for strchars() and
"				strdisplaywidth().
"   1.11.010	21-Mar-2013	Avoid changing the jumplist.
"   1.10.009	27-Dec-2012	Need special case for turning blockwise register
"				into linewise to avoid that _two_ newlines are
"				appended.
"				FIX: When appending a block consisting of a
"				single line, the merge doesn't capture the new
"				block at all. With a single line, the cursor
"				position after the initial paste is different.
"				Explicitly move the cursor to column 1 via 0
"				first.
"   1.10.008	26-Dec-2012	ENH: Add alternative gly mapping to yank as new
"				line.
"   1.00.007	06-Dec-2011	Retire visualrepeat#set_also(); use
"				visualrepeat#set() everywhere.
"	006	07-Nov-2011	ENH: echo number of yanked lines, total lines
"				now in the register, and register name instead
"				of the default yank message (or nothing,
"				depending on 'report').
"				FIX: Suppress temporary paste and yank messages
"				in blockwise merge yank.
"	005	22-Oct-2011	Now that repeat.vim does not automatically
"				increase b:changedtick, mappings that do not
"				modify the buffer and repeat naturally need to
"				invoke repeat#invalidate().
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
function! RepeatableYank#SetCount()
    let s:count = v:count
endfunction
function! s:AdaptRegtype( useRegister, yanktype, isAsLine )
    if a:isAsLine
	if getregtype(a:useRegister) !=# 'V'
	    if getregtype(a:useRegister) ==# 'v'
		" This ensures a trailing newline character.
		call setreg(a:useRegister, '', 'aV')
	    else
		" XXX: Above appends two newline characters; probably, because
		" the change away from blockwise mode inserts the previously
		" implicit trailing newline, making the register characterwise;
		" then, the switch to linewise appends another newline.
		" Work around this by overwriting the contents with itself
		" instead of appending nothing.
		let l:directRegister = tolower(a:useRegister)   " Cannot override via uppercase register name.
		call setreg(l:directRegister, getreg(l:directRegister), 'V')
	    endif
	endif
    else
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
	\	'ingo#compat#strdisplaywidth(v:val)'
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

    call s:AdaptRegtype(a:useRegister, 'visual', 0)

    " When appending a blockwise selection to a blockwise register, we
    " want the individual rows merged (so the new block is appended to
    " the right), not (what is the built-in behavior) the new block
    " appended below the existing block.
    let l:directRegister = tolower(a:useRegister)   " Cannot delete via uppercase register name.
    call setreg(l:directRegister, '', '')
    execute 'silent normal! gv' . a:yankCmd

    " Merge the old, saved blockwise register contents with the new ones
    " by pasting both together in a scratch buffer.
    call ingo#buffer#temp#Call(function('RepeatableYank#TempMerge'), [l:directRegister, l:save_reg, l:save_regtype], 1)
endfunction
function! RepeatableYank#TempMerge( directRegister, save_reg, save_regtype )
    " First paste the new block, then paste the old register contents to
    " the left. Pasting to the right would be complicated when there's
    " an uneven right border; pasting to the left must account for
    " differences in the number of rows.
    execute 'silent normal! "' . a:directRegister . 'P'
    call setreg(a:directRegister, s:BlockAugmentedRegister(getreg(a:directRegister), a:save_reg, a:save_regtype), "\<C-v>")
    execute 'normal! 0"' . a:directRegister . 'P'

    execute "silent normal! 0\<C-v>G$\"" . a:directRegister . 'y'
endfunction
function! s:YankMessage( visualmode, yankedLines, content )
    if a:visualmode ==# 'v' && a:yankedLines == 1
	let l:message = 'text yanked'
    else
	let l:message = printf('%d line%s yanked', a:yankedLines, (a:yankedLines == 1 ? '' : 's'))
	if a:visualmode ==# "\<C-v>"
	    let l:message = 'block of ' . l:message
	endif
    endif
    let l:lineCnt = (a:content =~# '\n' ? len(split(a:content, "\n")) : 0)
    if l:lineCnt == 0
	let l:message .= printf('; %d characters total', ingo#compat#strchars(a:content))
    else
	let l:message .= printf('; %d line%s total', l:lineCnt, (l:lineCnt == 1 ? '' : 's'))
    endif

    let l:message .= ' in "' . s:activeRegister

    return l:message
endfunction
function! s:Operator( isAsLine, type, ... )
    let l:isRepetition = 0
    if s:register ==# ingo#register#Default()
	let l:isRepetition = 1
	if ! exists('s:activeRegister')
	    " First-time use of gy, without an explicit register.
	    let s:activeRegister = g:RepeatableYank_DefaultRegister
	    let l:useRegister = s:activeRegister
	else
	    " Append to the previously used register.
	    let l:useRegister = toupper(s:activeRegister)
	endif
    elseif ingo#register#IsWritable(s:register)
	let s:activeRegister = s:register
	let l:useRegister = s:register
    else
	execute "normal! \<C-\>\<C-n>\<Esc>" | " Beep.
	return
    endif

    if l:useRegister !~# '^\a$'
	" Cannot directly append to a non-named register. Use a named register
	" temporarily for the yank.
	let l:tempRegister = 'z'
	let l:save_reg = getreg(l:tempRegister)
	let l:save_regtype = getregtype(l:tempRegister)

	if s:register ==# ingo#register#Default()
	    " Repeated yank; transfer the register's contents to the temp
	    " register so that the yank is properly appended.
	    call setreg(l:tempRegister, getreg(l:useRegister), getregtype(l:useRegister))
	    let l:useRegister = toupper(l:tempRegister)
	else
	    " The register has just been specified; we want to accumulate from
	    " scratch.
	    call setreg(l:tempRegister, '')
	    let l:useRegister = l:tempRegister
	endif
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
	let s:register = ingo#register#Default()
    endif

    if a:type ==# 'visual'
	if l:isRepetition && visualmode() ==# "\<C-v>" && ! a:isAsLine
	    call s:BlockwiseMergeYank(l:useRegister, l:yankCmd)
	else
	    call s:AdaptRegtype(l:useRegister, a:type, a:isAsLine)
	    execute 'silent normal! gv' . l:yankCmd
	endif
    else
	call s:AdaptRegtype(l:useRegister, a:type, a:isAsLine)

	" Note: Need to use an "inclusive" selection to make `] include the
	" last moved-over character.
	let l:save_selection = &selection
	set selection=inclusive
	try
	    execute 'silent normal! g`[' . (a:type ==# 'line' ? 'V' : 'v') . 'g`]' . l:yankCmd
	finally
	    let &selection = l:save_selection
	endtry
    endif

    echomsg s:YankMessage(visualmode(), line("'>") - line("'<") + 1, getreg(l:useRegister))

    if exists('l:tempRegister')
	" Move the temp uppercase named register ...
	let [l:tempRegisterContent, l:tempRegisterType] = [getreg(l:tempRegister), getregtype(l:tempRegister)]

	" Restore the temp uppercase named register.
	call setreg(l:tempRegister, l:save_reg, l:save_regtype)

	" ... to the active register.
	call setreg(s:activeRegister, l:tempRegisterContent, l:tempRegisterType)

	" Because of the yank, the unnamed register is still aliased to the temp
	" register, and restoring it also updated it. That's unfortunate, as it
	" already contained the right content. Need to explicitly restore it.
	call setreg(ingo#register#Default(), l:tempRegisterContent, l:tempRegisterType)
    endif

    if a:0
	if a:0 >= 2 && a:2
	    silent! call repeat#set(a:1, s:count)
	else
	    silent! call repeat#set(a:1)
	endif
    else
	silent! call repeat#invalidate()
    endif
    silent! call visualrepeat#set(a:isAsLine ? "\<Plug>RepeatableYankAsLineVisual" : "\<Plug>RepeatableYankVisual")
endfunction
function! RepeatableYank#Operator( type, ... )
    return call('s:Operator', [0, a:type] + a:000)
endfunction
function! RepeatableYank#OperatorAsLine( type, ... )
    return call('s:Operator', [1, a:type] + a:000)
endfunction
function! RepeatableYank#OperatorExpression()
    call RepeatableYank#SetRegister()
    set opfunc=RepeatableYank#Operator
    return 'g@'
endfunction
function! RepeatableYank#OperatorAsLineExpression()
    call RepeatableYank#SetRegister()
    set opfunc=RepeatableYank#OperatorAsLine
    return 'g@'
endfunction

function! RepeatableYank#VisualMode()
    let l:keys = "1v\<Esc>"
    silent! let l:keys = visualrepeat#reapply#VisualMode(0)
    return l:keys
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
