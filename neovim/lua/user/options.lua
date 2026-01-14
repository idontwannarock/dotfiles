-- :help options
local options = {
    clipboard = "unnamedplus", -- allows neovim to access the system clipboard
    cmdheight = 2,             -- more space in the neovim command line for displaying messages
    conceallevel = 0,          -- so that `` is visible in markdown file
    fileencoding = "utf-8",    -- the encoding written to a file
    swapfile = false,          -- creates a swapfile
	termguicolors = true,      -- set term gui colors (most terminals support this)
    updatetime = 300,          -- faster completion (4000ms default)
    cursorline = true,         -- highlight the cursor line
    number = true,             -- set numbered lines
    relativenumber = true,     -- set relative numbered lines
    tabstop = 4,               -- insert spaces for a tab (8 default)
	shiftwidth = 4,            -- the number of spaces inserted for each indentation
}

for k, v in pairs(options) do
    vim.opt[k] = v
end

