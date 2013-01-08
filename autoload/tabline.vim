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

let s:tabLineTabs = []

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

  let s:tabLineTabs = []

  let tabCount = tabpagenr('$')
  let tabSel = tabpagenr()

  " fill s:tabLineTabs with {n, filename, split, flag} for each tab
  for i in range(tabCount)
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
    let winCount = tabpagewinnr(tabnr, '$')
    if winCount > 1   " has split windows
      let split .= winCount
    endif
    let flag = ''
    if getbufvar(bufnr, '&modified')  " modified
      let flag .= modified_text
    endif
    if strlen(flag) > 0 || strlen(split) > 0
      let flag .= ' '
    endif

    call add(s:tabLineTabs, {'n': tabnr, 'split': split, 'flag': flag, 'filename': filename})
  endfor

  " variables for final oupout
  let s = ''
  let l:tabLineTabs = deepcopy(s:tabLineTabs)

  " overflow adjustment
  " 1. apply min/max tabWidth option
  if s:TabLineTotalLength(l:tabLineTabs) > &columns
    unlet i
    for i in l:tabLineTabs
      let tabLength = s:CalcTabLength(i)
      if tabLength < tab_min_width
        let i.filename .= repeat(' ', tab_min_width - tabLength)
      elseif tab_max_width > 0 && tabLength > tab_max_width
        let reserve = tabLength - StrWidth(i.filename) + StrWidth(ellipsis_text)
        if tab_max_width > reserve
          let i.filename = StrCrop(i.filename, (tab_max_width - reserve), '~') . ellipsis_text
        endif
      endif
    endfor
  endif
  " 2. try divide each tab equal-width
  if divide_equally
    if s:TabLineTotalLength(l:tabLineTabs) > &columns
      let divideWidth = max([tab_min_width, tab_min_shrinked_width, &columns / tabCount, StrWidth(ellipsis_text)])
      unlet i
      for i in l:tabLineTabs
        let tabLength = s:CalcTabLength(i)
        if tabLength > divideWidth
          let i.filename = StrCrop(i.filename, divideWidth - StrWidth(ellipsis_text), '~') . ellipsis_text
        endif
      endfor
    endif
  endif
  " 3. ensure visibility of current tab
  let rhWidth = 0
  let t = tabCount - 1
  let rhTabStart = min([tabSel - 1, tabSel - scroll_off])
  while t >= max([rhTabStart, 0])
    let tab = l:tabLineTabs[t]
    let tabLength = s:CalcTabLength(tab)
    let rhWidth += tabLength
    let t -= 1
  endwhile
  while rhWidth >= &columns
    let tab = l:tabLineTabs[-1]
    let tabLength = s:CalcTabLength(tab)
    let lastTabSpace = &columns - (rhWidth - tabLength)
    let rhWidth -= tabLength
    if rhWidth > &columns
      call remove(l:tabLineTabs, -1)
    else
      " add special flag (will be removed later) indicating that how many
      " columns could be used for last displayed tab.
      if tabSel <= scroll_off || tabSel < tabCount - scroll_off
        let tab.flag .= '>' . lastTabSpace
      endif
    endif
  endwhile

  " final ouput
  unlet i
  for i in l:tabLineTabs
    let tabnr = i.n

    let split = ''
    if strlen(i.split) > 0
      if tabnr == tabSel
        let split = '%#TabLineSplitNrSel#' . i.split .'%#TabLineSel#'
      else
        let split = '%#TabLineSplitNr#' . i.split .'%#TabLine#'
      endif
    endif

    let text = ' ' . split . i.flag . i.filename . ' '

    if i.n == l:tabLineTabs[-1].n
        if match(i.flag, '>\d\+') > -1 || i.n < tabCount
        let lastTabSpace = matchstr(i.flag, '>\zs\d\+')
        let i.flag = substitute(i.flag, '>\d\+', '', '')
        if lastTabSpace <= strlen(i.n)
          if lastTabSpace == 0
            let s = strpart(s, 0, strlen(s) - 1)
          endif
          let s .= '%#TabLineMore#>'
          continue
        else
          let text = ' ' . i.split . i.flag . i.filename . ' '
          let text = StrCrop(text, (lastTabSpace - strlen(i.n) - 1), '~') . '%#TabLineMore#>'
          let text = substitute(text, ' ' . i.split, ' ' . split, '')
        endif
        endif
    endif

    let s .= '%' . tabnr . 'T'  " start of tab N

    if tabnr == tabSel
      let s .= '%#TabLineNrSel#' . tabnr . '%#TabLineSel#'
    else
      let s .= '%#TabLineNr#' . tabnr . '%#TabLine#'
    endif

    let s .= text

  endfor

  let s .= '%#TabLineFill#%T'
  if exists('s:tabLineResult') && s:tabLineResult !=# s
    let s:tabLineNeedRedraw = 1
  endif
  let s:tabLineResult = s
  return s
endfunction "}}}

function! tabline#tabs() "{{{
  return s:tabLineTabs
endfunction "}}}

" }}} Main Functions


" Utils: {{{

function! s:option(key) "{{{
  return get(g:, s:OPTION_PREFIX . a:key, get(s:DEFAULT_OPTIONS, a:key))
endfunction "}}}


function! s:CalcTabLength(tab)
  return strlen(a:tab.n) + 2 + strlen(a:tab.split) + strlen(a:tab.flag) + StrWidth(a:tab.filename)
endfunction


function! s:TabLineTotalLength(dict)
  let length = 0
  for i in (a:dict)
    let length += strlen(i.n) + 2 + strlen(i.split) + strlen(i.flag) + StrWidth(i.filename)
  endfor
  return length
endfunction

" }}} Utils
