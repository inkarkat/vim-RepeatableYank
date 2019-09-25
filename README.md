REPEATABLE YANK
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

Text fragments can be collected and accumulated by first yanking into a
lowercase register, and then subsequently yanking into the uppercase variant.
The problem is that the register must be specified on every yank command, and
one accidental failure to uppercase the register (i.e. slipping off the Shift
key) results in the irrecoverable loss of all fragments collected so far.

This can be somewhat remedied by enabling the non-default cpo-y setting,
which allows a repeat of a yank (plus remembered last register) via .

This plugin instead offers an alternative yank command gy, which allows to
specify the accumulator register only once on its initial use (and supports
accumulation into other writable registers like quotestar and quoteplus),
can then be repeated as an operator, linewise, in visual mode and via ., and
enhances some yank semantics for special cases.  For example, subsequent
blockwise yanks are merged as blocks to the right, instead of added below the
existing text blocks.

### RELATED WORKS

- AppendToClip ([vimscript #5118](http://www.vim.org/scripts/script.php?script_id=5118)) defines repeatable mappings that (delete and)
  append to the default register.

USAGE
------------------------------------------------------------------------------

    ["x]gy{motion}          Yank {motion} text into register x.
    [count]["x]gyy          Yank [count] lines into register x.
    {Visual}["x]gy          Yank the selected text into register x.

                            Subsequent gy commands without an explicit register
                            and command repeats via . will append the text to
                            the previously used register x, until another register
                            is explicitly given.
                            Therefore, you can gradually collect text in any
                            register (not just named registers; only the unnamed
                            register cannot be used directly).

                            Subsequent blockwise yanks are merged as blocks to the
                            right:
                                ab -> ab12
                                cd    cd34
                            instead of added below the existing text blocks:
                                ab -> ab
                                cd    cd
                                      12
                                      34

    ["x]gly{motion}         Yank {motion} text as a new line into register x.
    {Visual}["x]gly         Yank the selected text as a new line into register x.
                            When repeated, the text will be automatically
                            separated from the existing contents by a newline
                            character. This is useful for collecting individual
                            words (without surrounding whitespace), or other
                            phrases when you intend to work on them as separate
                            lines.

                            You can also use this mapping to avoid the special
                            RepeatableYank-block-merge behavior.

### EXAMPLE

Start by yanking "an entire line" into register a:

    "agyy

    an entire line

Add "another line" to the same register a without specifying it again:

    gyy

    an entire line
    another line

Add "word1" and "word2"; even though the register is now of linewise type,
these are added on a single line:

    gyw w.

    an entire line
    another line
    word1 word2

Now, let's yank a vertical block of "ABC" into another register:

    <C-V>2j "bgy

    A
    B
    C

Another vertical block of "123" is appended blockwise to the right:

    l1v.

    A1
    B2
    C3

You can build up multiple registers in parallel. To switch to another register
without starting over, just specify the uppercase register name:

    "Agyy

    an entire line
    another line
    word1 word2
    +addition after register switch

This is an example of gly:
Start by yanking "word1" into register a:

    "aglyi"

    word1

Add "word2" and "word3", but on separate lines, so that the register contents
don't turn into a mess of "word1word2word3":
    glyi"
    word1
    word2
    w.
    word1
    word2
    word3

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-RepeatableYank
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim RepeatableYank*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.039 or
  higher.
- repeat.vim ([vimscript #2136](http://www.vim.org/scripts/script.php?script_id=2136)) plugin (optional).
- visualrepeat.vim ([vimscript #3848](http://www.vim.org/scripts/script.php?script_id=3848)) plugin (version 2.00 or higher; optional)

CONFIGURATION
------------------------------------------------------------------------------

For a permanent configuration, put the following commands into your vimrc:

Since you don't need this plugin to repeat yanks to the unnamed register (just
use the built-in y), register "a is used as the default register, i.e. when
you use gy for the first time without explicitly specifying a register. To
change this default to another register (e.g. the clipboard), use:

    let g:RepeatableYank_DefaultRegister = '+'

If you want to use different mappings, map your keys to the
&lt;Plug&gt;RepeatableYank... mapping targets _before_ sourcing the script (e.g. in
your vimrc):

    nmap <Leader>y  <Plug>RepeatableYankOperator
    nmap <Leader>yy <Plug>RepeatableYankLine
    xmap <Leader>y  <Plug>RepeatableYankVisual
    nmap <Leader>ly <Plug>RepeatableYankAsLineOperator
    xmap <Leader>ly <Plug>RepeatableYankAsLineVisual

If you don't need the gly mappings introduced in version 1.10:

    nmap <Plug>DisableRepeatableYankAsLineOperator <Plug>RepeatableYankAsLineOperator
    xmap <Plug>DisableRepeatableYankAsLineVisual   <Plug>RepeatableYankAsLineVisual

CONTRIBUTING
------------------------------------------------------------------------------

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-RepeatableYank/issues or email (address below).

HISTORY
------------------------------------------------------------------------------

##### 1.30    RELEASEME
- BUG: {count}gyy does not repeat the count.
- Emulate appending to a non-named register (through use of a temporary named
  register). The previously advertised behavior of simply repeating a yank to
  the specified {09-\*+~/-} register turned out to be far less useful (at least
  to me and Enno Nagel, who suggested this enhancement) than the ability to
  consistently accumulate in any register.

__You need to update to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.039!__

##### 1.20    21-Nov-2013
- Use optional visualrepeat#reapply#VisualMode() for normal mode repeat of a
  visual mapping. When supplying a [count] on such repeat of a previous
  linewise selection, now [count] number of lines instead of [count] times the
  original selection is used.
- Avoid changing the jumplist.
- Add dependency to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)).

__You need to separately
  install ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.008 (or higher)!__

##### 1.10    27-Dec-2012
- ENH: Add alternative gly mapping to yank as new line.
- FIX: When appending a block consisting of a single line, the merge doesn't
  capture the new block at all.

##### 1.00    24-Sep-2012
- First published version.

##### 0.01    12-Sep-2011
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2011-2019 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
