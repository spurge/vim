vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.spell = true
vim.opt_local.spelllang = require("core.config").spell
-- With render_markdown, raw means the literal source (conceallevel 0) and
-- the plugin flips it to 3 when rendering. It only touches the option when
-- it renders, though, so with on_open = false a 2 here would stick until
-- the first <Leader>M — a "raw" view with emphasis and link targets hidden.
vim.opt_local.conceallevel = require("core.config").render_markdown.enabled and 0 or 2
