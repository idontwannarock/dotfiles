local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath "data" .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
	PACKER_BOOTSTRAP = fn.system {
		"git",
		"clone",
		"--depth",
		"1",
		"https://github.com/wbthomason/packer.nvim",
		install_path,
	}
	print "Installing packer close and reopen Neovim..."
	vim.cmd [[packadd packer.nvim]]
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd [[
    augroup packer_user_config
        autocmd!
		autocmd BufWritePost plugins.lua source <afile> | PackerSync
	augroup end
]]

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
	return
end

-- Have packer use a popup window
packer.init {
	display = {
		open_fn = function()
			return require("packer.util").float { border = "rounded" }
		end,
	},
}

-- Install your plugins here
return packer.startup(function(use)
	-- My plugins here
	use "wbthomason/packer.nvim" -- Have packer manage itself
	use "nvim-lua/popup.nvim"    -- An implementation of the Popup API from vim in Neovim
	use "nvim-lua/plenary.nvim"  -- Useful lua functions used by lots of plugins
	use "numToStr/Comment.nvim"  -- Easily comment stuff
	use "kyazdani42/nvim-web-devicons"


	-- color schemes
	-- use "lunarvim/colorschemes" -- A bunch of colorschemes you can try out
	use "lunarvim/darkplus.nvim"

	-- cmp plugins
	use "hrsh7th/nvim-cmp"         -- The completion plugin
	use "hrsh7th/cmp-buffer"       -- Buffer completions
	use "hrsh7th/cmp-path"         -- Path completions
	use "hrsh7th/cmp-cmdline"      -- cmdline completions
	use "saadparwaiz1/cmp_luasnip" -- Snippet completions
	use "hrsh7th/cmp-nvim-lsp"
	use "hrsh7th/cmp-nvim-lua"

	-- snippets
	use "L3MON4D3/LuaSnip"             -- Snippet engine
	use "rafamadriz/friendly-snippets" -- A bunch of snippets to use

	-- LSP
	use "neovim/nvim-lspconfig"           -- enable LSP
	use "williamboman/nvim-lsp-installer" -- simple to use language server installer
	use "tamago324/nlsp-settings.nvim"    -- language server settings defined in json form
	use "jose-elias-alvarez/null-ls.nvim" -- for formatters and linters

	-- Telescope
	use "nvim-telescope/telescope.nvim"
	use "nvim-telescope/telescope-media-files.nvim"

	-- Treesitter
	use {
		"nvim-treesitter/nvim-treesitter",
		run = function()
			local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
			ts_update()
		end,
	}
	use "p00f/nvim-ts-rainbow"
	use "JoosepAlviste/nvim-ts-context-commentstring"

	-- autopairs
	use "windwp/nvim-autopairs" -- Autopairs, integrates with both cmp and treesitter

	-- Git
	use "lewis6991/gitsigns.nvim"

	-- Nvimtree
	use "kyazdani42/nvim-tree.lua"

	-- Bufferline
	use "akinsho/bufferline.nvim"
	use "moll/vim-bbye" -- close buffer without closing neovim

	-- Toggleterm
	use "akinsho/toggleterm.nvim"

	-- Automatically set up your configuration after cloning packer.nvim
	-- Pu this at the end after all plugins
	if PACKER_BOOTSTRAP then
		require("packer").sync()
	end
end)

