do
	vim.opt.tabstop = 4
	vim.opt.shiftwidth = 4
	vim.opt.expandtab = false

	vim.loader.enable()

	vim.g.mapleader = ' '
	vim.g.maplocalleader = ' '
	vim.g.have_nerd_font = true

	vim.o.number = true
	vim.o.relativenumber = true

	vim.o.mouse = 'a'

	vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

	vim.o.breakindent = true

	vim.o.undofile = false

	vim.o.ignorecase = false
	vim.o.smartcase = false

	vim.o.signcolumn = 'yes'

	vim.o.splitright = true
	vim.o.splitbelow = true

	vim.o.list = true

	vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
	vim.o.inccommand = 'split'

	vim.o.cursorline = true
	vim.o.scrolloff = 999
	vim.o.scrolloffpad = 1

	vim.opt.virtualedit = "onemore"

	vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>', { silent = true })

	-- Exit terminal mode with Ctrl+-. Most terminals send <C-_> (0x1f) for it;
	-- <C--> only arrives distinctly with extended key protocols (kitty, CSI u).
	vim.keymap.set('t', '<C-_>', [[<C-\><C-n>]], { desc = 'Exit terminal mode' })
	vim.keymap.set('t', '<C-->', [[<C-\><C-n>]], { desc = 'Exit terminal mode' })

	-- Floating terminal with tabs. Hiding keeps every shell alive.
	local fterm = { bufs = {}, cur = 0, win = nil }

	local function fterm_config()
		local width, height = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.8)
		return {
			relative = 'editor',
			width = width,
			height = height,
			col = math.floor((vim.o.columns - width) / 2),
			row = math.floor((vim.o.lines - height) / 2) - 1,
			style = 'minimal',
			border = 'rounded',
		}
	end

	local function fterm_winbar()
		if not (fterm.win and vim.api.nvim_win_is_valid(fterm.win)) then return end
		local parts = {}
		for i = 1, #fterm.bufs do
			table.insert(parts, (i == fterm.cur and '%#TabLineSel#' or '%#TabLine#') .. ' ' .. i .. ' ')
		end
		vim.wo[fterm.win].winbar = table.concat(parts) .. '%#TabLineFill#'
	end

	local function fterm_hide()
		if fterm.win and vim.api.nvim_win_is_valid(fterm.win) then vim.api.nvim_win_hide(fterm.win) end
		fterm.win = nil
	end

	local function fterm_show(idx)
		fterm.cur = idx
		local buf = fterm.bufs[idx]
		if fterm.win and vim.api.nvim_win_is_valid(fterm.win) then
			vim.api.nvim_win_set_buf(fterm.win, buf)
		else
			fterm.win = vim.api.nvim_open_win(buf, true, fterm_config())
		end
		vim.api.nvim_set_current_win(fterm.win)
		fterm_winbar()
		vim.cmd 'startinsert'
	end

	local function fterm_new()
		local buf = vim.api.nvim_create_buf(false, true)
		table.insert(fterm.bufs, buf)
		local idx = #fterm.bufs
		if fterm.win and vim.api.nvim_win_is_valid(fterm.win) then
			vim.api.nvim_win_set_buf(fterm.win, buf)
		else
			fterm.win = vim.api.nvim_open_win(buf, true, fterm_config())
		end
		vim.api.nvim_buf_call(buf, function() vim.fn.jobstart({ vim.o.shell }, { term = true }) end)

		local function step(delta)
			return function()
				if #fterm.bufs > 0 then fterm_show((fterm.cur - 1 + delta) % #fterm.bufs + 1) end
			end
		end
		local maps = {
			['<Esc><Esc>'] = { fterm_hide, 'Hide terminal' },
			['<C-n>'] = { fterm_new, 'New terminal tab' },
			['<C-l>'] = { step(1), 'Next terminal tab' },
			['<C-h>'] = { step(-1), 'Previous terminal tab' },
		}
		for lhs, m in pairs(maps) do
			vim.keymap.set({ 't', 'n' }, lhs, m[1], { buffer = buf, desc = m[2] })
		end

		vim.api.nvim_create_autocmd('TermClose', {
			buffer = buf,
			callback = function()
				local i = vim.fn.index(fterm.bufs, buf) + 1
				if i == 0 then return end
				table.remove(fterm.bufs, i)
				if #fterm.bufs == 0 then
					fterm_hide()
					fterm.cur = 0
				else
					fterm_show(math.min(i, #fterm.bufs))
				end
				vim.schedule(function() pcall(vim.api.nvim_buf_delete, buf, { force = true }) end)
			end,
		})
		fterm_show(idx)
	end

	function _G.fterm_toggle()
		if fterm.win and vim.api.nvim_win_is_valid(fterm.win) then
			fterm_hide()
		elseif #fterm.bufs > 0 then
			fterm_show(fterm.cur)
		else
			fterm_new()
		end
	end
end

do
	-- Bootstrap lazy.nvim
	local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
	if not (vim.uv or vim.loop).fs_stat(lazypath) then
		local lazyrepo = "https://github.com/folke/lazy.nvim.git"
		local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
		if vim.v.shell_error ~= 0 then
			vim.api.nvim_echo({
				{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
				{ out, "WarningMsg" },
				{ "\nPress any key to exit..." },
			}, true, {})
			vim.fn.getchar()
			os.exit(1)
		end
	end
	vim.opt.rtp:prepend(lazypath)

	-- Make sure to setup `mapleader` and `maplocalleader` before
	-- loading lazy.nvim so that mappings are correct.
	-- This is also a good place to setup other settings (vim.opt)
	vim.g.mapleader = " "
	vim.g.maplocalleader = "\\"

	-- Setup lazy.nvim
	require("lazy").setup({
		-- highlight-start
		spec = {
			-- add your plugins here
			{
				"folke/snacks.nvim",
				priority = 1000,
				lazy = false,
				---@type snacks.Config
				opts = {
					-- your configuration comes here
					-- or leave it empty to use the default settings
					-- refer to the configuration section below
					bigfile = { enabled = true },
					dashboard = { enabled = true },
					explorer = { enabled = false },
					indent = { enabled = true },
					input = { enabled = true },
					picker = {
						enabled = true,
						sources = {
							git_log = {
								actions = {
									-- Open a diff picker showing only the selected commit's changes
									git_commit_diff = function(picker, item)
										if not item or not item.commit then return end
										picker:close()
										Snacks.picker.git_diff({
											title = "Diff " .. item.commit:sub(1, 8),
											staged = false, -- skip the extra --cached finder
											cmd_args = { item.commit .. "^", item.commit },
										})
									end,
								},
								win = {
									input = { keys = { ["<C-d>"] = { "git_commit_diff", mode = { "n", "i" } } } },
									list = { keys = { ["<C-d>"] = "git_commit_diff" } },
								},
							},
						},
					},
					notifier = { enabled = true },
					quickfile = { enabled = true },
					scope = { enabled = false},
					scroll = { enabled = false },
					statuscolumn = { enabled = true },
					git = {enabled = true},
					terminal = {enabled = true},
					vim.keymap.set({ 'n', 't' }, '<C-`>', function() _G.fterm_toggle() end, { desc = 'Toggle floating terminal' }),
					vim.keymap.set('n', '<leader>ps', ':lua Snacks.picker("git_status")<CR>'),
					vim.keymap.set('n', '<leader>pd', ':lua Snacks.picker("git_diff")<CR>'),
					vim.keymap.set('n', '<leader>pl', ':lua Snacks.picker("git_log")<CR>'),
					vim.keymap.set('n', '<leader>pb', ':lua Snacks.picker("git_branches")<CR>'),
				}
			},
			{
				'lewis6991/gitsigns.nvim',
				opts = {
					signs = {
						add = { text = '+' }, ---@diagnostic disable-line: missing-fields
						change = { text = '~' }, ---@diagnostic disable-line: missing-fields
						delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
						topdelete = { text = '‾' }, ---@diagnostic disable-line: missing-fields
						changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
					},
				},
			},

			{
				"ellisonleao/gruvbox.nvim",
				priority = 1000, -- Make sure to load this before all the other start plugins.
				---@diagnostic disable-next-line: missing-fields
				opts = {
					styles = {
						comments = { italic = true },
					},
				},
				config = function(_, opts)

					-- Load the colorscheme here.
					-- Like many other themes, this one has different styles, and you could load
					-- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
					vim.cmd.colorscheme 'gruvbox'
				end,
			},
			-- Useful plugin to show you pending keybinds.
			{
				'folke/which-key.nvim',
				event = 'VimEnter',
				opts = {
					-- Delay between pressing a key and opening which-key (milliseconds)
					delay = 0,
					icons = { mappings = vim.g.have_nerd_font },
					-- Document existing key chains
					spec = {
						{ '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
						{ '<leader>t', group = '[T]oggle' },
						{ '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
						{ 'gr', group = 'LSP Actions', mode = { 'n' } },
					},
				},
			},

			{ 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

			{
				'nvim-telescope/telescope.nvim',
				event = 'VimEnter',
				dependencies = {
					'nvim-lua/plenary.nvim',
					{ -- If encountering errors, see telescope-fzf-native README for install instructions
						'nvim-telescope/telescope-fzf-native.nvim',

						-- `build` is used to run some command when the plugin is installed/updated.
						build = 'make',

						-- `cond` is a condition used to determine whether this plugin should be
						-- installed and loaded.
						cond = function() return vim.fn.executable 'make' == 1 end,
					},
					{ 'nvim-telescope/telescope-ui-select.nvim' },
				},
				config = function()
					-- See `:help telescope` and `:help telescope.setup()`
					require('telescope').setup {

						defaults = {
							file_ignore_patterns = {
							}
						},
						-- You can put your default mappings / updates / etc. in here
						--  All the info you're looking for is in `:help telescope.setup()`
						--
						-- defaults = {
						--   mappings = {
						--     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
						--   },
						-- },
						-- pickers = {}
						extensions = {
							['ui-select'] = { require('telescope.themes').get_dropdown() },
						},
					}

					-- Enable Telescope extensions if they are installed
					pcall(require('telescope').load_extension, 'fzf')
					pcall(require('telescope').load_extension, 'ui-select')

					-- See `:help telescope.builtin`
					local builtin = require 'telescope.builtin'
					vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
					vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
					-- git ls-files reads the git index instead of walking the tree, which is
					-- much faster than find_files in a large monorepo; fall back outside git.
					vim.keymap.set('n', '<leader>sf', function()
						vim.fn.system { 'git', 'rev-parse', '--is-inside-work-tree' }
						if vim.v.shell_error == 0 then
							builtin.git_files { show_untracked = true }
						else
							builtin.find_files()
						end
					end, { desc = '[S]earch [F]iles' })
					vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
					vim.keymap.set({ 'n', 'v' }, '<leader>sW', builtin.grep_string, { desc = '[S]earch current [W]ord' })
					vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
					vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
					vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
					vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
					vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
					vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

					-- Add Telescope-based LSP pickers when an LSP attaches to a buffer.
					-- If you later switch picker plugins, this is where to update these mappings.
					vim.api.nvim_create_autocmd('LspAttach', {
						group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
						callback = function(event)
							local buf = event.buf

							-- Find references for the word under your cursor.
							vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

							-- Jump to the implementation of the word under your cursor.
							-- Useful when your language has ways of declaring types without an actual implementation.
							vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

							-- Jump to the definition of the word under your cursor.
							-- This is where a variable was first declared, or where a function is defined, etc.
							-- To jump back, press <C-t>.
							vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

							-- Fuzzy find all the symbols in your current document.
							-- Symbols are things like variables, functions, types, etc.
							vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })

							-- Fuzzy find all the symbols in your current workspace.
							-- Similar to document symbols, except searches over your entire project.
							vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })

							-- Jump to the type of the word under your cursor.
							-- Useful when you're not sure what type a variable is and you want to see
							-- the definition of its *type*, not where it was *defined*.
							vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
						end,
					})

					-- Override default behavior and theme when searching
					vim.keymap.set('n', '<leader>/', function()
						-- You can pass additional configuration to Telescope to change the theme, layout, etc.
						builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
							winblend = 10,
							previewer = false,
						})
					end, { desc = '[/] Fuzzily search in current buffer' })

					vim.keymap.set({ 'n', 'v' }, '<leader>sw', '<leader>/<C-r><C-f>', { desc = '[S]earch current [w]ord in current buffer' })

					-- It's also possible to pass additional configuration options.
					--  See `:help telescope.builtin.live_grep()` for information about particular keys
					vim.keymap.set(
						'n',
						'<leader>s/',
						function()
							builtin.live_grep {
								grep_open_files = true,
								prompt_title = 'Live Grep in Open Files',
							}
						end,
						{ desc = '[S]earch [/] in Open Files' }
					)

					-- Shortcut for searching your Neovim configuration files
					vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config', follow = true } end, { desc = '[S]earch [N]eovim files' })
				end,
			},
			{
				'stevearc/oil.nvim',
				keys = {
					{ '-', function() require('oil').toggle_float() end, desc = 'Open oil in a floating window' },
				},
				opts = {
					float = {
						padding = 2,
						max_width = 0.8,
						max_height = 0.8,
						border = 'rounded',
					},
					keymaps = {
						['<Esc><Esc>'] = { 'actions.close', mode = 'n' },
						['<leader>fg'] = {
							desc = 'Live grep in visually selected oil dirs',
							mode = 'v',
							callback = function()
								local oil = require 'oil'
								local start_line = vim.fn.line 'v'
								local end_line = vim.fn.line '.'
								if start_line > end_line then start_line, end_line = end_line, start_line end

								-- Leave visual mode before querying buffer state
								vim.cmd 'normal! \27'

								local cwd = oil.get_current_dir()
								local dirs = {}
								for lnum = start_line, end_line do
									local entry = oil.get_entry_on_line(0, lnum)
									if entry then
										if entry.type == 'directory' then
											table.insert(dirs, cwd .. entry.name)
										elseif entry.type == 'file' then
											table.insert(dirs, cwd)
										end
									end
								end

								if vim.tbl_isempty(dirs) then
									vim.notify('No directories selected', vim.log.levels.WARN)
									return
								end

								require('telescope.builtin').live_grep { search_dirs = dirs }
							end,
						},
					},
				},
			},
			{
				-- NOTE: You can also specify a branch or a specific commit
				'nvim-treesitter/nvim-treesitter',
				branch = 'main',
				build = ':TSUpdate',
				config = function()
					-- Ensure basic parsers are installed
					local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
					require('nvim-treesitter').install(parsers)

					---@param buf integer
					---@param language string
					local function treesitter_try_attach(buf, language)
						-- Check if a parser exists and load it
						if not vim.treesitter.language.add(language) then return end
						-- Enable syntax highlighting and other treesitter features
						vim.treesitter.start(buf, language)

						-- Enable treesitter based folds
						-- For more info on folds see `:help folds`
						-- vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
						-- vim.wo.foldmethod = 'expr'

						-- Check if treesitter indentation is available for this language, and if so enable it
						-- in case there is no indent query, the indentexpr will fallback to the vim's built in one
						local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

						-- Enable treesitter based indentation
						if has_indent_query and language ~= 'c' and language ~= 'cpp' then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
					end

					local available_parsers = require('nvim-treesitter').get_available()
					vim.api.nvim_create_autocmd('FileType', {
						callback = function(args)
							local buf, filetype = args.buf, args.match

							local language = vim.treesitter.language.get_lang(filetype)
							if not language then return end

							local installed_parsers = require('nvim-treesitter').get_installed 'parsers'

							if vim.tbl_contains(installed_parsers, language) then
								-- Enable the parser if it is already installed
								treesitter_try_attach(buf, language)
							elseif vim.tbl_contains(available_parsers, language) then
								-- If a parser is available in `nvim-treesitter`, auto-install it and enable it after the installation is done
								require('nvim-treesitter').install(language):await(function() treesitter_try_attach(buf, language) end)
							else
								-- Try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
								treesitter_try_attach(buf, language)
							end
						end,
					})
				end,
			}
		}
	})
end
