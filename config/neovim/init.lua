-- INSTALL LAZY.NVIM (if not bootstrapping automatically):
-- git clone --filter=blob:none https://github.com/folke/lazy.nvim.git --branch=stable \
--   ~/.local/share/nvim/lazy/lazy.nvim

if vim.g.vscode then
  return
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

local opt = vim.opt
opt.termguicolors = true
opt.mouse = 'a'
opt.smartindent = true
opt.wrap = false
opt.number = true
opt.relativenumber = false
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
vim.o.sessionoptions = 'blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions'

vim.hl.priorities.semantic_tokens = 140
vim.hl.priorities.treesitter = 100

vim.filetype.add({
  extension = {
    svelte = 'svelte',
    svx = 'markdown',
  },
})
vim.api.nvim_create_autocmd('FileType', { pattern = { 'markdown', 'svx' }, command = 'setlocal wrap' })

local function map(mode, lhs, rhs)
  vim.keymap.set(mode, lhs, rhs, { silent = true })
end

local function confirm_clear_buffers()
  local choice = vim.fn.confirm('Clear all buffers?', '&Yes\n&No', 2)
  if choice ~= 1 then
    return
  end

  local listed_buffers = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      listed_buffers[#listed_buffers + 1] = buf
    end
  end

  local ok, err = pcall(vim.cmd, 'enew')
  if not ok then
    vim.notify(err, vim.log.levels.WARN)
    return
  end

  local scratch = vim.api.nvim_get_current_buf()
  vim.bo[scratch].buftype = 'nofile'
  vim.bo[scratch].bufhidden = 'wipe'
  vim.bo[scratch].buflisted = false
  vim.bo[scratch].swapfile = false

  local failed = false
  for _, buf in ipairs(listed_buffers) do
    if buf ~= scratch and vim.api.nvim_buf_is_valid(buf) then
      local deleted = pcall(vim.api.nvim_buf_delete, buf, {})
      failed = failed or not deleted
    end
  end

  if failed then
    vim.notify('Some buffers could not be deleted', vim.log.levels.WARN)
  end
end

local function smart_definition()
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  local cur_bufnr = vim.api.nvim_get_current_buf()
  vim.lsp.buf.definition({
    on_list = function(options)
      local items = options.items or {}
      if #items == 0 then
        require('telescope.builtin').lsp_references()
        return
      end
      local first = items[1]
      if first.bufnr == cur_bufnr and first.lnum == cur_pos[1] then
        require('telescope.builtin').lsp_references()
        return
      end
      if #items == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(first.filename))
        vim.api.nvim_win_set_cursor(0, { first.lnum, math.max(0, first.col - 1) })
      else
        require('telescope.builtin').lsp_definitions()
      end
    end,
  })
end

local function telescope_workspace_symbols()
  local bufnr = vim.api.nvim_get_current_buf()

  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client:supports_method('workspace/symbol', bufnr) then
      require('telescope.builtin').lsp_dynamic_workspace_symbols()
      return
    end
  end

  vim.notify('No attached LSP client supports workspace/symbol for this buffer', vim.log.levels.WARN)
end

for _, m in ipairs({
  { 'n', '<c-b>', '<cmd>NvimTreeFindFileToggle<cr>' },
  { 'n', '<c-`>', '<cmd>ToggleTerm direction="float"<cr>' },
  { 't', '<c-`>', '<cmd>ToggleTerm<cr>' },
  { 'n', '<leader>gs', '<cmd>Telescope git_status<cr>' },
  { 'n', '<leader>gc', '<cmd>Telescope git_commits<cr>' },
  { 'n', '<leader>:', '<cmd>Telescope commands<cr>' },
  { 'n', '<leader><leader>', '<cmd>Telescope find_files<cr>' },
  { 'n', '<leader>ff', '<cmd>Telescope live_grep<cr>' },
  { 'n', '<leader>fz', '<cmd>Telescope grep_string<cr>' },
  { 'n', '<leader>t', telescope_workspace_symbols },
  { 'n', '<leader>b', '<cmd>Telescope buffers<cr>' },
  { 'n', '<leader>dB', confirm_clear_buffers },
  { 'n', 'B', '<cmd>Telescope buffers<cr>' },
  { 'n', '<leader>e', vim.diagnostic.open_float },
  { 'n', '\\', vim.lsp.buf.hover },
  { 'n', '<F12>', smart_definition },
  { 'n', '<S-F12>', function() require('telescope.builtin').lsp_references() end },
  { 'n', '<C-F12>', function() require('telescope.builtin').lsp_implementations() end },
  { 'n', '<F2>', vim.lsp.buf.rename },
  { 'n', '<a-k>', '<cmd>GitGutterPrevHunk<cr>' },
  { 'n', '<a-j>', '<cmd>GitGutterNextHunk<cr>' },
  { 'n', '<c-h>', '<cmd>bp<cr>' },
  { 'n', '<c-l>', '<cmd>bn<cr>' },
  { 'n', '<leader>c', '<cmd>bp<bar>bd#<cr>' },
}) do
  map(m[1], m[2], m[3])
end

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  {
    'Mofiqul/vscode.nvim',
    name = 'vscode',
    priority = 1000,
    lazy = false,
    config = function() require('vscode').setup({ transparent = true }) end,
  },
  { 'airblade/vim-gitgutter' },
  {
    'numToStr/Comment.nvim',
    config = function()
      require('Comment').setup()
      vim.keymap.set('n', '<leader>/', function()
        return vim.v.count == 0 and '<Plug>(comment_toggle_linewise_current)'
          or '<Plug>(comment_toggle_linewise_count)'
      end, { expr = true, silent = true, desc = 'Toggle line comment' })

      vim.keymap.set('x', '<leader>/', '<Plug>(comment_toggle_blockwise_visual)', {
        silent = true,
        desc = 'Toggle block comment',
      })
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = { theme = 'vscode', globalstatus = true },
        sections = {
          lualine_z = {
            'location',
            function() return 'L:' .. vim.api.nvim_buf_line_count(0) end,
          },
        },
      })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      local wanted = { 'svelte', 'javascript', 'typescript', 'html', 'css', 'markdown', 'svx' }
      local ts_runtime = vim.fn.stdpath('data') .. '/lazy/nvim-treesitter/runtime'
      if vim.uv.fs_stat(ts_runtime) then
        vim.opt.rtp:append(ts_runtime)
      end
      require('nvim-treesitter').setup({ install_dir = vim.fn.stdpath('data') .. '/site' })
      vim.treesitter.language.register('markdown', 'svx')

      vim.api.nvim_create_autocmd('FileType', {
        pattern = wanted,
        callback = function() pcall(vim.treesitter.start) end,
      })
    end,
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    config = function()
      vim.lsp.config('*', {
        capabilities = vim.tbl_deep_extend(
          'force',
          vim.lsp.protocol.make_client_capabilities(),
          require('cmp_nvim_lsp').default_capabilities()
        ),
      })
      vim.lsp.enable({ 'basedpyright', 'ts_ls', 'svelte', 'rust_analyzer' })
    end,
  },
  { 'hrsh7th/cmp-nvim-lsp' },
  {
    'hrsh7th/nvim-cmp',
    dependencies = { 'hrsh7th/cmp-nvim-lsp' },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        mapping = {
          ['<C-n>'] = cmp.mapping(function()
            if cmp.visible() then
              cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
            else
              cmp.complete()
            end
          end, { 'i', 's' }),
          ['<C-p>'] = cmp.mapping(function()
            if cmp.visible() then
              cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
            end
          end, { 'i', 's' }),
          ['<CR>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.confirm({ select = true })
            else
              fallback()
            end
          end, { 'i', 's' }),
        },
        sources = { { name = 'nvim_lsp' } },
      })
    end,
  },
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      vim.api.nvim_set_hl(0, 'NvimTreeNormal', { bg = '#0f0f12' })
      vim.api.nvim_set_hl(0, 'NvimTreeEndOfBuffer', { bg = '#0f0f12' })
      vim.api.nvim_set_hl(0, 'NvimTreeWinSeparator', { bg = '#0f0f12', fg = '#0f0f12' })
      require('nvim-tree').setup({
        view = { width = 42 },
        update_focused_file = {
          enable = true,
          update_root = false,
        },
      })
    end,
  },
  {
    'rmagatti/auto-session',
    lazy = false,
    opts = {
      suppressed_dirs = { '~/', '~/Downloads', '/' },
      close_filetypes_on_save = { 'checkhealth', 'NvimTree' },
      auto_delete_empty_sessions = false,
    },
  },
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope-fzf-native.nvim' },
    config = function()
      local actions = require('telescope.actions')
      require('telescope').setup({
        defaults = {
          mappings = {
            i = {
              ['<Esc>'] = actions.close,
            },
          },
        },
        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = 'smart_case',
          },
        },
      })
      require('telescope').load_extension('fzf')
    end,
  },
  { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function() require('toggleterm').setup() end,
  },
})

if not pcall(vim.cmd.colorscheme, 'vscode') then
  print('Failed to load colorscheme - probably has not been installed')
end
