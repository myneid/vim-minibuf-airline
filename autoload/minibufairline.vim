" autoload/minibufairline.vim - Core logic for minibuf-airline
"
" Uses a 1-line split window (like the original MiniBufExpl) instead of
" &tabline.  This gives reliable mouse-click support on all Vim versions
" without needing the tablineat feature.

let s:save_cpo = &cpo
set cpo&vim

" ─────────────────────────────────────────────────────────────────────────────
" Glyphs
" ─────────────────────────────────────────────────────────────────────────────

let s:GL = {
      \ 'sep_hard': "",
      \ 'sep_soft': "",
      \ 'lock':     "",
      \ 'modified': "●",
      \ 'close':    "×",
      \ }

let s:ASCII = {
      \ 'sep_hard': '',
      \ 'sep_soft': '|',
      \ 'lock':     '[ro]',
      \ 'modified': '+',
      \ 'close':    'x',
      \ }

function! s:G(key) abort
  return g:miniBufAirlinePowerline ? s:GL[a:key] : s:ASCII[a:key]
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Colour palette
" ─────────────────────────────────────────────────────────────────────────────

let s:BG = {
      \ 'norm':    [235, '#262626'],
      \ 'normmod': [235, '#262626'],
      \ 'vis':     [237, '#3a3a3a'],
      \ 'vismod':  [237, '#3a3a3a'],
      \ 'act':     [ 31, '#0087af'],
      \ 'actmod':  [166, '#d75f00'],
      \ 'fill':    [233, '#121212'],
      \ 'prefix':  [ 24, '#005f87'],
      \ }

let s:FG = {
      \ 'norm':    [244, '#808080'],
      \ 'normmod': [208, '#ff8700'],
      \ 'vis':     [250, '#bcbcbc'],
      \ 'vismod':  [214, '#ffaf00'],
      \ 'act':     [231, '#ffffff'],
      \ 'actmod':  [231, '#ffffff'],
      \ 'fill':    [239, '#4e4e4e'],
      \ 'prefix':  [231, '#ffffff'],
      \ }

let s:SOFT_SEP_FG = {
      \ 'norm':    [237, '#3a3a3a'],
      \ 'normmod': [237, '#3a3a3a'],
      \ 'vis':     [239, '#4e4e4e'],
      \ 'vismod':  [239, '#4e4e4e'],
      \ 'act':     [ 38, '#00afd7'],
      \ 'actmod':  [172, '#d78700'],
      \ 'fill':    [235, '#262626'],
      \ 'prefix':  [ 26, '#005faf'],
      \ }

" ─────────────────────────────────────────────────────────────────────────────
" State
" ─────────────────────────────────────────────────────────────────────────────

let s:enabled       = 0
let s:mbe_bufnr     = -1   " bufnr of the minibuf-airline window buffer
let s:last_real_buf = -1   " last non-MBE buffer that was active
let s:regions       = []   " [{start, end, hl, buf}] byte ranges for matching
let s:updating      = 0    " re-entrancy guard

let s:MBE_NAME = '-MiniBufAirline-'

" ─────────────────────────────────────────────────────────────────────────────
" Public API
" ─────────────────────────────────────────────────────────────────────────────

function! minibufairline#enable() abort
  call minibufairline#setup_highlights()
  call s:open_window()
  call s:setup_delete_key()
  let s:enabled = 1
endfunction

function! minibufairline#disable() abort
  call s:close_window()
  call s:teardown_delete_key()
  let s:enabled = 0
endfunction

function! minibufairline#toggle() abort
  if s:enabled
    call minibufairline#disable()
  else
    call minibufairline#enable()
  endif
endfunction

function! minibufairline#refresh() abort
  if !s:enabled || s:updating | return | endif
  " Track which real buffer was last active
  if bufnr('%') != s:mbe_bufnr
    let s:last_real_buf = bufnr('%')
  endif
  call s:update()
endfunction

function! minibufairline#cycle(dir) abort
  let l:bufs = s:listed_buffers()
  if empty(l:bufs) | return | endif
  " If cursor is in MBE window, operate on s:last_real_buf
  let l:cur = (bufnr('%') == s:mbe_bufnr) ? s:last_real_buf : bufnr('%')
  let l:idx = index(l:bufs, l:cur)
  if l:idx < 0
    call s:switch_to(l:bufs[0])
    return
  endif
  let l:n = l:idx + a:dir
  if g:miniBufAirlineCycleAround
    let l:n = (l:n + len(l:bufs)) % len(l:bufs)
  else
    let l:n = max([0, min([len(l:bufs) - 1, l:n])])
  endif
  call s:switch_to(l:bufs[l:n])
endfunction

" Close a buffer, switching any window showing it to a neighbour first.
function! minibufairline#close_buf(target) abort
  let l:bufs = s:listed_buffers()
  let l:idx  = index(l:bufs, a:target)
  if l:idx < 0 | return | endif

  if len(l:bufs) > 1
    let l:replacement = (l:idx < len(l:bufs) - 1)
          \ ? l:bufs[l:idx + 1] : l:bufs[l:idx - 1]
  else
    let l:replacement = -1
  endif

  for l:w in range(1, winnr('$'))
    if winbufnr(l:w) == a:target && l:w != bufwinnr(s:mbe_bufnr)
      execute l:w . 'wincmd w'
      if l:replacement > 0
        execute 'buffer ' . l:replacement
      else
        enew
      endif
    endif
  endfor

  execute 'bdelete ' . a:target
endfunction

" Called when user presses Enter / o / double-clicks in the MBE window.
function! minibufairline#select(split) abort
  if bufnr('%') != s:mbe_bufnr | return | endif
  let l:target = s:buf_at_col(col('.'))
  if l:target < 0 | return | endif
  wincmd p
  if winnr() == bufwinnr(s:mbe_bufnr)
    " wincmd p landed back in MBE; find a real window
    for l:w in range(1, winnr('$'))
      if l:w != bufwinnr(s:mbe_bufnr)
        execute l:w . 'wincmd w'
        break
      endif
    endfor
  endif
  if a:split == 0
    execute 'buffer ' . l:target
  elseif a:split == 1
    execute 'split | buffer ' . l:target
  elseif a:split == 2
    execute 'vsplit | buffer ' . l:target
  endif
endfunction

" Close whichever buffer the cursor is over in the MBE window.
function! minibufairline#close_at_cursor() abort
  if bufnr('%') != s:mbe_bufnr | return | endif
  let l:target = s:buf_at_col(col('.'))
  if l:target > 0
    call minibufairline#close_buf(l:target)
  endif
endfunction

" Move cursor left/right between buffer entries inside the MBE window.
function! minibufairline#move_cursor(dir) abort
  if bufnr('%') != s:mbe_bufnr | return | endif
  let l:cur_buf = s:buf_at_col(col('.'))
  let l:bufs    = s:listed_buffers()
  let l:idx     = index(l:bufs, l:cur_buf)
  if l:idx < 0 | return | endif
  let l:next_idx = l:idx + a:dir
  if l:next_idx < 0 || l:next_idx >= len(l:bufs) | return | endif
  let l:next_buf = l:bufs[l:next_idx]
  for l:r in s:regions
    if get(l:r, 'buf', -1) == l:next_buf
      call cursor(1, l:r.start)
      return
    endif
  endfor
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Delete-key mapping helpers
" ─────────────────────────────────────────────────────────────────────────────

let s:active_delete_key = ''

function! s:setup_delete_key() abort
  let l:key = get(g:, 'miniBufAirlineDeleteKey', '<Delete>')
  if empty(l:key) | return | endif
  execute 'nnoremap <silent> ' . l:key
        \ . ' :call minibufairline#close_buf(bufnr("%"))<CR>'
  let s:active_delete_key = l:key
endfunction

function! s:teardown_delete_key() abort
  if !empty(s:active_delete_key)
    execute 'nunmap ' . s:active_delete_key
    let s:active_delete_key = ''
  endif
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Highlight setup
" ─────────────────────────────────────────────────────────────────────────────

function! minibufairline#setup_highlights() abort
  for l:t in keys(s:BG)
    let l:extra = (l:t =~# '^act') ? ' cterm=bold gui=bold' : ''
    execute printf(
          \ 'hi MBA_%s ctermfg=%d ctermbg=%d guifg=%s guibg=%s%s',
          \ l:t,
          \ s:FG[l:t][0], s:BG[l:t][0],
          \ s:FG[l:t][1], s:BG[l:t][1],
          \ l:extra)
  endfor

  for l:left in keys(s:BG)
    for l:right in keys(s:BG)
      if l:left ==# l:right
        execute printf(
              \ 'hi MBA_sep_%s_%s ctermfg=%d ctermbg=%d guifg=%s guibg=%s',
              \ l:left, l:right,
              \ s:SOFT_SEP_FG[l:left][0], s:BG[l:left][0],
              \ s:SOFT_SEP_FG[l:left][1], s:BG[l:left][1])
      else
        execute printf(
              \ 'hi MBA_sep_%s_%s ctermfg=%d ctermbg=%d guifg=%s guibg=%s',
              \ l:left, l:right,
              \ s:BG[l:left][0], s:BG[l:right][0],
              \ s:BG[l:left][1], s:BG[l:right][1])
      endif
    endfor
  endfor
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Window management
" ─────────────────────────────────────────────────────────────────────────────

function! s:open_window() abort
  let l:save_win = winnr()

  if s:mbe_bufnr > 0 && bufexists(s:mbe_bufnr)
    let l:mbe_win = bufwinnr(s:mbe_bufnr)
    if l:mbe_win < 0
      execute 'topleft 1split'
      execute 'buffer ' . s:mbe_bufnr
    else
      execute l:mbe_win . 'wincmd w'
    endif
  else
    execute 'topleft 1split'
    silent execute 'edit ' . s:MBE_NAME
    let s:mbe_bufnr = bufnr('%')
    call s:setup_mbe_buffer()
  endif

  resize 1

  " Return to the editing window
  " (the save_win number may have shifted by +1 due to the new split)
  execute (l:save_win + 1) . 'wincmd w'
  call s:update()
endfunction

function! s:setup_mbe_buffer() abort
  setlocal buftype=nofile bufhidden=hide noswapfile
  setlocal nobuflisted nomodifiable
  setlocal nonumber norelativenumber
  setlocal nocursorline nocursorcolumn
  setlocal nolist nospell nowrap
  setlocal winfixheight
  setlocal filetype=minibufairline

  nnoremap <buffer> <silent> <CR>          :call minibufairline#select(0)<CR>
  nnoremap <buffer> <silent> o             :call minibufairline#select(0)<CR>
  nnoremap <buffer> <silent> s             :call minibufairline#select(1)<CR>
  nnoremap <buffer> <silent> v             :call minibufairline#select(2)<CR>
  nnoremap <buffer> <silent> d             :call minibufairline#close_at_cursor()<CR>
  nnoremap <buffer> <silent> l             :call minibufairline#move_cursor(1)<CR>
  nnoremap <buffer> <silent> h             :call minibufairline#move_cursor(-1)<CR>
  nnoremap <buffer> <silent> <right>       :call minibufairline#move_cursor(1)<CR>
  nnoremap <buffer> <silent> <left>        :call minibufairline#move_cursor(-1)<CR>
  nnoremap <buffer> <silent> <2-LeftMouse> :call minibufairline#select(0)<CR>

  " Optional single-click support (off by default to avoid stealing global mouse)
  if get(g:, 'miniBufAirlineUseSingleClick', 0)
    nnoremap <buffer> <silent> <LeftMouse>
          \ <LeftMouse>:call minibufairline#select(0)<CR>
  endif
endfunction

function! s:close_window() abort
  if s:mbe_bufnr < 0 | return | endif
  let l:win = bufwinnr(s:mbe_bufnr)
  if l:win > 0
    execute l:win . 'wincmd w'
    close
  endif
  if bufexists(s:mbe_bufnr)
    execute 'bwipeout! ' . s:mbe_bufnr
  endif
  let s:mbe_bufnr = -1
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Content update
" ─────────────────────────────────────────────────────────────────────────────

function! s:update() abort
  if s:updating | return | endif
  let s:updating = 1

  let l:mbe_win = bufwinnr(s:mbe_bufnr)
  if l:mbe_win < 0
    let s:updating = 0
    return
  endif

  let l:bufs = s:listed_buffers()
  let l:save_win = winnr()

  execute l:mbe_win . 'wincmd w'

  if empty(l:bufs)
    setlocal modifiable
    call setline(1, repeat(' ', winwidth(0)))
    setlocal nomodifiable
    call clearmatches()
    call matchadd('MBA_fill', '.*', -1)
  else
    let [l:text, l:regions] = s:render_line(l:bufs)
    let s:regions = l:regions

    setlocal modifiable
    call setline(1, l:text)
    setlocal nomodifiable

    call clearmatches()
    " Fill background at lowest priority
    call matchadd('MBA_fill', '.*', -1)
    " Region highlights at default priority (10)
    for l:r in l:regions
      if !empty(l:r.hl) && l:r.start <= l:r.end
        call matchaddpos(l:r.hl, [[1, l:r.start, l:r.end - l:r.start + 1]])
      endif
    endfor
  endif

  " Return to wherever we came from
  execute l:save_win . 'wincmd w'

  let s:updating = 0
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Rendering — builds the display string and region map
"
" Tracks byte positions (not display columns) throughout, because:
"   • len() counts bytes in Vim
"   • matchaddpos [line, col, len] uses bytes
"   • col('.') returns the byte column
" This makes all three consistent for click detection.
" ─────────────────────────────────────────────────────────────────────────────

function! s:render_line(bufs) abort
  let l:pl      = g:miniBufAirlinePowerline
  let l:text    = ''
  let l:regions = []
  let l:bcol    = 1   " next byte column to write (1-indexed)

  " ── Prefix ─────────────────────────────────────────────────────────────────
  let l:pfx      = get(g:, 'miniBufAirlinePrefix', ' ≡ ')
  let l:pfx_type = 'prefix'
  if !empty(l:pfx)
    let l:pfx_len = len(l:pfx)
    call add(l:regions, {'start': l:bcol, 'end': l:bcol + l:pfx_len - 1,
          \ 'hl': 'MBA_prefix', 'buf': -1})
    let l:text .= l:pfx
    let l:bcol += l:pfx_len
  else
    let l:pfx_type = ''
  endif

  " ── Buffer tabs ─────────────────────────────────────────────────────────────
  for l:i in range(len(a:bufs))
    let l:b    = a:bufs[l:i]
    let l:st   = s:buf_state(l:b)
    let l:type = s:buf_type(l:st)

    " Leading separator: from previous section into this tab
    if l:i == 0
      let l:prev_type = l:pfx_type
    else
      let l:prev_type = s:buf_type(s:buf_state(a:bufs[l:i - 1]))
    endif

    if !empty(l:prev_type)
      if l:pl
        let l:sep = (l:prev_type ==# l:type)
              \ ? s:G('sep_soft') : s:G('sep_hard')
        let l:sep_hl  = 'MBA_sep_' . l:prev_type . '_' . l:type
        let l:sep_len = len(l:sep)
        call add(l:regions, {'start': l:bcol, 'end': l:bcol + l:sep_len - 1,
              \ 'hl': l:sep_hl, 'buf': -1})
        let l:text .= l:sep
        let l:bcol += l:sep_len
      else
        " ASCII: plain space separator (no glyph between same-type tabs)
        if l:i > 0
          let l:pipe = ' | '
          let l:pipe_len = len(l:pipe)
          call add(l:regions, {'start': l:bcol, 'end': l:bcol + l:pipe_len - 1,
                \ 'hl': 'MBA_fill', 'buf': -1})
          let l:text .= l:pipe
          let l:bcol += l:pipe_len
        endif
      endif
    endif

    " Tab content — this is the region that maps to a buffer for click detection
    let l:content = ' '
    if g:miniBufAirlineShowBufNr
      let l:content .= l:b . ' '
    endif
    if getbufvar(l:b, '&readonly')
      let l:content .= s:G('lock') . ' '
    endif
    let l:content .= s:buf_name(l:b)
    if g:miniBufAirlineShowModified && l:st.modified
      let l:content .= ' ' . s:G('modified')
    endif
    if g:miniBufAirlineShowClose && l:st.active
      let l:content .= ' ' . s:G('close')
    endif
    let l:content .= ' '

    let l:content_len = len(l:content)
    call add(l:regions, {'start': l:bcol, 'end': l:bcol + l:content_len - 1,
          \ 'hl': 'MBA_' . l:type, 'buf': l:b})
    let l:text .= l:content
    let l:bcol += l:content_len

    " Trailing separator: out of this tab into next (or fill)
    " Sits inside this tab's logical region so clicking the arrow
    " switches to THIS buffer, not the next.
    if l:pl
      let l:next_type = (l:i + 1 < len(a:bufs))
            \ ? s:buf_type(s:buf_state(a:bufs[l:i + 1]))
            \ : 'fill'
      let l:sep = (l:type ==# l:next_type)
            \ ? s:G('sep_soft') : s:G('sep_hard')
      let l:sep_hl  = 'MBA_sep_' . l:type . '_' . l:next_type
      let l:sep_len = len(l:sep)
      call add(l:regions, {'start': l:bcol, 'end': l:bcol + l:sep_len - 1,
            \ 'hl': l:sep_hl, 'buf': l:b})
      let l:text .= l:sep
      let l:bcol += l:sep_len
    endif
  endfor

  " ── Fill ────────────────────────────────────────────────────────────────────
  let l:mbe_win  = bufwinnr(s:mbe_bufnr)
  let l:width    = (l:mbe_win > 0) ? winwidth(l:mbe_win) : 80
  let l:fill_len = max([0, l:width - strwidth(l:text)])
  if l:fill_len > 0
    let l:fill = repeat(' ', l:fill_len)
    call add(l:regions, {'start': l:bcol, 'end': l:bcol + l:fill_len - 1,
          \ 'hl': 'MBA_fill', 'buf': -1})
    let l:text .= l:fill
  endif

  return [l:text, l:regions]
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Click detection
" ─────────────────────────────────────────────────────────────────────────────

function! s:buf_at_col(byte_col) abort
  " Walk regions; trailing separator regions carry the buffer they belong to.
  for l:r in s:regions
    if a:byte_col >= l:r.start && a:byte_col <= l:r.end
      return get(l:r, 'buf', -1)
    endif
  endfor
  return -1
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Buffer helpers
" ─────────────────────────────────────────────────────────────────────────────

function! s:switch_to(bufnr) abort
  " If cursor is in MBE window, jump to the editing window first
  if bufnr('%') == s:mbe_bufnr
    wincmd p
    if winnr() == bufwinnr(s:mbe_bufnr)
      for l:w in range(1, winnr('$'))
        if l:w != bufwinnr(s:mbe_bufnr)
          execute l:w . 'wincmd w'
          break
        endif
      endfor
    endif
  endif
  execute 'buffer ' . a:bufnr
endfunction

function! s:listed_buffers() abort
  let l:bufs = []
  let l:i = 1
  while l:i <= bufnr('$')
    if buflisted(l:i) && s:buf_worth_showing(l:i)
      call add(l:bufs, l:i)
    endif
    let l:i += 1
  endwhile
  if g:miniBufAirlineSortBy ==# 'name'
    call sort(l:bufs, function('s:cmp_by_name'))
  endif
  return l:bufs
endfunction

function! s:buf_worth_showing(bufnr) abort
  " Hide the MBE window buffer itself
  if a:bufnr == s:mbe_bufnr | return 0 | endif
  " Hide empty unnamed scratch buffers (Vim's startup buffer)
  if bufname(a:bufnr) ==# '' && !getbufvar(a:bufnr, '&modified')
    return 0
  endif
  return 1
endfunction

function! s:cmp_by_name(a, b) abort
  let l:na = fnamemodify(bufname(a:a), ':t')
  let l:nb = fnamemodify(bufname(a:b), ':t')
  return l:na ==# l:nb ? 0 : l:na >? l:nb ? 1 : -1
endfunction

function! s:buf_state(bufnr) abort
  " Use s:last_real_buf as the reference for "active" when we are inside the
  " MBE window (bufnr('%') == s:mbe_bufnr during s:update()).
  let l:active = (bufnr('%') == s:mbe_bufnr)
        \ ? s:last_real_buf : bufnr('%')
  return {
        \ 'active':   (a:bufnr == l:active),
        \ 'visible':  s:is_visible(a:bufnr),
        \ 'modified': !!getbufvar(a:bufnr, '&modified'),
        \ 'readonly': !!getbufvar(a:bufnr, '&readonly'),
        \ }
endfunction

function! s:is_visible(bufnr) abort
  let l:w = 1
  while l:w <= winnr('$')
    " Exclude the MBE window itself from "visible" counts
    if winbufnr(l:w) == a:bufnr && l:w != bufwinnr(s:mbe_bufnr)
      return 1
    endif
    let l:w += 1
  endwhile
  return 0
endfunction

function! s:buf_type(state) abort
  if a:state.active
    return a:state.modified ? 'actmod' : 'act'
  elseif a:state.visible
    return a:state.modified ? 'vismod' : 'vis'
  else
    return a:state.modified ? 'normmod' : 'norm'
  endif
endfunction

function! s:buf_name(bufnr) abort
  let l:name = bufname(a:bufnr)
  if empty(l:name)
    return getbufvar(a:bufnr, '&buftype') ==# 'nofile' ? '[scratch]' : '[No Name]'
  endif
  let l:tail = fnamemodify(l:name, ':t')
  for l:b in s:listed_buffers()
    if l:b != a:bufnr && fnamemodify(bufname(l:b), ':t') ==# l:tail
      return fnamemodify(l:name, ':p:~:.:h:t') . '/' . l:tail
    endif
  endfor
  return l:tail
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
