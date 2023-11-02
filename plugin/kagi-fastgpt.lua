local curl = require('plenary.curl')
local cache = {}


local prompt = '❓'


local fetch = function (query)
  if cache[query] then
    return cache[query]
  end

  local resp = curl.post {
    url = 'https://kagi.com/api/v0/fastgpt',
    body = vim.fn.json_encode {
      query = query,
    },
    headers = {
      ['Content-Type'] = 'application/json',
      ['Authorization'] = 'Bot ' .. vim.env['KAGI_API_KEY'],
    },
  }

  local result = vim.fn.json_decode(resp.body)
  cache[query] = result
  return result
end


local go_last_line = function (buf)
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), #prompt + 1 })
end


local new_query = function (buf, query)
  vim.api.nvim_buf_set_lines(buf, -1, -1, true, { '...waiting...' })

  go_last_line(buf)
  vim.api.nvim_command('redraw')

  local output = { '' }

  local body = fetch(query)



  vim.api.nvim_buf_set_lines(buf, -2, -1, true, {})

  for _, l in ipairs(vim.fn.split(body.data.output, '\n')) do
    table.insert(output, l)
  end
  table.insert(output, '')
  if body.data.references then
    for i, ref in ipairs(body.data.references) do
      table.insert(output, '[' .. tostring(i) .. '] ' .. ref.title .. ' ' .. ref.url)
    end
  end

  table.insert(output, '')
  table.insert(output, prompt)

  vim.api.nvim_buf_set_lines(buf, -1, -1, true, output)

  go_last_line(buf)
end


local ask = function (buf)
  return function()
    local line = vim.api.nvim_get_current_line()
    if vim.startswith(line, prompt) then
      local query = vim.trim(line:sub(#prompt + 1))
      new_query(buf, query)
    end
  end
end

local create_buffer = function (_)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, { prompt })
  vim.api.nvim_win_set_buf(0, buf)
  vim.keymap.set('i', '<CR>', ask(buf), { silent = true, buffer = buf })
  vim.cmd.startinsert()
  vim.api.nvim_win_set_cursor(0, { 1, #prompt + 1 })
end

vim.api.nvim_create_user_command(
  'Fastgpt',
  function (opts)
    create_buffer(opts.args)
  end,
  {
    nargs = '?',
  }
)
