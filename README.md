# bitfield.nvim


A Neovim plugin that visualizes the bit-level memory layout of C structs in a floating window. Place your cursor anywhere within a struct definition and inspect every field's bit offset, width, and padding. 

| Bitfield.nvim Output | Chessboard Example Struct |
|---|---|
| <img width="450" src="https://github.com/user-attachments/assets/5f9dd84d-4ef8-4ab6-bcb6-d1294a830615" /> | <img width="450" src="https://github.com/user-attachments/assets/ff7e433b-4fcc-4d08-8065-d778699331d4" /> |d4" />

Above is an example of how a chess board struct used in a chess engine would behave in the neovim floating window. 

To create this output, run <leader>zi, while your cursor is in the definition of a C struct. 

*NOTE*: This plugin only works with C structs. C++ structs are not supported.

---
## Features

- ABI-accurate layout via libclang. Meaning these offsets are the same as what a C compiler would see.
- Proportional bit map showing each fields position across the full struct width.
- Displays declared widths alongside computed offsets.
- Padding detection highlights wasted bits per gap with reorder suggestion.
- Field Detail Table displaying the name, type spelling, bit range, and width for every field.
- Works on both *.c* and *.h* files.
---

## Requirements
