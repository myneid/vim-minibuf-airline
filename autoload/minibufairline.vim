" autoload/minibufairline.vim - Core logic for minibuf-airline
"
" All public functions use the minibufairline# namespace so Vim lazy-loads
" this file on first call rather than at startup.

let s:save_cpo = &cpo
set cpo&vim

" ─────────────────────────────────────────────────────────────────────────────
" Glyphs
" ─────────────────────────────────────────────────────────────────────────────
"
" Powerline private-use block (requires a patched / Nerd Font):
"   U+E0B0  solid right-arrow   ❯ (hard left separator)
"   U+E0B1  thin  right-arrow   ❯ (soft left separator, same bg)
"   U+E0B2  solid left-arrow    ❮ (hard right separator)
"   U+E0B3  thin  left-arrow    ❮ (soft right separator, same bg)
"   U+E0A2  lock icon
"   U+25CF  black circle        ● (modified indicator, no font needed)
"   U+00D7  multiplication sign × (close, no font needed)

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
"
" Each "type" maps to a fg+bg pair in both cterm and gui colour spaces.
" Types:
"   norm      - unlisted / background buffer
"   normmod   - norm + unsaved changes
"   vis       - visible in a non-active window
"   vismod    - vis  + unsaved changes
"   act       - the buffer currently under the cursor
"   actmod    - act  + unsaved changes
"   fill      - empty space after all tabs
" ─────────────────────────────────────────────────────────────────────────────

" [cterm_index, '#rrggbb']
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

" Soft-separator foreground: slightly lighter than the shared background,
" so the thin glyph is subtly visible between same-type tabs.
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

let s:enabled = 0

" ─────────────────────────────────────────────────────────────────────────────
" Public API
" ─────────────────────────────────────────────────────────────────────────────

function! minibufairline#enable() abort
  call minibufairline#setup_highlights()
  set showtabline=2
  set tabline=%!minibufairline#tabline()
  let s:enabled = 1
  call s:setup_delete_key()
endfunction

function! minibufairline#disable() abort
  set showtabline=1
  set tabline=
  let s:enabled = 0
  call s:teardown_delete_key()
endfunction

function! minibufairline#toggle() abort
  if s:enabled
    call minibufairline#disable()
  else
    call minibufairline#enable()
  endif
endfunction

function! minibufairline#refresh() abort
  if s:enabled
    redrawtabline
  endif
endfunction

function! minibufairline#cycle(dir) abort
  let l:bufs = s:listed_buffers()
  if empty(l:bufs) | return | endif
  let l:cur = bufnr('%')
  let l:idx = index(l:bufs, l:cur)
  if l:idx < 0
    execute 'buffer ' . l:bufs[0]
    return
  endif
  let l:n = l:idx + a:dir
  if g:miniBufAirlineCycleAround
    let l:n = (l:n + len(l:bufs)) % len(l:bufs)
  else
    let l:n = max([0, min([len(l:bufs) - 1, l:n])])
  endif
  execute 'buffer ' . l:bufs[l:n]
endfunction

" Close a buffer without destroying window layout.
" Switches windows showing that buffer to an adjacent listed buffer first.
function! minibufairline#close_buf(bufnr) abort
  let l:bufs   = s:listed_buffers()
  let l:target = a:bufnr

  " Find a replacement buffer (prefer the next one, else the previous)
  let l:idx = index(l:bufs, l:target)
  if len(l:bufs) > 1
    let l:replacement = (l:idx < len(l:bufs) - 1)
          \ ? l:bufs[l:idx + 1]
          \ : l:bufs[l:idx - 1]
  else
    let l:replacement = -1
  endif

  " Switch every window showing the target buffer to the replacement
  for l:w in range(1, winnr('$'))
    if winbufnr(l:w) == l:target
      execute l:w . 'wincmd w'
      if l:replacement > 0
        execute 'buffer ' . l:replacement
      else
        enew
      endif
    endif
  endfor

  execute 'bdelete ' . l:target
  call minibufairline#refresh()
endfunction

" Called by Vim's %N@func@ tabline click mechanism.
" button: 'l' left, 'm' middle, 'r' right
function! minibufairline#switch(bufnr, clicks, button, mod) abort
  if a:button ==# 'm'
    call minibufairline#close_buf(a:bufnr)
  else
    execute 'buffer ' . a:bufnr
  endif
endfunction

" Click handler for the prefix label — absorbs the click, does nothing.
function! minibufairline#noop(...) abort
endfunction

" The tabline expression: called by Vim on every redraw.
function! minibufairline#tabline() abort
  let l:bufs = s:listed_buffers()
  if len(l:bufs) < g:miniBufAirlineMinBufs
    return '%#MBA_fill#'
  endif
  return s:render(l:bufs)
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Delete-key mapping helpers
" ─────────────────────────────────────────────────────────────────────────────

let s:active_delete_key = ''

function! s:setup_delete_key() abort
  let l:key = get(g:, 'miniBufAirlineDeleteKey', '<Delete>')
  if empty(l:key) | return | endif
  execute 'nnoremap <silent> ' . l:key . ' :call minibufairline#close_buf(bufnr("%"))<CR>'
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
"
" Defines all MBA_* highlight groups from the palette above.
" Re-run on ColorScheme so the groups survive :colorscheme changes.
" ─────────────────────────────────────────────────────────────────────────────

function! minibufairline#setup_highlights() abort
  " Base buffer-type groups
  for l:t in keys(s:BG)
    let l:extra = (l:t =~# '^act') ? ' cterm=bold gui=bold' : ''
    execute printf(
          \ 'hi MBA_%s ctermfg=%d ctermbg=%d guifg=%s guibg=%s%s',
          \ l:t,
          \ s:FG[l:t][0], s:BG[l:t][0],
          \ s:FG[l:t][1], s:BG[l:t][1],
          \ l:extra)
  endfor

  " Separator groups: MBA_sep_{left}_{right}
  " The separator glyph sits between sections; its fg = left section's bg
  " colour and its bg = right section's bg colour.  This creates the
  " "arrow cut out of the left section" effect.
  let l:all_types = keys(s:BG)
  for l:left in l:all_types
    for l:right in l:all_types
      if l:left ==# l:right
        " Soft separator: same bg, slightly lighter fg so the thin glyph shows
        execute printf(
              \ 'hi MBA_sep_%s_%s ctermfg=%d ctermbg=%d guifg=%s guibg=%s',
              \ l:left, l:right,
              \ s:SOFT_SEP_FG[l:left][0], s:BG[l:left][0],
              \ s:SOFT_SEP_FG[l:left][1], s:BG[l:left][1])
      else
        " Hard separator: fg = left bg, bg = right bg
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
" Tabline rendering
" ─────────────────────────────────────────────────────────────────────────────

function! s:render(bufs) abort
  let l:pl        = g:miniBufAirlinePowerline
  let l:clickable = has('tablineat')
  let l:line      = ''

  " ── Prefix label ───────────────────────────────────────────────────────────
  " Sits at position 0 and owns the click there, preventing Vim's built-in
  " 'create new tab page' from firing when the user clicks near the left edge.
  let l:pfx = get(g:, 'miniBufAirlinePrefix', ' ≡ ')
  if !empty(l:pfx)
    let l:first_type = s:buf_type(s:buf_state(a:bufs[0]))
    if l:clickable
      let l:line .= '%0@minibufairline#noop@'
    endif
    let l:line .= '%#MBA_prefix#' . l:pfx
    if l:pl
      let l:line .= '%#MBA_sep_prefix_' . l:first_type . '#' . s:G('sep_hard')
    endif
    if l:clickable
      let l:line .= '%X'
    endif
  endif

  for l:i in range(len(a:bufs))
    let l:b    = a:bufs[l:i]
    let l:st   = s:buf_state(l:b)
    let l:type = s:buf_type(l:st)

    " Type of the next tab (or fill) — needed for trailing separator colour
    if l:i + 1 < len(a:bufs)
      let l:next_type = s:buf_type(s:buf_state(a:bufs[l:i + 1]))
    else
      let l:next_type = 'fill'
    endif

    " ── Start click region ─────────────────────────────────────────────────
    if l:clickable
      let l:line .= '%' . l:b . '@minibufairline#switch@'
    endif

    " ── Tab content ────────────────────────────────────────────────────────
    let l:line .= '%#MBA_' . l:type . '#'
    let l:line .= ' '

    if g:miniBufAirlineShowBufNr
      let l:line .= l:b . ' '
    endif

    if getbufvar(l:b, '&readonly')
      let l:line .= s:G('lock') . ' '
    endif

    let l:line .= s:buf_name(l:b)

    if g:miniBufAirlineShowModified && l:st.modified
      let l:line .= ' ' . s:G('modified')
    endif

    if g:miniBufAirlineShowClose && l:st.active
      let l:line .= ' ' . s:G('close')
    endif

    let l:line .= ' '

    " ── Trailing separator (inside this tab's click region) ────────────────
    " The arrow glyph visually "comes out of" this tab, so clicking it
    " should switch to THIS buffer, not the next one.
    if l:pl
      let l:sep_hl   = 'MBA_sep_' . l:type . '_' . l:next_type
      let l:sep_char = (l:type ==# l:next_type) ? s:G('sep_soft') : s:G('sep_hard')
      let l:line .= '%#' . l:sep_hl . '#' . l:sep_char
    else
      " ASCII: pipe separator between tabs (not inside the last tab)
      if l:next_type !=# 'fill'
        let l:line .= '%#MBA_fill# ' . s:G('sep_soft') . ' '
      endif
    endif

    " ── End click region ───────────────────────────────────────────────────
    if l:clickable
      let l:line .= '%X'
    endif
  endfor

  " ── Fill ─────────────────────────────────────────────────────────────────
  let l:line .= '%#MBA_fill#%='

  return l:line
endfunction

" ─────────────────────────────────────────────────────────────────────────────
" Buffer helpers
" ─────────────────────────────────────────────────────────────────────────────

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

" Skip empty unnamed buffers (Vim's startup scratch buffer).
" Keep them if they have unsaved content so work is never silently hidden.
function! s:buf_worth_showing(bufnr) abort
  if bufname(a:bufnr) !=# ''
    return 1
  endif
  return !!getbufvar(a:bufnr, '&modified')
endfunction

function! s:cmp_by_name(a, b) abort
  let l:na = fnamemodify(bufname(a:a), ':t')
  let l:nb = fnamemodify(bufname(a:b), ':t')
  return l:na ==# l:nb ? 0 : l:na >? l:nb ? 1 : -1
endfunction

function! s:buf_state(bufnr) abort
  return {
        \ 'active':   (a:bufnr == bufnr('%')),
        \ 'visible':  s:is_visible(a:bufnr),
        \ 'modified': !!getbufvar(a:bufnr, '&modified'),
        \ 'readonly': !!getbufvar(a:bufnr, '&readonly'),
        \ }
endfunction

function! s:is_visible(bufnr) abort
  let l:w = 1
  while l:w <= winnr('$')
    if winbufnr(l:w) == a:bufnr
      return 1
    endif
    let l:w += 1
  endwhile
  return 0
endfunction

" Map a state dict to one of the palette type keys
function! s:buf_type(state) abort
  if a:state.active
    return a:state.modified ? 'actmod' : 'act'
  elseif a:state.visible
    return a:state.modified ? 'vismod' : 'vis'
  else
    return a:state.modified ? 'normmod' : 'norm'
  endif
endfunction

" Display name for a buffer: tail of the path, or [No Name] / [scratch]
function! s:buf_name(bufnr) abort
  let l:name = bufname(a:bufnr)
  if empty(l:name)
    let l:bt = getbufvar(a:bufnr, '&buftype')
    return l:bt ==# 'nofile' ? '[scratch]' : '[No Name]'
  endif
  let l:tail = fnamemodify(l:name, ':t')
  " Show parent dir when the filename alone is ambiguous (duplicate basenames)
  for l:b in s:listed_buffers()
    if l:b != a:bufnr && fnamemodify(bufname(l:b), ':t') ==# l:tail
      return fnamemodify(l:name, ':p:~:.:h:t') . '/' . l:tail
    endif
  endfor
  return l:tail
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
