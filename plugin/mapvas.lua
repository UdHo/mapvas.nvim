if vim.g.loaded_mapvas then return end
vim.g.loaded_mapvas = true

-- :Mapvas [range]  — send current buffer or visual selection
vim.api.nvim_create_user_command('Mapvas', function(opts)
  if opts.range > 0 then
    require('mapvas').send({ line1 = opts.line1, line2 = opts.line2 })
  else
    require('mapvas').send()
  end
end, {
  range = true,
  desc = 'Send buffer (or selection) to mapvas',
})

-- :MapvasClear  — clear the map
vim.api.nvim_create_user_command('MapvasClear', function()
  require('mapvas').clear()
end, { desc = 'Clear mapvas' })

-- :MapvasToggle  — toggle send-on-save + highlight-on-change
vim.api.nvim_create_user_command('MapvasToggle', function()
  require('mapvas').toggle_auto()
end, { desc = 'Toggle mapvas auto-send on save' })

-- :MapvasHighlight  — toggle coordinate highlighting
vim.api.nvim_create_user_command('MapvasHighlight', function()
  require('mapvas').toggle_highlight()
end, { desc = 'Toggle mapvas coordinate highlighting' })

-- :MapvasSidebar  — toggle layer explorer sidebar
vim.api.nvim_create_user_command('MapvasSidebar', function()
  require('mapvas').sidebar_toggle()
end, { desc = 'Toggle mapvas layer explorer sidebar' })
