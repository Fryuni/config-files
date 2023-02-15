local M = {}

M.settings = {}

M.packages = {
  ["jameshiew/nvim-magic"] = {
    "jameshiew/nvim-magic",
    commit = "9d306f5ac272eb7f7bf9b81d80f25e9973316a97",
  },
	requires = {
		'nvim-lua/plenary.nvim',
		'MunifTanjim/nui.nvim'
	}
}

M.configs = {}
M.configs["jameshiew/nvim-magic"] = function()
  require('nvim-magic').setup({})
end

-- M.binds = {
--   { '<leader>clt', name = "+tests", {
--     { 'f', name = "Test current file", "<cmd>TestFile<CR>" }
--   }}
-- }

return M
