-- lua/bitfield/render.lua
-- Draws the floating window showing the bit-level layout of a C struct.

local M = {}

-- ── config defaults (overridden by setup()) ────────────────────────────
M.config = {
    win_width      = 70,
    max_height     = 40,
    border         = "rounded",
    show_reorder   = true,
}

-- ── highlight groups ──────────────────────────────────────────────────
local HI_FIELD  = "BitfieldField"
local HI_BFIELD = "BitfieldBit"
local HI_PAD    = "BitfieldPad"
local HI_HEADER = "BitfieldHeader"
local HI_WASTE  = "BitfieldWaste"
local HI_GOOD   = "BitfieldGood"

function M.setup_highlights()
    vim.api.nvim_set_hl(0, HI_FIELD,  { bg = "#1e3a5f", fg = "#89d4f5", bold = true })
    vim.api.nvim_set_hl(0, HI_BFIELD, { bg = "#1a4731", fg = "#7dd4a8", bold = true })
    vim.api.nvim_set_hl(0, HI_PAD,    { bg = "#4e4e4e", fg = "#bbbbbb", italic = true })
    vim.api.nvim_set_hl(0, HI_HEADER, { fg = "#e0af68", bold = true })
    vim.api.nvim_set_hl(0, HI_WASTE,  { fg = "#f7768e", bold = true })
    vim.api.nvim_set_hl(0, HI_GOOD,   { fg = "#9ece6a", bold = true })
end

-- ── internal helpers ──────────────────────────────────────────────────

local function pad_right(s, n)
    return s .. string.rep(" ", math.max(0, n - #s))
end

local function bar(width_bits, total_bits, win_w)
    -- returns a string of █ and ░ representing used vs wasted bits
    local bar_w = win_w - 4
    local used = math.floor(width_bits / total_bits * bar_w + 0.5)
    return string.rep("█", used) .. string.rep("░", bar_w - used)
end

-- ── main render function ──────────────────────────────────────────────

---@param struct_name string
---@param rows        table[]   from layout.compute()
---@param reorder     table[]   from layout.suggest_reorder()
---@param total_bits  number
function M.open(struct_name, rows, reorder, total_bits)
    local cfg   = M.config
    local W     = cfg.win_width
    local lines = {}
    local hls   = {}   -- { line, col_start, col_end, hl_group }

    local function hl(line_idx, cs, ce, group)
        hls[#hls + 1] = { line_idx, cs, ce, group }
    end

    -- ── header ──────────────────────────────────────────────────────
    local waste = 0
    for _, r in ipairs(rows) do
        if r.kind == "pad" then waste = waste + r.width_bits end
    end

    local header = string.format(
        " STRUCT: %s   %d bits total",
        struct_name, total_bits
    )
    if waste > 0 then
        header = header .. string.format("  ·  %d bits wasted", waste)
    else
        header = header .. "  ·  no waste"
    end
    lines[#lines + 1] = header
    hl(0, 0, #header, HI_HEADER)
    lines[#lines + 1] = string.rep("─", W)

    -- ── bit ruler ───────────────────────────────────────────────────
    -- Shows bit indices across the top. We show every 4th bit label.
    local ruler_top = " Bits: "
    local ruler_bot = "       "
    for bit = total_bits - 1, 0, -1 do
        if bit % 4 == 3 or bit == total_bits - 1 or bit == 0 then
            local lbl = tostring(bit)
            ruler_top = ruler_top .. lbl
            ruler_bot = ruler_bot .. string.rep(" ", #lbl)
        else
            ruler_top = ruler_top .. " "
            ruler_bot = ruler_bot .. " "
        end
    end
    lines[#lines + 1] = ruler_top
    lines[#lines + 1] = ruler_bot

    -- ── bit map rows ─────────────────────────────────────────────────
    lines[#lines + 1] = string.rep("─", W)

    -- Build a character-per-bit map line for each field/pad row
    -- Each bit gets one character cell in a fixed-width ruler.
    -- We scale: if total_bits > W-10 we group bits per cell.
    local BMAP_W = W - 8
    local bits_per_cell = math.max(1, math.ceil(total_bits / BMAP_W))

    local function bmap_line(row)
        local cells = math.ceil(total_bits / bits_per_cell)
        local chars = {}
        for cell = 0, cells - 1 do
            local bit_hi = total_bits - 1 - cell * bits_per_cell
            local bit_lo = math.max(0, bit_hi - bits_per_cell + 1)
            -- does this cell overlap the row's range?
            if row.bit_end >= bit_lo and row.bit_start <= bit_hi then
                if row.kind == "pad" then
                    chars[#chars + 1] = "░"
                elseif row.is_bitfield then
                    chars[#chars + 1] = "▓"
                else
                    chars[#chars + 1] = "█"
                end
            else
                chars[#chars + 1] = "·"
            end
        end
        return table.concat(chars)
    end

    for _, row in ipairs(rows) do
        local bmap  = bmap_line(row)
        local range = string.format("[%d:%d]", row.bit_end, row.bit_start)
        local wbits = string.format("%d b", row.width_bits)

        -- label column (left-justified, fixed width)
        local label_col = pad_right(row.label, 14)
        local line = string.format(" %s │%s│ %-8s %s",
            label_col, bmap, range, wbits)

        local li = #lines
        lines[#lines + 1] = line

        local hi_group
        if row.kind == "pad" then
            hi_group = HI_PAD
        elseif row.is_bitfield then
            hi_group = HI_BFIELD
        else
            hi_group = HI_FIELD
        end
        -- highlight just the bmap portion
        local bmap_start = 16   -- after label + " │"
        local bmap_end   = bmap_start + #bmap
        hl(li, bmap_start, bmap_end, hi_group)
    end

    lines[#lines + 1] = string.rep("─", W)

    -- ── legend ────────────────────────────────────────────────────────
    lines[#lines + 1] = " █ = regular field   ▓ = bitfield   ░ = padding"
    lines[#lines + 1] = string.rep("─", W)

    -- ── field detail table ────────────────────────────────────────────
    lines[#lines + 1] = string.format(" %-14s %-22s %-10s %s",
        "Field", "Type", "Range", "Bits")
    lines[#lines + 1] = string.rep("─", W)

    for _, row in ipairs(rows) do
        if row.kind == "field" then
            local range = string.format("[%d:%d]", row.bit_end, row.bit_start)
            local bw = row.is_bitfield
                and string.format(":%d", row.bit_width)
                or  tostring(row.width_bits)
            lines[#lines + 1] = string.format(" %-14s %-22s %-10s %s",
                row.label,
                row.type:sub(1, 22),
                range,
                bw
            )
        elseif row.kind == "pad" then
            local range = string.format("[%d:%d]", row.bit_end, row.bit_start)
            local li = #lines
            local pad_line = string.format(" %-14s %-22s %-10s %d (WASTED)",
                row.label, "", range, row.width_bits)
            lines[#lines + 1] = pad_line
            hl(li, 0, #pad_line, HI_WASTE)
        end
    end

    -- ── reorder suggestion ────────────────────────────────────────────
    if cfg.show_reorder and waste > 0 and #reorder > 0 then
        lines[#lines + 1] = string.rep("─", W)
        lines[#lines + 1] = "!! reorder to eliminate padding:"
        hl(#lines - 1, 0, W, HI_WASTE)
        lines[#lines + 1] = "   " .. table.concat(reorder, ", ")
    elseif waste == 0 then
        lines[#lines + 1] = string.rep("─", W)
        local ok = " ✓ Perfectly packed — no wasted bits."
        lines[#lines + 1] = ok
        hl(#lines - 1, 0, #ok, HI_GOOD)
    end

    lines[#lines + 1] = ""

    -- ── open floating window ──────────────────────────────────────────
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "filetype", "bitfield")

    -- apply highlights
    local ns = vim.api.nvim_create_namespace("bitfield")
    for _, h in ipairs(hls) do
        local li, cs, ce, grp = h[1], h[2], h[3], h[4]
        vim.api.nvim_buf_add_highlight(buf, ns, grp, li, cs, ce)
    end

    local height = math.min(#lines, cfg.max_height)
    local ui     = vim.api.nvim_list_uis()[1]
    local row    = math.floor((ui.height - height) / 2)
    local col    = math.floor((ui.width  - W)      / 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width    = W,
        height   = height,
        row      = row,
        col      = col,
        style    = "minimal",
        border   = cfg.border,
        title    = " bitfield.nvim ",
        title_pos = "center",
    })

    -- key maps to close / scroll
    local close = function() vim.api.nvim_win_close(win, true) end
    for _, k in ipairs({ "q", "<Esc>", "<leader>bf" }) do
        vim.keymap.set("n", k, close, { buffer = buf, nowait = true, silent = true })
    end
    vim.keymap.set("n", "j", "<C-e>", { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "k", "<C-y>", { buffer = buf, nowait = true, silent = true })
end

return M
