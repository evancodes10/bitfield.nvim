# bitfield.nvim


A Neovim plugin that visualizes the bit-level memory layout of C structs in a floating window. Place your cursor anywhere within a struct definition and inspect every field's bit offset, width, and padding. 

| Chessboard Example Struct | Bitfield.nvim Output |
|---|---|
| <img width="450" src="https://github.com/user-attachments/assets/ff7e433b-4fcc-4d08-8065-d778699331d4" /> | <img width="450" src="https://github.com/user-attachments/assets/5f9dd84d-4ef8-4ab6-bcb6-d1294a830615" />

Above is an example of how a chess board struct used in a chess engine would behave in the Neovim floating window. 

To create this output, run `<leader>zi`, while your cursor is in the definition of a C struct. 

*NOTE*: This plugin only works with C structs. C++ structs are not supported.

---
## Features

- ABI-accurate layout via libclang. Meaning these offsets are the same as what a C compiler would see.
- Proportional bit map showing each fields position across the full struct width.
- Displays declared widths alongside computed offsets.
- Padding detection highlights wasted bits per gap with reorder suggestion.
- Field Detail Table displaying the name, type spelling, bit range, and width for every field.
- Works on both `.c` and `.h` files.
---

## Requirements

- Neovim >= 0.9 with LuaJIT
- libclang >= 14

```bash
# Ubuntu / Debian
sudo apt install libclang-dev

# Arch
sudo pacman -S clang

# Fedora
sudo dnf install clang-devel

# macOS
brew install llvm
```

If libclang is installed in a non-standard location:

```bash
LLVM_PATH=/path/to/llvm make -C c/
```
---
## Installation 

### lazy.nvim
```lua
{
  "evancodes10/bitfield.nvim",
  build  = "make -C c/",
  ft     = { "c", "cpp" },
  config = function()
    require("bitfield").setup()
  end,
}
```

### packer
```lua
use {
  "evancodes10/bitfield.nvim",
  run    = "make -C c/",
  config = function() require("bitfield").setup() end,
}
```

## Usage

| Key / Command       | Action                                        |
|---------------------|-----------------------------------------------|
| `<leader>zi`        | Show layout for struct under cursor           |
| `q` / `<Esc>`       | Close the floating window                     |
| `j` / `k`           | Scroll (large structs)                        |
| `:BitfieldShow`     | Same as the keymap                            |
| `:BitfieldBuild`    | Compile `c/bitfield-parse` from source        |
| `:BitfieldReload`   | Reload Lua modules after a local change       |
| `:BitfieldDebug`    | Dump raw parser JSON at cursor position       |

Because libclang parses the file on the disk, the buffer must be saved before triggering. 

Run `:checkhealh bitfield` to verify the binary and libclang are accessible.

---

## Projects that include flags

For projects that include specific paths, set a buffer-local variable:

```vim
let b:bitfield_cflags = "-I./include -std=c11"
```

---

## Configuration

```lua
require("bitfield").setup({
  keymap       = "zi",
  win_width    = 70,
  max_height   = 40,
  border       = "rounded",
  show_reorder = true,
})
```

### Highlight groups

```lua
vim.api.nvim_set_hl(0, "BitfieldField",  { bg = "#1e3a5f", fg = "#89d4f5", bold = true })
vim.api.nvim_set_hl(0, "BitfieldBit",    { bg = "#1a4731", fg = "#7dd4a8", bold = true })
vim.api.nvim_set_hl(0, "BitfieldPad",    { bg = "#4e4e4e", fg = "#bbbbbb", italic = true })
vim.api.nvim_set_hl(0, "BitfieldHeader", { fg = "#e0af68", bold = true })
vim.api.nvim_set_hl(0, "BitfieldWaste",  { fg = "#f7768e", bold = true })
vim.api.nvim_set_hl(0, "BitfieldGood",   { fg = "#9ece6a", bold = true })
```

---

## How it works

Two components communicate through a JSON protocol.

`c/parser.c` is a standalone binary built against libclang. It accepts a file path, line, and column as arguments, walks the AST to find the struct at that position, and emits a JSON object containing each field's name, type of spelling, bit offset, declared bit width, and byte size. It has no runtime dependency on Neovim.

`lua/bitfield/` is the Neovim side:

- `init.lua` — resolves the binary path, invokes it as a subprocess, decodes the JSON response, and drives the layout and render modules
- `layout.lua` — converts raw field offsets into display rows, detects padding gaps between fields, and produces a suggested reordering to eliminate waste
- `render.lua` — opens a centered floating window, draws the proportional bit map and field detail table, and applies highlight groups
- `health.lua` — implements `:checkhealth bitfield` to verify the binary, libclang, and Neovim version


FULL EXAMPLE OUTPUT:

| | |
|---|---|
| <img width="450" src="https://github.com/user-attachments/assets/ad3465e4-2f0d-459b-8471-bad8ec17f2a0" /> | <img width="450" src="https://github.com/user-attachments/assets/ed9c9400-6d55-4d8e-bd17-de77801279fb" /> |
| <img width="450" src="https://github.com/user-attachments/assets/1d331e78-4050-4c10-9244-b79418b4a43f" /> | <img width="450" src="https://github.com/user-attachments/assets/5f9dd84d-4ef8-4ab6-bcb6-d1294a830615" /> |

---

## Limitations

- C-style structs only; C++ classes are not supported
- Bitfields inside anonymous nested structs are not recursed into
- The buffer must be saved before triggering (libclang reads from disk)

---

## License

MIT
