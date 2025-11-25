local M = {}

---NB: there is only one current buf/win, therefor only one match

local augroups = require("infra.augroups")
local itertools = require("infra.itertools")
local ni = require("infra.ni")
local prefer = require("infra.prefer")
local unsafe = require("infra.unsafe")

local uv = vim.uv

local facts = {
  xmark_ns = ni.create_namespace("showmatch://xmark"),
  remain_time = 500, --in ms; see &matchtime
  ignore_buftypes = itertools.toset({ "terminal", "help", "quickfix" }),
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

local aug, bufaug ---@type infra.Augroup?, infra.BufAugroup?
local timer = uv.new_timer()
local clear_match = vim.schedule_wrap(function() marker:clear() end)

function M.activate()
  assert(not vim.go.showmatch, "conflict with &showmatch")
  if aug ~= nil then return end

  aug = augroups.Augroup("showmatch://")

  ---impl
  ---a) repeats:insertcharpre
  ---b) preats:winenter -> once:insertenter -> repeats:insertcharPre
  ---as insertcharpre can be fired frequently, b can be efficient than a
  aug:repeats({ "BufWinEnter", "WinEnter" }, {
    callback = function(args)
      local bufnr = assert(args.buf)
      --todo: `:term` hasnt been taken down
      if facts.ignore_buftypes[prefer.bo(bufnr, "buftype")] then return end

      if bufaug then
        if bufaug.bufnr == bufnr then return end
        bufaug:unlink()
        bufaug = augroups.BufAugroup(bufnr, "showmatch://insidebuf", false)
      else
        bufaug = augroups.BufAugroup(bufnr, "showmatch://insidebuf", false)
      end

      bufaug:once("InsertEnter", {
        callback = function() --
          local function insertcharpre()
            local lnum, col = unsafe.findmatch()
            if not (lnum and col) then return end
            marker:set(bufnr, lnum, col)
            timer:start(facts.remain_time, 0, clear_match)
          end
          bufaug:repeats("InsertCharPre", { callback = vim.schedule_wrap(insertcharpre) })
        end,
      })
    end,
  })

  --necessary for VimEnter, re-activate
  aug:emit("WinEnter", { buffer = ni.get_current_buf() })
end

function M.deactivate()
  if aug ~= nil then
    aug:unlink()
    aug = nil
  end

  if bufaug ~= nil then
    bufaug:unlink()
    bufaug = nil
  end

  timer:stop()
  marker:clear()
end

return M
