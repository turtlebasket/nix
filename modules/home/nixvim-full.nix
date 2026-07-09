{ config, lib, ... }:
let
  treesitterGrammars = config.plugins.treesitter.package.builtGrammars;
in
{
  imports = [ ./nixvim-lite.nix ];

  extraConfigLuaPre = lib.mkOrder 110 ''
    vim.hl.priorities.semantic_tokens = 140
    vim.hl.priorities.treesitter = 100
  '';

  filetype.extension = {
    svelte = "svelte";
    svx = "markdown";
  };

  autoCmd = [
    {
      event = "FileType";
      pattern = [
        "svx"
      ];
      command = "setlocal wrap";
    }
  ];

  plugins = {
    cmp = {
      enable = true;
      settings = {
        mapping = {
          "<C-n>" = ''
            cmp.mapping(function()
              if cmp.visible() then
                cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
              else
                cmp.complete()
              end
            end, { 'i', 's' })
          '';
          "<C-p>" = ''
            cmp.mapping(function()
              if cmp.visible() then
                cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
              end
            end, { 'i', 's' })
          '';
          "<CR>" = ''
            cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.confirm({ select = true })
              else
                fallback()
              end
            end, { 'i', 's' })
          '';
        };
        sources = [
          { name = "nvim_lsp"; }
        ];
      };
    };

    lsp = {
      enable = true;
      servers = {
        basedpyright.enable = true;
        rust_analyzer = {
          enable = true;
          installCargo = false;
          installRustc = false;
        };
        svelte.enable = true;
        ts_ls.enable = true;
      };
    };

    treesitter = {
      enable = true;
      highlight.enable = true;
      grammarPackages = with treesitterGrammars; [
        css
        html
        javascript
        markdown
        markdown_inline
        svelte
        typescript
      ];
      languageRegister.markdown = "svx";
    };
  };

  extraConfigLua = ''
    local function map(mode, lhs, rhs)
      vim.keymap.set(mode, lhs, rhs, { silent = true })
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
      { 'n', '<leader>t', telescope_workspace_symbols },
      { 'n', '<leader>e', vim.diagnostic.open_float },
      { 'n', '\\', vim.lsp.buf.hover },
      { 'n', '<F12>', smart_definition },
      { 'n', '<S-F12>', function() require('telescope.builtin').lsp_references() end },
      { 'n', '<C-F12>', function() require('telescope.builtin').lsp_implementations() end },
      { 'n', '<F2>', vim.lsp.buf.rename },
    }) do
      map(m[1], m[2], m[3])
    end
  '';
}
