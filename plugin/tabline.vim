if exists('g:loaded_tabline')
  finish
endif
let g:loaded_tabline = 1
let s:save_cpo = &cpoptions
set cpoptions&vim

let s:old_tabline = &tabline
if empty(&tabline)
  set tabline=%!tabline#build()
endif


" Default Options: {{{

function! s:set_default(name, value)
  if !exists(a:name)
    execute "let " . a:name . " = " . string(a:value)
  endif
endfunction

" }}} Default Options


" Interface: {{{

" }}} Interface


" Finish:  {{{

let &cpoptions = s:save_cpo
unlet s:save_cpo

" }}} Finish


" modeline {{{
" vim: expandtab softtabstop=2 shiftwidth=2 foldmethod=marker
