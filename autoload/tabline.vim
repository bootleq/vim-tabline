" Variables: {{{

let s:DEFAULT_OPTIONS = {
      \ 'tab_min_width': 0,
      \ 'tab_max_width': 40,
      \ 'tab_min_shrinked_width': 15,
      \ 'scroll_off': 5,
      \ 'divide_equally': 0,
      \ 'ellipsis_text': '…',
      \ 'nofile_text': '[Scratch]',
      \ 'new_file_text': '[New]',
      \ 'modified_text': '+'
      \ }
let s:OPTION_PREFIX = 'tabline_'
lockvar! s:OPTION_PREFIX s:DEFAULT_OPTIONS

let s:tabs = []

" }}} Variables


" Main Functions: {{{

function! tabline#build() "{{{
  " NOTE: left/right padding of each tab was hard coded as 1 space.
  " NOTE: require Vim 7.3 strwidth() to display fullwidth text correctly.

  " settings
  let tab_min_width          = s:option('tab_min_width')
  let tab_max_width          = s:option('tab_max_width')
  let tab_min_shrinked_width = s:option('tab_min_shrinked_width')
  let scroll_off             = s:option('scroll_off')
  let divide_equally         = s:option('divide_equally')
  let ellipsis_text          = s:option('ellipsis_text')
  let nofile_text            = s:option('nofile_text')
  let new_file_text          = s:option('new_file_text')
  let modified_text          = s:option('modified_text')

  let s:tabs = []

  let tab_count = tabpagenr('$')
  let tab_current = tabpagenr()

  " fill s:tabs with {n, filename, split, flag} for each tab
  for i in range(tab_count)
    let tabnr = i + 1
    let buflist = tabpagebuflist(tabnr)
    let winnr = tabpagewinnr(tabnr)
    let bufnr = buflist[winnr - 1]

    let filename = bufname(bufnr)
    let filename = fnamemodify(filename, ':p:t')
    let buftype = getbufvar(bufnr, '&buftype')
    if filename == ''
      if buftype == 'nofile'
        let filename .= nofile_text
      else
        let filename .= new_file_text
      endif
    endif
    let split = ''
    let window_count = tabpagewinnr(tabnr, '$')
    if window_count > 1   " has split windows
      let split .= window_count
    endif
    let flag = ''
    if getbufvar(bufnr, '&modified')  " modified
      let flag .= modified_text
    endif
    if strlen(flag) > 0 || strlen(split) > 0
      let flag .= ' '
    endif

    call add(s:tabs, {'n': tabnr, 'split': split, 'flag': flag, 'filename': filename})
  endfor

  " variables for final oupout
  let s = ''
  let l:tabs = deepcopy(s:tabs)

  " overflow adjustment
  " 1. apply min/max tab_width option
  if s:total_length(l:tabs) > &columns
    unlet i
    for i in l:tabs
      let tab_length = s:tab_length(i)
      if tab_length < tab_min_width
        let i.filename .= repeat(' ', tab_min_width - tab_length)
      elseif tab_max_width > 0 && tab_length > tab_max_width
        let reserve = tab_length - s:string_width(i.filename) + s:string_width(ellipsis_text)
        if tab_max_width > reserve
          let i.filename = s:string_truncate(i.filename, (tab_max_width - reserve), '~') . ellipsis_text
        endif
      endif
    endfor
  endif
  " 2. try divide each tab equal-width
  if divide_equally
    if s:total_length(l:tabs) > &columns
      let divided_width = max([tab_min_width, tab_min_shrinked_width, &columns / tab_count, s:string_width(ellipsis_text)])
      unlet i
      for i in l:tabs
        let tab_length = s:tab_length(i)
        if tab_length > divided_width
          let i.filename = s:string_truncate(i.filename, divided_width - s:string_width(ellipsis_text), '~') . ellipsis_text
        endif
      endfor
    endif
  endif
  " 3. ensure visibility of current tab
  let rhs_width = 0
  let t = tab_count - 1
  let rhs_tab_start = min([tab_current - 1, tab_current - scroll_off])
  while t >= max([rhs_tab_start, 0])
    let tab = l:tabs[t]
    let tab_length = s:tab_length(tab)
    let rhs_width += tab_length
    let t -= 1
  endwhile
  while rhs_width >= &columns
    let tab = l:tabs[-1]
    let tab_length = s:tab_length(tab)
    let last_tab_space = &columns - (rhs_width - tab_length)
    let rhs_width -= tab_length
    if rhs_width > &columns
      call remove(l:tabs, -1)
    else
      " add special flag (will be removed later) indicating that how many
      " columns could be used for last displayed tab.
      if tab_current <= scroll_off || tab_current < tab_count - scroll_off
        let tab.flag .= '>' . last_tab_space
      endif
    endif
  endwhile

  " final ouput
  unlet i
  for i in l:tabs
    let tabnr = i.n

    let split = ''
    if strlen(i.split) > 0
      if tabnr == tab_current
        let split = '%#TabLineSplitNrSel#' . i.split .'%#TabLineSel#'
      else
        let split = '%#TabLineSplitNr#' . i.split .'%#TabLine#'
      endif
    endif

    let text = ' ' . split . i.flag . i.filename . ' '

    if i.n == l:tabs[-1].n
        if match(i.flag, '>\d\+') > -1 || i.n < tab_count
        let last_tab_space = matchstr(i.flag, '>\zs\d\+')
        let i.flag = substitute(i.flag, '>\d\+', '', '')
        if last_tab_space <= strlen(i.n)
          if last_tab_space == 0
            let s = strpart(s, 0, strlen(s) - 1)
          endif
          let s .= '%#TabLineMore#>'
          continue
        else
          let text = ' ' . i.split . i.flag . i.filename . ' '
          let text = s:string_truncate(text, (last_tab_space - strlen(i.n) - 1), '~') . '%#TabLineMore#>'
          let text = substitute(text, ' ' . i.split, ' ' . split, '')
        endif
        endif
    endif

    let s .= '%' . tabnr . 'T'  " start of tab N

    if tabnr == tab_current
      let s .= '%#TabLineNrSel#' . tabnr . '%#TabLineSel#'
    else
      let s .= '%#TabLineNr#' . tabnr . '%#TabLine#'
    endif

    let s .= text

  endfor

  let s .= '%#TabLineFill#%T'
  if exists('s:result_string') && s:result_string !=# s
    let s:dirty = 1
  endif
  let s:result_string = s
  return s
endfunction "}}}


function! tabline#tabs() "{{{
  return s:tabs
endfunction "}}}

" }}} Main Functions


" Utils: {{{

function! s:option(key) "{{{
  return get(g:, s:OPTION_PREFIX . a:key, get(s:DEFAULT_OPTIONS, a:key))
endfunction "}}}


function! s:tab_length(tab) "{{{
  return strlen(a:tab.n) + 2 + strlen(a:tab.split) + strlen(a:tab.flag) + s:string_width(a:tab.filename)
endfunction "}}}


function! s:total_length(dict) "{{{
  let length = 0
  for i in (a:dict)
    let length += strlen(i.n) + 2 + strlen(i.split) + strlen(i.flag) + s:string_width(i.filename)
  endfor
  return length
endfunction "}}}


function! s:string_width(string) "{{{
  if exists('*strwidth')
    return strwidth(a:string)
  else
    let strlen = strlen(a:string)
    let mstrlen = strlen(substitute(a:string, ".", "x", "g"))
    if strlen == mstrlen
      return strlen
    else
      " NOTE: do nothing for multibyte characters, can be incorrect
      return strlen
    endif
  endif
endfunction "}}}


function! s:string_truncate(string, len, ...) "{{{
  let pad_char = a:0 > 0 ? a:1 : ' '
  if exists('*strwidth')
    let text = substitute(a:string, '\%>' . a:len . 'c.*', '', '')
    let remain_chars = split(substitute(a:string, text, '', ''), '\zs')
    while strwidth(text) < a:len
      let longer = len(remain_chars) > 0 ? (text . remove(remain_chars, 0)) : text
      if strwidth(longer) < a:len
        let text = longer
      else
        let text .= pad_char
      endif
    endwhile
    return text
  else
    " NOTE: do nothing for multibyte characters, can be incorrect
    return substitute(a:string, '\%>' . a:len . 'c.*', '', '')
  endif
endfunction "}}}

" }}} Utils
