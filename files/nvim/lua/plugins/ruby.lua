return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Use the project's bundled rubocop/ruby-lsp instead of Mason's global
        -- copies, so gem versions match what's in the Gemfile.lock.
        rubocop = {
          cmd = { "bundle", "exec", "rubocop", "--lsp" },
        },
        ruby_lsp = {
          cmd = function(dispatchers, config)
            return vim.lsp.rpc.start(
              { "bundle", "exec", "ruby-lsp" },
              dispatchers,
              config and config.root_dir and { cwd = config.cmd_cwd or config.root_dir }
            )
          end,
        },
      },
    },
  },
}
