# mapvas.nvim

Neovim plugin for [mapvas](https://github.com/UdHo/mapvas) — a map viewer that renders geographic data from the terminal.

## Requirements

- Neovim 0.11+
- mapvas 0.2.10
- `mapcat` binary on `$PATH` (ships with mapvas)
- `curl` on `$PATH`
- mapvas running locally on `http://localhost:12345`

## Installation

Plugin releases are tagged to match the mapvas version they require (e.g. tag `v0.2.10` works
with mapvas 0.2.10).

With `vim.pack` (built-in, Neovim 0.11+):

```lua
vim.pack.add({ src = 'https://github.com/UdHo/mapvas.nvim', version = vim.version.range('0.2') })
require('mapvas').setup()
```

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ 'UdHo/mapvas.nvim', version = '~0.2' }
```

Call `setup()` in your config to register keymaps:

```lua
{
  'UdHo/mapvas.nvim',
  config = function()
    require('mapvas').setup({
      highlight_group = 'Search',   -- highlight group for coordinate pairs (default: 'Search')
      keys = {
        send      = '<leader>ms',   -- send buffer / selection to mapvas
        clear     = '<leader>mc',   -- clear the map
        toggle    = '<leader>mt',   -- toggle auto send-on-save
        highlight = '<leader>mh',   -- toggle coordinate highlighting
        sidebar   = '<leader>ml',   -- toggle layer explorer sidebar
      },
    })
  end,
}
```

## Features

### Send data to the map

| Mode   | Default key  | Command            | Description                        |
|--------|--------------|--------------------|------------------------------------|
| Normal | `<leader>ms` | `:Mapvas`          | Send the current buffer            |
| Visual | `<leader>ms` | `:'<,'>Mapvas`     | Send the selected lines            |
| Normal | `<leader>mc` | `:MapvasClear`     | Clear all shapes from the map      |

mapvas accepts any format that `mapcat` understands: GeoJSON, CSV with lat/lon columns,
Google Encoded Polylines, plain `lat,lon` pairs, and more.

### Auto mode

`<leader>mt` / `:MapvasToggle` — toggles auto mode. While active:

- the buffer is sent to mapvas on every `:write`
- coordinate pairs in the buffer are highlighted on every change

### Coordinate highlighting

`<leader>mh` / `:MapvasHighlight` — toggles in-buffer highlighting of coordinate pairs
(`lat,lon` patterns). The highlight group is `MapvasCoord`, linked to `Search` by default.

### Layer sidebar

`<leader>ml` / `:MapvasSidebar` — opens a sidebar that shows all layers currently loaded in
mapvas. The sidebar polls mapvas every 2 seconds and updates automatically.

**Sidebar keymaps:**

| Key          | Action                                      |
|--------------|---------------------------------------------|
| `<CR>` (Enter) | Drill into a layer to see its shapes      |
| `<BS>`       | Go back to the layer list                   |
| `v` / `Space`| Toggle visibility of the layer or shape     |
| `f`          | Focus the map on the layer (layer view only)|
| `r`          | Refresh immediately                         |
| `q` / `<Esc>`| Close the sidebar                           |

## API

```lua
local mapvas = require('mapvas')

mapvas.send()                          -- send current buffer
mapvas.send({ line1 = 1, line2 = 5 }) -- send lines 1-5
mapvas.clear()                         -- clear the map
mapvas.toggle_auto()                   -- toggle auto send-on-save
mapvas.toggle_highlight()              -- toggle coordinate highlighting
mapvas.sidebar_toggle()                -- toggle layer explorer sidebar
```
