-- The waiting half of $EDITOR. See shell/nvim-edit.
--
-- Neovim has no --remote-wait: it answers with
--   E5600: Wait commands not yet implemented in Nvim
-- which is exactly what git needs from $EDITOR, so it has to be built out
-- of the two remote verbs that do exist. shell/nvim-edit opens the file
-- with --remote, then calls this over --remote-expr and blocks until the
-- sentinel appears.

local M = {}

--- Touch `sentinel` once the current buffer is done with, releasing the
--- shell that's waiting on it.
---
--- Attached to the buffer rather than the file path: --remote has already
--- opened it and made it current, and a buffer handle can't be confused by
--- symlinks, relative paths or a second file of the same name.
function M.wait(sentinel)
  local buf = vim.api.nvim_get_current_buf()

  -- The whole trick. This config sets 'hidden', so :wq closes the WINDOW
  -- and leaves the buffer loaded — BufUnload and BufDelete never fire, and
  -- git waits forever. 'bufhidden=wipe' turns "no longer on screen" into a
  -- real BufWipeout, which is the signal we actually mean: done with it.
  vim.bo[buf].bufhidden = "wipe"

  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload", "BufDelete", "BufHidden" }, {
    buffer = buf,
    once = true,
    callback = function()
      -- Scheduled: the write has already happened by now, and the caller
      -- only cares that the file appears, not where in teardown it lands.
      vim.schedule(function()
        pcall(vim.fn.writefile, { "" }, sentinel)
      end)
    end,
  })
  return ""
end

return M
