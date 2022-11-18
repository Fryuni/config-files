local module = {}

module.settings = {}

module.packages = {
  ["klen/nvim-test"] = {
    "klen/nvim-test",
    commit = "bea40f71fc2b918ad6cf2154bcc12521ac664dc2",
  },
}

module.require_modules = { 'features.lsp' }

module.configs = {}
module.configs["klen/nvim-test"] = function()
  require('nvim-test').setup({})

  require('nvim-test.runners.jest'):setup {
    -- Use local jest installation of whichever project is being executed
    command = "./node_modules/.bin/jest",
  }
end

module.binds = {
  { '<leader>clt', name = "+tests", {
    { 'f', name = "Test current file", "<cmd>TestFile<CR>" }
  }}
}

return module
