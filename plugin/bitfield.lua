-- plugin/bitfield.lua
-- Neovim loads this file automatically at startup (for ft=c/cpp).
-- It simply calls setup() so the plugin is ready without any user config.
-- Users who want to customise it should call require("bitfield").setup({...})
-- in their own init.lua instead, and set ft to prevent double-setup.
 
if vim.g.loaded_bitfield then return end
vim.g.loaded_bitfield = true
 
-- Only activate for C / C++ buffers
vim.api.nvim_create_autocmd("FileType", {
    pattern  = { "c", "cpp" },
    callback = function()
        -- Lazy-init: don't call setup() more than once.
        if not vim.g.bitfield_setup_done then
            require("bitfield").setup()
            vim.g.bitfield_setup_done = true
        end
    end,
    desc = "bitfield.nvim — activate for C/C++ buffers",
})
 