-- Statusline and tabline, native. Replaces a statusline plugin with
-- ~110 lines and no dependencies.
--
-- Recomputed on every redraw, so everything here stays cheap: no shelling
-- out, no git calls (gitsigns already puts the branch in a buffer var).

local modes = {
  n = "NORMAL", no = "OP-PEND", nov = "OP-PEND", noV = "OP-PEND",
  v = "VISUAL", V = "V-LINE", ["\22"] = "V-BLOCK",
  s = "SELECT", S = "S-LINE", ["\19"] = "S-BLOCK",
  i = "INSERT", ic = "INSERT", ix = "INSERT",
  R = "REPLACE", Rv = "V-REPL",
  c = "COMMAND", cv = "EX",
  r = "PROMPT", rm = "MORE", ["r?"] = "CONFIRM",
  ["!"] = "SHELL", t = "TERMINAL",
}

local severities = {
  { vim.diagnostic.severity.ERROR, "e" },
  { vim.diagnostic.severity.WARN, "w" },
  { vim.diagnostic.severity.INFO, "i" },
}

local function diagnostics()
  local out = {}
  for _, s in ipairs(severities) do
    local n = #vim.diagnostic.get(0, { severity = s[1] })
    if n > 0 then
      table.insert(out, ("%s»%d"):format(s[2], n))
    end
  end
  return table.concat(out, " ")
end

local function clients()
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    table.insert(names, c.name)
  end
  if #names == 0 then return "" end
  table.sort(names)
  return table.concat(names, ",")
end

local function flags()
  local out = {}
  if vim.b.core_passthrough then
    table.insert(out, "[passthrough]")
  end
  if vim.g.disable_autoformat or vim.b.disable_autoformat then
    table.insert(out, "[fmt off]")
  end
  return table.concat(out, " ")
end

function _G.NvimStatusline()
  local head = vim.b.gitsigns_head
  local left = table.concat({
    " %#StatusLineNC#",
    modes[vim.api.nvim_get_mode().mode] or "?",
    "%* %f%m%r %#Comment#",
    head and (" " .. head) or "",
    "%*",
  })

  local right = table.concat({
    "%#DiagnosticError#", diagnostics(), "%*",
    " %#Comment#", flags(), " ", clients(), "%*",
    "  %{&filetype}",
    "  %{&fileformat}",
    "  %l:%c",
    "  %P ",
  })

  return left .. "%=" .. right
end

vim.o.statusline = "%!v:lua.NvimStatusline()"

-- Redraw when diagnostics change, otherwise the counts lag behind.
vim.api.nvim_create_autocmd({ "DiagnosticChanged", "LspAttach", "LspDetach" }, {
  group = vim.api.nvim_create_augroup("core.statusline", { clear = true }),
  callback = function() vim.cmd.redrawstatus() end,
})

-- ── Tabline ───────────────────────────────────────────────────────────
-- The default shows nothing useful, and the tab keymaps make tabs
-- first-class here.
function _G.NvimTabline()
  local out = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local win = vim.api.nvim_tabpage_get_win(tab)
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
    if name == "" then name = "[No Name]" end
    local hl = tab == vim.api.nvim_get_current_tabpage() and "%#TabLineSel#" or "%#TabLine#"
    table.insert(out, ("%s %d:%s %%*"):format(hl, i, name))
  end
  return table.concat(out) .. "%#TabLineFill#"
end

vim.o.tabline = "%!v:lua.NvimTabline()"
vim.o.showtabline = 1
