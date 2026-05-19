-- lua/bitfield/health.lua
-- Implements :checkhealth bitfield
 
local M = {}
 
function M.check()
    vim.health.start("bitfield.nvim")
 

    if vim.fn.has("nvim-0.9") == 1 then
        vim.health.ok("Neovim >= 0.9")
    else
        vim.health.error("Neovim >= 0.9 required (you have " .. tostring(vim.version()) .. ")")
    end
 

    if jit then
        vim.health.ok("LuaJIT available (" .. jit.version .. ")")
    else
        vim.health.warn("LuaJIT not found — plugin may be slower")
    end
 

    local this_file = debug.getinfo(1, "S").source:sub(2)
    local plugin_root = vim.fn.fnamemodify(this_file, ":h:h:h")
    local bin = plugin_root .. "/c/bitfield-parse"
 
    if vim.fn.executable(bin) == 1 then
        vim.health.ok("bitfield-parse binary found: " .. bin)
    else
        vim.health.error(
            "bitfield-parse not found or not executable at " .. bin ..
            "\nRun :BitfieldBuild to compile it."
        )
    end
 

    if vim.fn.executable(bin) == 1 then
        local tmp = vim.fn.tempname() .. ".c"
        local f = io.open(tmp, "w")
        if f then
            f:write("struct X { int a : 4; int b : 4; };\n")
            f:close()
            local out = vim.fn.system(string.format("%s %s 1 10 2>&1", vim.fn.shellescape(bin), vim.fn.shellescape(tmp)))
            vim.fn.delete(tmp)
            if vim.v.shell_error == 0 then
                vim.health.ok("libclang accessible — parser smoke test passed")
            else
                vim.health.error("Parser smoke test failed:\n" .. out)
            end
        end
    end
 

    for _, compiler in ipairs({ "gcc", "clang" }) do
        if vim.fn.executable(compiler) == 1 then
            vim.health.ok(compiler .. " available for building")
            break
        end
    end
 

    vim.health.info("If build fails, install libclang dev headers:")
    vim.health.info("  Ubuntu/Debian:  sudo apt install libclang-dev")
    vim.health.info("  Arch:           sudo pacman -S clang")
    vim.health.info("  Fedora:         sudo dnf install clang-devel")
    vim.health.info("  macOS:          brew install llvm")
    vim.health.info("  Custom path:    LLVM_PATH=/your/llvm make -C c/")
end
 
return M
 