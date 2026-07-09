{ lib, ... }:
{
  enable = true;
  defaultEditor = true;
  viAlias = true;
  vimAlias = true;
  withPython3 = false;
  withRuby = false;
  wrapRc = true;
  impureRtp = false;

  extraConfigLuaPre = lib.mkOrder 100 ''
    if vim.g.vscode then
      return
    end
  '';

  globals = {
    mapleader = " ";
    maplocalleader = " ";
  };

  opts = {
    termguicolors = true;
    mouse = "a";
    smartindent = true;
    wrap = false;
    number = true;
    relativenumber = false;
    tabstop = 4;
    shiftwidth = 4;
    expandtab = true;
    sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions";
  };

  autoCmd = [
    {
      event = "FileType";
      pattern = [
        "markdown"
      ];
      command = "setlocal wrap";
    }
  ];

  colorschemes.vscode = {
    enable = true;
    settings.transparent = true;
  };

  plugins = {
    auto-session = {
      enable = true;
      settings = {
        suppressed_dirs = [
          "~/"
          "~/Downloads"
          "/"
        ];
        bypass_save_filetypes = [
          "checkhealth"
          "NvimTree"
        ];
        close_filetypes_on_save = [
          "checkhealth"
          "NvimTree"
        ];
        auto_delete_empty_sessions = false;
      };
    };

    comment.enable = true;
    gitgutter = {
      enable = true;
      recommendedSettings = false;
    };

    lualine = {
      enable = true;
      settings = {
        options = {
          theme = "vscode";
          globalstatus = true;
        };
        sections.lualine_z = [
          "location"
          { __raw = "function() return 'L:' .. vim.api.nvim_buf_line_count(0) end"; }
        ];
      };
    };

    nvim-tree = {
      enable = true;
      luaConfig.post = ''
        local function apply_nvim_tree_transparency()
          for _, group in ipairs({
            'NvimTreeNormal',
            'NvimTreeNormalNC',
            'NvimTreeEndOfBuffer',
            'NvimTreeSignColumn',
            'NvimTreeStatusLine',
            'NvimTreeStatuslineNC',
            'NvimTreeNormalFloat',
            'NvimTreeNormalFloatBorder',
            'NvimTreeCursorLine',
          }) do
            vim.api.nvim_set_hl(0, group, { bg = 'NONE' })
          end
          vim.api.nvim_set_hl(0, 'NvimTreeWinSeparator', { bg = 'NONE', fg = 'NONE' })
        end

        apply_nvim_tree_transparency()

        vim.api.nvim_create_autocmd('ColorScheme', {
          callback = function()
            vim.schedule(apply_nvim_tree_transparency)
          end,
        })

        vim.api.nvim_create_autocmd('FileType', {
          pattern = 'NvimTree',
          callback = function()
            vim.schedule(apply_nvim_tree_transparency)
          end,
        })
      '';
      settings = {
        view.width = 42;
        update_focused_file = {
          enable = true;
          update_root = false;
        };
      };
    };

    telescope = {
      enable = true;
      extensions.fzf-native = {
        enable = true;
        settings = {
          fuzzy = true;
          override_generic_sorter = true;
          override_file_sorter = true;
          case_mode = "smart_case";
        };
      };
      settings.defaults.mappings.i."<Esc>".__raw = "require('telescope.actions').close";
    };

    toggleterm.enable = true;

    web-devicons.enable = true;
  };

  extraConfigLua = ''
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
      { 'n', '<leader>b', '<cmd>Telescope buffers<cr>' },
      { 'n', '<leader>dB', confirm_clear_buffers },
      { 'n', 'B', '<cmd>Telescope buffers<cr>' },
      { 'n', '<a-k>', '<cmd>GitGutterPrevHunk<cr>' },
      { 'n', '<a-j>', '<cmd>GitGutterNextHunk<cr>' },
      { 'n', '<c-h>', '<cmd>bp<cr>' },
      { 'n', '<c-l>', '<cmd>bn<cr>' },
      { 'n', '<leader>c', '<cmd>bp<bar>bd#<cr>' },
    }) do
      map(m[1], m[2], m[3])
    end

    vim.keymap.set('n', '<leader>/', function()
      return vim.v.count == 0 and '<Plug>(comment_toggle_linewise_current)'
        or '<Plug>(comment_toggle_linewise_count)'
    end, { expr = true, silent = true, desc = 'Toggle line comment' })

    vim.keymap.set('x', '<leader>/', '<Plug>(comment_toggle_blockwise_visual)', {
      silent = true,
      desc = 'Toggle block comment',
    })
  '';
}
