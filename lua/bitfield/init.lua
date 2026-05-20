-- lua/bitfield/init.lua
-- Entry point for bitfield.nvim.
 
local M = {}
 
M.config = {
    keymap = "bf",
    win_width = 70,
    max_height = 40,
    border = "rounded",
    show_reorder = true,
}
 
-- Resolve the absolute path to the bitfield-parse binary that lives
-- next to this plugin's c/ directory.
local function bin_path()
    -- debug.getinfo gives us the path to THIS file:
    --   .../bitfield.nvim/lua/bitfield/init.lua
    -- Go up three levels to reach the plugin root.
    local src = debug.getinfo(1, "S").source:sub(2)
    local root = vim.fn.fnamemodify(src, ":h:h:h")
    return root .. "/c/bitfield-parse"
end
 
-- Run the C parser on the current buffer at (line, col).
-- Returns a table of field records on success, nil + error string on failure.
local function parse(filepath, line, col)
    local bin = bin_path()
 
    if vim.fn.executable(bin) ~= 1 then
        return nil, "bitfield-parse not found at " .. bin .. "\nRun :BitfieldBuild"
    end
 
    -- Pass any extra include flags your project needs via the buffer variable
    -- b:bitfield_cflags  (e.g.  let b:bitfield_cflags = "-I./include -std=c11")
    local extra = vim.b.bitfield_cflags or ""
 
    local cmd = string.format(
        "%s %s %d %d %s 2>/dev/null",
        vim.fn.shellescape(bin),
        vim.fn.shellescape(filepath),
        line, col,
        extra
    )
 
    local raw = vim.fn.system(cmd)
 
    if vim.v.shell_error ~= 0 then
        return nil, "Parser exited with error:\n" .. raw
    end
 
    if raw:match("^%[%]") then
        return nil, "Cursor is not inside a struct or union definition."
    end
 
    local ok, decoded = pcall(vim.fn.json_decode, raw)
    if not ok or type(decoded) ~= "table" then
        return nil, "Failed to decode parser output:\n" .. raw
    end
 
    return decoded, nil
end
 
function M.show()
    local buf_path = vim.api.nvim_buf_get_name(0)
    if buf_path == "" then
        vim.notify("bitfield.nvim: buffer has no file path (save it first)", vim.log.levels.WARN)
        return
    end
 
    -- Neovim cursor is 1-based (line, col); col is 0-based internally, add 1
    local cursor   = vim.api.nvim_win_get_cursor(0)
    local line     = cursor[1]
    local col      = cursor[2] + 1
 
    local data, err = parse(buf_path, line, col)
    if not data then
        vim.notify("bitfield.nvim: " .. err, vim.log.levels.ERROR)
        return
    end
 
    local layout  = require("bitfield.layout")
    local render  = require("bitfield.render")
 
    local fields  = data.fields
    local rows    = layout.compute(fields)
    local reorder = layout.suggest_reorder(fields)
 
    -- total_bits = last bit_end + 1  (use the struct's actual size when known)
    local total_bits = 0
    for _, r in ipairs(rows) do
        if r.bit_end + 1 > total_bits then
            total_bits = r.bit_end + 1
        end
    end
    -- round up to nearest byte for display consistency
    total_bits = math.ceil(total_bits / 8) * 8
 
    render.open(data.struct, rows, reorder, total_bits)
end
 
-- Build the C binary by running make inside the plugin's c/ directory.
function M.build()
    local src   = debug.getinfo(1, "S").source:sub(2)
    local root  = vim.fn.fnamemodify(src, ":h:h:h")
    local c_dir = root .. "/c"
 
    vim.notify("bitfield.nvim: building in " .. c_dir, vim.log.levels.INFO)
 
    vim.fn.jobstart({ "make", "-C", c_dir }, {
        on_exit = function(_, code)
            if code == 0 then
                vim.notify("bitfield.nvim: build succeeded", vim.log.levels.INFO)
            else
                vim.notify("bitfield.nvim: build FAILED (see :messages)", vim.log.levels.ERROR)
            end
        end,
        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.notify(table.concat(data, "\n"), vim.log.levels.WARN)
            end
        end,
    })
end
 
function M.setup(user_opts)
    user_opts = user_opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, user_opts)
 
    -- propagate win/border config into render module
    local render = require("bitfield.render")
    render.config.win_width    = M.config.win_width
    render.config.max_height   = M.config.max_height
    render.config.border       = M.config.border
    render.config.show_reorder = M.config.show_reorder
    render.setup_highlights()
 
    -- keymaps
    if M.config.keymap then
        vim.keymap.set("n",
            "<leader>" .. M.config.keymap,
            M.show,
            { desc = "Show bitfield layout", silent = true }
        )
    end
 
    -- user commands
    vim.api.nvim_create_user_command("BitfieldShow",   M.show,  { desc = "Show bitfield layout at cursor" })
    vim.api.nvim_create_user_command("BitfieldBuild",  M.build, { desc = "Compile bitfield-parse binary" })
    vim.api.nvim_create_user_command("BitfieldReload", function()
        package.loaded["bitfield"]        = nil
        package.loaded["bitfield.layout"] = nil
        package.loaded["bitfield.render"] = nil
        require("bitfield").setup(user_opts)
        vim.notify("bitfield.nvim: reloaded", vim.log.levels.INFO)
    end, { desc = "Reload bitfield.nvim modules" })
 
    vim.api.nvim_create_user_command("BitfieldDebug", function()
        local buf_path = vim.api.nvim_buf_get_name(0)
        local cursor   = vim.api.nvim_win_get_cursor(0)
        local data, err = parse(buf_path, cursor[1], cursor[2] + 1)
        if not data then
            vim.notify(err, vim.log.levels.ERROR)
        else
            vim.notify(vim.inspect(data), vim.log.levels.INFO)
        end
    end, { desc = "Dump raw parser output at cursor" })
end
 
return M
