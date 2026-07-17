return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "tinymist",
        "laravel-ls",
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "typst",
        "php",
        "blade",
      },
    },
  },
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}
      table.insert(opts.sources, nls.builtins.formatting.phpcsfixer)
      table.insert(opts.sources, nls.builtins.diagnostics.phpcs)
    end,
  },
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        denols = {},
        tinymist = {
          settings = {
            formatterMode = "typstyle",
            exportPdf = "never",
            semanticTokens = "disable",
          },
        },
        intelephense = {
          enabled = true,
        },
      },
    },
  },
  {
    "chomosuke/typst-preview.nvim",
    ft = "typst",
    version = "1.*",
    opts = {
      dependencies_bin = {
        ["tinymist"] = "tinymist",
        ["websocat"] = nil,
      },
    }, -- lazy.nvim will implicitly calls `setup {}`
  },

  -- Flutter
  {
    "nvim-flutter/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim", -- optional for vim.ui.select
    },
    config = true,
  },
}
