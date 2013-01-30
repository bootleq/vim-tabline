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
  let scroll_off             = s:option('scroll_off')
  let ellipsis_text          = s:option('ellipsis_text')

  let s:tabs = []

  let s:tab_count = tabpagenr('$')
  let s:tab_current = tabpagenr()
  let s:output = ''

  call s:parse_tabs()

  " variables for final oupout
  let tabs = deepcopy(s:tabs)

  " overflow adjustment
  " 1. apply min/max tab_width option
  if s:total_length(tabs) > &columns
    for tab in tabs
      let tab_length = s:tab_length(tab)
      if tab_length < tab_min_width
        let tab.filename .= repeat(' ', tab_min_width - tab_length)
      elseif tab_max_width > 0 && tab_length > tab_max_width
        let least_visible = tab_length - s:string_width(tab.filename) + s:string_width(ellipsis_text)
        if tab_max_width > least_visible
          let tab.filename = s:string_truncate(tab.filename, (tab_max_width - least_visible), '~') . ellipsis_text
        endif
      endif
    endfor
  endif

  " 2. try divide each tab equal-width
  if s:option('divide_equally')
    if s:total_length(tabs) > &columns
      let target_length = max([tab_min_width, s:option('tab_min_shrinked_width'), &columns / s:tab_count, s:string_width(ellipsis_text)])
      for tab in tabs
        let tab_length = s:tab_length(tab)
        if tab_length > target_length
          let tab.filename = s:string_truncate(tab.filename, target_length - s:string_width(ellipsis_text), '~') . ellipsis_text
        endif
      endfor
    endif
  endif

  " 3. ensure visibility of current tab
  let rhs_length = 0
  let rhs_iter = s:tab_count - 1
  let rhs_start = min([s:tab_current - 1, s:tab_current - scroll_off])
  while rhs_iter >= max([rhs_start, 0])
    let tab = tabs[rhs_iter]
    let tab_length = s:tab_length(tab)
    let rhs_length += tab_length
    let rhs_iter -= 1
  endwhile

  while rhs_length >= &columns
    let tab = tabs[-1]
    let tab_length = s:tab_length(tab)
    let last_tab_length = &columns - (rhs_length - tab_length)
    let rhs_length -= tab_length
    if rhs_length > &columns
      call remove(tabs, -1)
    else
      " add special flag (will be removed later) indicating that how many
      " columns could be used for last displayed tab.
      if s:tab_current <= scroll_off || s:tab_current < s:tab_count - scroll_off
        let tab.flag .= '>' . last_tab_length
      endif
    endif
  endwhile

  " final ouput
  for tab in tabs
    let tabnr = tab.n
    let split = ''
    let text = ''

    if strlen(tab.split) > 0
      if tabnr == s:tab_current
        let split = '%#TabLineSplitNrSel#' . tab.split .'%#TabLineSel#'
      else
        let split = '%#TabLineSplitNr#' . tab.split .'%#TabLine#'
      endif
    endif

    let text = ' ' . split . tab.flag . tab.filename . ' '

    if tab.n == tabs[-1].n
      if match(tab.flag, '>\d\+') > -1 || tab.n < s:tab_count
        let last_tab_length = matchstr(tab.flag, '>\zs\d\+')
        let tab.flag = substitute(tab.flag, '>\d\+', '', '')
        if last_tab_length <= strlen(tab.n)
          if last_tab_length == 0
            let s:output = strpart(s:output, 0, strlen(s:output) - 1)
          endif
          let s:output .= '%#TabLineMore#>'
          continue
        else
          let text = ' ' . tab.split . tab.flag . tab.filename . ' '
          let text = s:string_truncate(text, (last_tab_length - strlen(tab.n) - 1), '~') . '%#TabLineMore#>'
          let text = substitute(text, ' ' . tab.split, ' ' . split, '')
        endif
      endif
    endif

    let s:output .= '%' . tabnr . 'T'  " start of tab N

    if tabnr == s:tab_current
      let s:output .= '%#TabLineNrSel#' . tabnr . '%#TabLineSel#'
    else
      let s:output .= '%#TabLineNr#' . tabnr . '%#TabLine#'
    endif

    let s:output .= text

  endfor

  let s:output .= '%#TabLineFill#%T'
  if exists('s:result_string') && s:result_string !=# s:output
    let s:dirty = 1
  endif
  let s:result_string = s:output
  return s:output
endfunction "}}}


function! tabline#tabs() "{{{
  return s:tabs
endfunction "}}}


function! s:parse_tabs() "{{{
  " fill s:tabs with {n, filename, split, flag} for each tab
  for tab in range(s:tab_count)
    let tabnr = tab + 1
    let bufnr = tabpagebuflist(tabnr)[tabpagewinnr(tabnr) - 1]

    let filename = bufname(bufnr)
    let filename = fnamemodify(filename, ':p:t')
    let buftype = getbufvar(bufnr, '&buftype')
    if filename == ''
      if buftype == 'nofile'
        let filename .= s:option('nofile_text')
      else
        let filename .= s:option('new_file_text')
      endif
    endif

    let window_count = tabpagewinnr(tabnr, '$')
    if window_count > 1
      let split = window_count
    else
      let split = ''
    endif

    let flag = ''
    if getbufvar(bufnr, '&modified')
      let flag .= s:option('modified_text')
    endif

    if strlen(flag) > 0 || strlen(split) > 0
      let flag .= ' '
    endif

    call add(s:tabs, {'n': tabnr, 'split': split, 'flag': flag, 'filename': filename})
  endfor
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
