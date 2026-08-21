{
  lib,
  pkgs,
  ...
}:
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

    vim.cmd.packadd('vscode.nvim')

    local vscode = require('vscode')
    vscode.setup({ transparent = true })
    vscode.load()
  '';

  extraPlugins = [
    {
      plugin = pkgs.vimPlugins.vscode-nvim;
      optional = true;
    }
  ];

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
      luaConfig.pre = ''
        local current_nvim_tree_file
        local nvim_tree_current_file_namespace = vim.api.nvim_create_namespace('NvimTreeCurrentFile')

        local function highlight_current_nvim_tree_file(event)
          local bufnr = event and event.bufnr or require('nvim-tree.view').get_bufnr()
          if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end

          vim.api.nvim_buf_clear_namespace(bufnr, nvim_tree_current_file_namespace, 0, -1)
          if not current_nvim_tree_file then
            return
          end

          local explorer = require('nvim-tree.core').get_explorer()
          if not explorer then
            return
          end

          local line = explorer:find_node_line(explorer:get_node_from_path(current_nvim_tree_file))
          if line < 1 then
            return
          end

          vim.api.nvim_buf_set_extmark(bufnr, nvim_tree_current_file_namespace, line - 1, 0, {
            line_hl_group = 'NvimTreeCurrentFile',
            priority = 300,
          })
        end

        local function update_current_nvim_tree_file(bufnr)
          if vim.bo[bufnr].buftype ~= "" then
            return
          end

          local path = vim.api.nvim_buf_get_name(bufnr)
          current_nvim_tree_file = path ~= "" and (vim.uv.fs_realpath(path) or path) or nil
          vim.schedule(highlight_current_nvim_tree_file)
        end

        vim.api.nvim_create_autocmd('BufEnter', {
          callback = function(args)
            update_current_nvim_tree_file(args.buf)
          end,
        })

        update_current_nvim_tree_file(vim.api.nvim_get_current_buf())
      '';
      luaConfig.post = ''
        local saved_guicursor

        local nvim_tree_api = require('nvim-tree.api')
        nvim_tree_api.events.subscribe(
          nvim_tree_api.events.Event.TreeRendered,
          highlight_current_nvim_tree_file
        )

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
          }) do
            vim.api.nvim_set_hl(0, group, { bg = 'NONE' })
          end
          vim.api.nvim_set_hl(0, 'NvimTreeWinSeparator', { bg = 'NONE', fg = 'NONE' })
          vim.api.nvim_set_hl(0, 'NvimTreeCurrentFile', { link = 'Visual' })
          vim.api.nvim_set_hl(0, 'NvimTreeHiddenCursor', { blend = 100, reverse = true })
        end

        local function hide_nvim_tree_cursor()
          if vim.bo.filetype ~= 'NvimTree' or saved_guicursor ~= nil then
            return
          end

          saved_guicursor = vim.o.guicursor
          vim.o.guicursor = 'n-v-ve-o:block-NvimTreeHiddenCursor'
        end

        local function restore_nvim_tree_cursor()
          if saved_guicursor == nil then
            return
          end

          vim.o.guicursor = saved_guicursor
          saved_guicursor = nil
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
            hide_nvim_tree_cursor()
          end,
        })

        vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
          callback = hide_nvim_tree_cursor,
        })

        vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave', 'VimLeavePre' }, {
          callback = function()
            if vim.bo.filetype == 'NvimTree' then
              restore_nvim_tree_cursor()
            end
          end,
        })
      '';
      settings = {
        on_attach.__raw = ''
          function(bufnr)
            local api = require('nvim-tree.api')

            api.map.on_attach.default(bufnr)
            vim.keymap.set('n', '<c-e>', '<cmd>NvimTreeFindFileToggle<cr>', {
              buffer = bufnr,
              desc = 'nvim-tree: Toggle',
              silent = true,
            })
            vim.keymap.set('n', '<LeftRelease>', api.node.open.edit, {
              buffer = bufnr,
              desc = 'nvim-tree: Open',
              noremap = true,
              silent = true,
              nowait = true,
            })
          end
        '';
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

    local function toggle_or_focus_nvim_tree()
      local api = require('nvim-tree.api')

      if api.tree.is_visible() and not api.tree.is_tree_buf() then
        api.tree.focus()
        return
      end

      api.tree.toggle({ find_file = true, focus = true })
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
      { 'n', '<c-b>', toggle_or_focus_nvim_tree },
      { 'n', '<c-e>', toggle_or_focus_nvim_tree },
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
