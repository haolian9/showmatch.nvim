local M = {}

---NB: there is only one current buf/win, therefor only one match

local augroups = require("infra.augroups")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local unsafe = require("infra.unsafe")

local uv = vim.uv

local facts = {
  xmark_ns = ni.create_namespace("showmatch://xmark"),
  remain_time = 500, --in ms; see &matchtime
}

local marker = {}
do
  marker.xmid = nil
  marker.bufnr = nil

  function marker:clear()
    if self.xmid == nil then return end
    local bufnr, xmid = self.bufnr, self.xmid
    self.bufnr, self.xmid = nil, nil
    ni.buf_del_extmark(bufnr, facts.xmark_ns, xmid)
  end

  ---@param bufnr integer
  ---@param lnum integer @0-based
  ---@param col integer @0-based
  function marker:set(bufnr, lnum, col)
    self:clear()
    local xmid = ni.buf_set_extmark(bufnr, facts.xmark_ns, lnum, col, { end_row = lnum, end_col = col + 1, hl_group = "MatchParen" })
    self.bufnr, self.xmid = bufnr, xmid
  end
end

local aug
local timer = uv.new_timer()
local clear_match = vim.schedule_wrap(function() marker:clear() end)

function M.activate()
  if aug ~= nil then return end
  aug = augroups.Augroup("showmatch://")
  aug:repeats("InsertCharPre", {
    callback = function(args)
      local bufnr = ni.get_current_buf()
      assert(args.buf == bufnr)
      if prefer.bo(bufnr, "buftype") == "terminal" then return end
      vim.schedule(function()
        local lnum, col = unsafe.findmatch()
        if not (lnum and col) then return end
        marker:set(bufnr, lnum, col)
        timer:start(facts.remain_time, 0, clear_match)
      end)
    end,
  })
end

function M.deactivate()
  if aug == nil then return end

  aug:unlink()
  aug = nil

  timer:stop()
  marker:clear()
end

return M
