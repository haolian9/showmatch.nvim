an user-land impl of nvim &showmatch

## why?

according to nvim/search.c::showmatch(),
the native &showmatch hijacks the cursor for &matchtime at most,
and turns insert-mode beam shape into normal-mode block shape.
it always distracts me.

also it seems &showmatch doesnt honor `hi MatchParen`.

## status
* just works (tm)
* the use of ffi may crash nvim

## prerequisites
* nvim 0.11.*
* haolian9/infra.nvim

## usage
* `:set noshowmatch`
* `:lua require'showmatch'.activate()`
