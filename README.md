# minibuf-airline

A modern rewrite of the classic [MiniBufExpl][fholgado] Vim plugin, updated
for the era of [Nerd Fonts][nerdfonts] and [vim-airline][airline].

I have been using MiniBufExpl for 20 years, and it has been a constant companion through every stage of my Vim journey.  It is the one plugin I have never
considered replacing, but the original implementation could use some modernization.  This rewrite keeps the spirit of the original — a compact, always-on buffer list — while updating the visuals and fixing long-standing bugs.  The result is a more robust, visually appealing, and feature-rich buffer tabline that integrates seamlessly with modern Vim setups.It works great using NerdTree.

---

## What it looks like

With a [Nerd Font][nerdfonts] or [Powerline-patched font][powerline-fonts]:

```
 init.lua   util.lua ●   █ plugin.lua × █  old.vim            
```

Without (ASCII fallback mode):

```
 init.lua  |  util.lua +  |  plugin.lua x  |  old.vim         
```

**Tab colours at a glance:**

| Colour      | Meaning                                              |
|-------------|------------------------------------------------------|
| Dim grey    | Buffer is loaded but not visible in any window       |
| Medium grey | Buffer is visible in a non-active split              |
| Bold blue   | Active buffer — where your cursor is right now       |
| Orange fg   | Buffer has unsaved changes (`●` or `+` indicator)   |
| `×`         | Close button — appears on the active tab only        |
| ``         | Solid powerline arrow — colour transition between tabs |
| ``         | Thin arrow — between adjacent tabs of the same colour |

---

## The MiniBufExpl lineage

This plugin is a direct descendant of a 20-year chain of Vim plugins.
Understanding that history explains every design decision made here.

### 2001–2003 — Bindu Wavell (original)

Bindu Wavell wrote the first **minibufexpl.vim** around 2001 and released
it on [vim.org][vimorg-original].  The concept was simple and powerful: keep
a slim horizontal strip at the top (or bottom) of the screen showing every
open buffer as `[N:filename]`, with `+` for modified and `*` for visible.
It consumed exactly one line and required no extra screen width.

Wavell's implementation opened a genuine Vim window (a split), which meant
the plugin had to carefully manage window focus, window sizes, and the
interaction with every other plugin that touched windows.

### 2010–2011 — Community patches (Oliver Uvman, Danielle Church, Stephan Sokolow, Federico Holgado)

The original plugin accumulated numerous issues over the years as Vim grew
new features.  Several contributors sent patches; the copyright file reflects
Oliver Uvman, Danielle Church, and Stephan Sokolow among those who improved
it during 2010.  Federico Holgado ([@fholgado][fholgado-gh]) began a full
rewrite at the same time, eventually publishing it as a separate fork.

### 2012 — Federico Holgado's rewrite · [fholgado/minibufexpl.vim][fholgado]

Holgado's fork was a ground-up reimplementation.  Key additions:

- Distinguished *active* buffers (cursor here) from *visible* buffers
  (open in another split), with separate highlight groups for each
- Colour-coded `MBEVisibleActiveNormal` / `MBEVisibleActiveChanged` groups
- Smarter duplicate-filename handling: shows `parent/file.txt` when two
  buffers share the same tail name
- A cleaner statusline for the MBE window itself
- Much better handling of splits and tab pages

This is the version most users know; it has over 1 000 stars on GitHub.

### 2013 — Techlive Zheng (weynhamz) · [techlivezheng/vim-plugin-minibufexpl][techlivezheng]

Development moved to Techlive Zheng's fork, with v6.5.0 published back to
the fholgado repository.  This release fixed the most deeply rooted bugs:

- MBE window is now **tab-local**: opening a new tab no longer corrupts the
  buffer list shown in other tabs
- Correct handling of `:bd`, `:bwipe`, and `:bunload` — the window layout is
  preserved when a buffer is deleted
- `QuitPre` autocmd used to handle `:q` cleanly and avoid accidental Vim exit
- MRU (most-recently-used) buffer cycling with `:MBEbf` / `:MBEbb`
- `:MBEToggleMRU` to switch between MRU and numeric listing order
- All-tab commands: `:MBEOpenAll`, `:MBECloseAll`, `:MBEToggleAll`
- Window-entering history preserved so other plugins (e.g., NERDTree) are not
  confused by the MBE window stealing focus

After v6.5.0 (June 2013) there have been no further releases from either
repository.  61 issues remain open on the fholgado repo as of 2026.

### 2026 — minibuf-airline (this plugin)

Thirteen years is a long time in Vim-plugin years.  Vim grew `set tabline`,
Nerd Fonts arrived, and vim-airline showed what a styled tabline could look
like.  This rewrite keeps the spirit of the original — a compact, always-on
buffer list — while modernising the implementation:

- **Uses `&tabline`** instead of a split window.  No windows are created or
  managed; every line of your editing area stays available.
- **Powerline arrow separators** between tabs of different colours, thin
  arrows between adjacent same-colour tabs.
- **Seven buffer states** with auto-generated separator highlight groups that
  produce the correct fg/bg colour for every possible transition.
- **Native click support** via Vim's `%N@func@` tabline mechanism.
  Left-click to switch; middle-click to close without breaking layout.
- **Safe buffer close** replicates the layout-preservation logic from
  Techlive Zheng's v6.5.0: every window showing the target buffer is
  switched to a replacement before `:bdelete` is called.
- **Vim 8.2+ awareness**: `BufModifiedSet` is used when available and falls
  back to `TextChanged` / `InsertLeave` on older Vim.

---

## Requirements

| Requirement | Notes |
|---|---|
| Vim 7.4 | Minimum |
| `set mouse=a` | For mouse click support (in your vimrc) |
| Nerd Font / Powerline font | For arrow glyphs; set `g:miniBufAirlinePowerline=0` without one |

The plugin works in both terminal Vim and gVim.  Neovim is supported but
not the primary target.

> **Note on clicking:** minibuf-airline uses a 1-line split window (the same
> approach as the original MiniBufExpl) rather than Vim's `&tabline`.
> This means double-clicking a buffer name always works regardless of Vim
> version, and no `tablineat` feature is needed.  Enable single-click with
> `let g:miniBufAirlineUseSingleClick = 1` in your vimrc.

---

## Installation

### vim-plug

```vim
Plug 'myneid/minibuf-airline'
```

### packer.nvim

```lua
use 'myneid/minibuf-airline'
```

### Manual

Copy `plugin/`, `autoload/`, and `doc/` into your `~/.vim/` directory, then:

```vim
:helptags ~/.vim/doc
```

---

## Quick start

```vim
" Minimum .vimrc config — assumes a Nerd Font is active in your terminal
let g:miniBufAirlinePowerline = 1   " set to 0 for ASCII mode

" Enable mouse so you can click tabs to switch (left-click) or close (middle-click)
set mouse=a

nnoremap <silent> <Tab>      :MBANext<CR>
nnoremap <silent> <S-Tab>    :MBAPrev<CR>
nnoremap <silent> <Leader>w  :MBAClose<CR>
```

---

## Options

All options can be set any time; changes take effect on the next tabline
redraw.

### `g:miniBufAirlineAutoStart` (default: `1`)

Start the plugin automatically.  Set to `0` to enable manually with
`:MBAEnable`.

### `g:miniBufAirlinePowerline` (default: `1`)

Use powerline arrow glyphs (`` `` `` ``).  Requires a
[Nerd Font][nerdfonts] or [Powerline-patched font][powerline-fonts].
Set to `0` for a plain `|` separator.

### `g:miniBufAirlineShowBufNr` (default: `0`)

Prefix each tab with the buffer number.  Handy if you use `:buffer N`
or `:MBANext` with counts.

```
 1 init.lua   2 util.lua ●   3 plugin.lua × 
```

### `g:miniBufAirlineShowModified` (default: `1`)

Show a `●` (powerline mode) or `+` (ASCII mode) on tabs with unsaved
changes.

### `g:miniBufAirlineShowClose` (default: `1`)

Show a `×` close button on the active tab.  Clicking it closes the buffer
without destroying the window layout.  Middle-click any tab for the same
effect.

### `g:miniBufAirlineMinBufs` (default: `1`)

Minimum number of listed buffers before the tabline is shown.  The original
MiniBufExpl defaulted to `2`.  Set to `2` to hide the tabline when only one
file is open:

```vim
let g:miniBufAirlineMinBufs = 2
```

### `g:miniBufAirlineCycleAround` (default: `1`)

Wrap around when `:MBANext` / `:MBAPrev` reaches the end of the list.

### `g:miniBufAirlineSortBy` (default: `'number'`)

Order of buffer tabs.  Options:

- `'number'` — buffer number order (stable; matches original MiniBufExpl)
- `'name'`   — alphabetical by filename tail

---

## Commands

| Command      | Description |
|---|---|
| `:MBAEnable`  | Enable the plugin |
| `:MBADisable` | Disable and restore Vim's built-in tabline |
| `:MBAToggle`  | Toggle on/off |
| `:MBANext`    | Switch to the next listed buffer |
| `:MBAPrev`    | Switch to the previous listed buffer |
| `:MBAClose`   | Close the current buffer, preserving window layout |

---

## Suggested mappings

```vim
" Cycle buffers with Tab / Shift-Tab
nnoremap <silent> <Tab>      :MBANext<CR>
nnoremap <silent> <S-Tab>    :MBAPrev<CR>

" Close buffer without breaking splits
nnoremap <silent> <Leader>w  :MBAClose<CR>

" Toggle the tabline
nnoremap <silent> <Leader>b  :MBAToggle<CR>
```

---

## Highlight groups

Override any of these after your `:colorscheme` to customise colours.  Wrap
overrides in a `ColorScheme` autocmd so they survive theme changes:

```vim
augroup MyMiniBufAirlineColors
  autocmd!
  autocmd ColorScheme * call s:SetMyMBAColors()
augroup END

function! s:SetMyMBAColors()
  " Change the active-buffer accent to green
  hi MBA_act    guifg=#ffffff guibg=#008000 cterm=bold gui=bold
  hi MBA_actmod guifg=#ffffff guibg=#5f8700 cterm=bold gui=bold
endfunction
```

| Group         | Default style         | Meaning |
|---|---|---|
| `MBA_norm`    | dim grey              | Background buffer (not visible) |
| `MBA_normmod` | dim grey, orange fg   | Background buffer, unsaved |
| `MBA_vis`     | medium grey           | Visible in a non-active window |
| `MBA_vismod`  | medium grey, orange fg| Visible, unsaved |
| `MBA_act`     | bold blue             | Active buffer (cursor here) |
| `MBA_actmod`  | bold orange-bg        | Active, unsaved |
| `MBA_fill`    | very dark bg          | Empty space after all tabs |

Separator groups are auto-generated as `MBA_sep_{left}_{right}` for every
pair of types (e.g. `MBA_sep_norm_act`).  Their fg equals the left type's
background and their bg equals the right type's background, which creates
the powerline arrow illusion.

---

## Colour palette (defaults)

These are the built-in cterm and GUI colours.  All are defined with both
`ctermbg`/`ctermfg` and `guibg`/`guifg` so the plugin works in terminal and
GUI Vim without extra configuration.

| Type      | ctermbg | guibg     | ctermfg | guifg     |
|-----------|---------|-----------|---------|-----------|
| `norm`    | 235     | `#262626` | 244     | `#808080` |
| `normmod` | 235     | `#262626` | 208     | `#ff8700` |
| `vis`     | 237     | `#3a3a3a` | 250     | `#bcbcbc` |
| `vismod`  | 237     | `#3a3a3a` | 214     | `#ffaf00` |
| `act`     | 31      | `#0087af` | 231     | `#ffffff` |
| `actmod`  | 166     | `#d75f00` | 231     | `#ffffff` |
| `fill`    | 233     | `#121212` | 239     | `#4e4e4e` |

---

## Migrating from MiniBufExpl

| MiniBufExpl setting           | minibuf-airline equivalent |
|---|---|
| `g:miniBufExplAutoStart`      | `g:miniBufAirlineAutoStart` |
| `g:miniBufExplBuffersNeeded`  | `g:miniBufAirlineMinBufs` |
| `g:miniBufExplShowBufNumbers` | `g:miniBufAirlineShowBufNr` |
| `g:miniBufExplSortBy`         | `g:miniBufAirlineSortBy` |
| `g:miniBufExplCycleArround`   | `g:miniBufAirlineCycleAround` |
| `:MBEbf` / `:MBEbb`          | `:MBANext` / `:MBAPrev` |
| `:MBEbd`                      | `:MBAClose` |
| `MBENormal` highlight         | `MBA_norm` |
| `MBEChanged` highlight        | `MBA_normmod` |
| `MBEVisibleNormal` highlight  | `MBA_vis` |
| `MBEVisibleActiveNormal`      | `MBA_act` |
| `MBEVisibleActiveChanged`     | `MBA_actmod` |

Settings that no longer apply: `g:miniBufExplVSplit`, `g:miniBufExplBRSplit`,
`g:miniBufExplSplitToEdge`, `g:miniBufExplMaxSize`, `g:miniBufExplMinSize`,
`g:miniBufExplTabWrap` — minibuf-airline uses `&tabline` and has no window to
split, size, or position.

---

## License

```
Copyright (C) 2002 & 2003  Bindu Wavell         (original minibufexpl.vim)
Copyright (C) 2010         Oliver Uvman
Copyright (C) 2010         Danielle Church
Copyright (C) 2010         Stephan Sokolow
Copyright (C) 2010 & 2011  Federico Holgado      (fholgado rewrite)
Copyright (C) 2013         Techlive Zheng         (v6.5.0 bugfixes)

Permission is hereby granted to use and distribute this code, with or
without modifications, provided that this copyright notice is copied with
it.  Like anything else that's free, minibuf-airline.vim is provided *as
is* and comes with no warranty of any kind, either expressed or implied.
In no event will the copyright holders be liable for any damages resulting
from the use of this software.
```

---

## Related projects

| Project | Description |
|---|---|
| [fholgado/minibufexpl.vim][fholgado] | The well-known 2012 rewrite; last active release |
| [techlivezheng/vim-plugin-minibufexpl][techlivezheng] | v6.5.0 development fork (2013) |
| [vim.org original][vimorg-original] | Bindu Wavell's original 2001 release |
| [vim-airline/vim-airline][airline] | The status/tabline plugin this plugin takes visual inspiration from |
| [ryanoasis/nerd-fonts][nerdfonts] | Patched fonts with the powerline and icon glyphs |
| [powerline/fonts][powerline-fonts] | The original powerline-patched font collection |

[fholgado]:       https://github.com/fholgado/minibufexpl.vim
[techlivezheng]:  https://github.com/techlivezheng/vim-plugin-minibufexpl
[vimorg-original]:https://www.vim.org/scripts/script.php?script_id=159
[airline]:        https://github.com/vim-airline/vim-airline
[nerdfonts]:      https://www.nerdfonts.com/
[powerline-fonts]:https://github.com/powerline/fonts
