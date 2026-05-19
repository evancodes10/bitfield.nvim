-- lua/bitfield/layout.lua
-- Turns raw field data (from the C parser) into a display-ready layout table.
--
-- Each entry in the returned table describes one "row" in the floating window:
--   {
--     kind        = "field" | "pad" | "header",
--     label       = string shown in the name column,
--     type        = type spelling (fields only),
--     bit_start   = first bit (inclusive, 0-based),
--     bit_end     = last  bit (inclusive),
--     width_bits  = bit_end - bit_start + 1,
--     is_bitfield = bool,
--   }

local M = {}

---@param fields table[]  raw field list from parse.c JSON
---@return table[] layout rows
function M.compute(fields)
    local rows = {}
    local cursor = 0  -- next expected bit

    for _, f in ipairs(fields) do
        local start = f.bit_offset

        -- padding gap before this field?
        if start > cursor then
            rows[#rows + 1] = {
                kind       = "pad",
                label      = string.format("<pad %d>", start - cursor),
                type       = "",
                bit_start  = cursor,
                bit_end    = start - 1,
                width_bits = start - cursor,
                is_bitfield = false,
            }
        end

        local width
        if f.is_bitfield then
            width = f.bit_width
        else
            width = f.byte_size * 8
        end

        rows[#rows + 1] = {
            kind        = "field",
            label       = f.name,
            type        = f.type,
            bit_start   = start,
            bit_end     = start + width - 1,
            width_bits  = width,
            is_bitfield = f.is_bitfield,
            bit_width   = f.bit_width,   -- declared width (bitfields only)
            byte_size   = f.byte_size,
        }

        cursor = start + width
    end

    return rows
end

-- Simple greedy: sort fields descending by alignment requirement so the
-- compiler can pack them tightly (same idea as memlay.nvim).
-- Returns the suggested order as a list of field names.

---@param fields table[]
---@return table[]  suggested field name order
function M.suggest_reorder(fields)
    -- Only non-bitfield fields participate; bitfields stay in declared order
    -- among themselves for correctness (reordering across bitfield groups can
    -- change semantics if the code casts the struct to an integer).
    local non_bf = {}
    local bf_groups = {}  -- preserve runs of consecutive bitfields

    local i = 1
    while i <= #fields do
        local f = fields[i]
        if f.is_bitfield then
            local group = {}
            while i <= #fields and fields[i].is_bitfield do
                group[#group + 1] = fields[i]
                i = i + 1
            end
            bf_groups[#bf_groups + 1] = { kind = "bf_group", fields = group }
        else
            non_bf[#non_bf + 1] = { kind = "field", field = f, align = f.byte_size }
            i = i + 1
        end
    end

    -- sort non-bitfield fields by byte_size descending (largest alignment first)
    table.sort(non_bf, function(a, b) return a.align > b.align end)

    local result = {}
    -- interleave: put all sorted non-bf fields first, then bitfield groups
    for _, item in ipairs(non_bf) do
        result[#result + 1] = item.field.name
    end
    for _, grp in ipairs(bf_groups) do
        for _, bf in ipairs(grp.fields) do
            result[#result + 1] = bf.name
        end
    end
    return result
end

---@param rows table[]
---@return number  total wasted bits
function M.total_waste(rows)
    local waste = 0
    for _, r in ipairs(rows) do
        if r.kind == "pad" then
            waste = waste + r.width_bits
        end
    end
    return waste
end

return M
