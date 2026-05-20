" minibuf-airline.vim - Modern buffer tabline with airline/powerline style
"
" Copyright (C) 2002 & 2003  Bindu Wavell         (original minibufexpl.vim)
" Copyright (C) 2010         Oliver Uvman
" Copyright (C) 2010         Danielle Church
" Copyright (C) 2010         Stephan Sokolow
" Copyright (C) 2010 & 2011  Federico Holgado      (fholgado rewrite)
" Copyright (C) 2013         Techlive Zheng         (v6.5.0 bugfixes)
"
" Permission is hereby granted to use and distribute this code, with or
" without modifications, provided that this copyright notice is copied with
" it.  Like anything else that's free, minibuf-airline.vim is provided *as
" is* and comes with no warranty of any kind, either expressed or implied.
" In no event will the copyright holders be liable for any damages resulting
" from the use of this software.
"
" Lineage:
"   minibufexpl.vim (2001)  - Bindu Wavell, original concept
"   minibufexpl.vim (2012)  - Federico Holgado (fholgado), full rewrite
"   vim-plugin-minibufexpl  - Techlive Zheng (weynhamz), v6.5.0 bugfixes
"   minibuf-airline.vim     - ground-up rewrite, airline/nerd-font visuals
"
" Key differences from the original:
"   - Uses Vim's native &tabline instead of a split window
"   - Powerline/nerd-font separators (  ) for tab-like appearance
"   - Airline-inspired highlight groups that adapt to colorscheme changes
"   - Mouse click support (left=switch, middle=close)
"   - No window splits consumed; zero screen real estate lost
"
" Requirements:
"   - Vim 7.4+ (tabline %@..@ click support requires patch 7.4.2311)
"   - A Nerd Font / Powerline-patched font for glyphs (optional but recommended)
"
" License: GPL-2.0 (same as original minibufexpl.vim)

if exists('g:loaded_minibuf_airline') | finish | endif
let g:loaded_minibuf_airline = 1

let s:save_cpo = &cpo
set cpo&vim

" ─────────────────────────────────────────────────────────────────────────────
" User-configurable options (set before plugin loads, or at any time)
" ─────────────────────────────────────────────────────────────────────────────

" Enable plugin on startup
let g:miniBufAirlineAutoStart    = get(g:, 'miniBufAirlineAutoStart',    1)

" Use powerline glyph separators (requires patched font).
" Set to 0 for plain ASCII separators.
let g:miniBufAirlinePowerline    = get(g:, 'miniBufAirlinePowerline',    1)

" Show buffer numbers before the filename
let g:miniBufAirlineShowBufNr    = get(g:, 'miniBufAirlineShowBufNr',    1)

" Show modified indicator (● with powerline font, + without)
let g:miniBufAirlineShowModified = get(g:, 'miniBufAirlineShowModified', 1)

" Show a × close button on the active buffer tab
let g:miniBufAirlineShowClose    = get(g:, 'miniBufAirlineShowClose',    1)

" Minimum number of listed buffers before the tabline appears (0 = always)
let g:miniBufAirlineMinBufs      = get(g:, 'miniBufAirlineMinBufs',      1)

" Wrap around when cycling past the first/last buffer
let g:miniBufAirlineCycleAround  = get(g:, 'miniBufAirlineCycleAround',  1)

" Sort listed buffers: 'number' (default) or 'name'
let g:miniBufAirlineSortBy       = get(g:, 'miniBufAirlineSortBy',    'number')

" ─────────────────────────────────────────────────────────────────────────────
" Commands
" ─────────────────────────────────────────────────────────────────────────────

command! MBAToggle   call minibufairline#toggle()
command! MBAEnable   call minibufairline#enable()
command! MBADisable  call minibufairline#disable()
command! MBANext     call minibufairline#cycle(1)
command! MBAPrev     call minibufairline#cycle(-1)
command! MBAClose    call minibufairline#close_buf(bufnr('%'))

" ─────────────────────────────────────────────────────────────────────────────
" Autocmds
" ─────────────────────────────────────────────────────────────────────────────

augroup MiniBufAirline
  autocmd!
  " Refresh highlights whenever the colorscheme changes
  autocmd ColorScheme * call minibufairline#setup_highlights()

  " Refresh the tabline on any buffer event that could change display
  autocmd BufEnter,BufLeave,BufAdd,BufDelete,BufWritePost *
        \ call minibufairline#refresh()

  " BufModifiedSet fires when the modified flag changes (Vim 8.2+)
  if exists('##BufModifiedSet')
    autocmd BufModifiedSet * call minibufairline#refresh()
  else
    " Fallback: catch modifications via TextChanged / InsertLeave
    autocmd TextChanged,TextChangedI,InsertLeave *
          \ call minibufairline#refresh()
  endif

  " Also refresh when switching tabs (tab-local buffer sets)
  autocmd TabEnter * call minibufairline#refresh()
augroup END

" ─────────────────────────────────────────────────────────────────────────────
" Startup
" ─────────────────────────────────────────────────────────────────────────────

if g:miniBufAirlineAutoStart
  " Delay until VimEnter so the colorscheme is already active
  autocmd MiniBufAirline VimEnter * call minibufairline#enable()
endif

let &cpo = s:save_cpo
unlet s:save_cpo
