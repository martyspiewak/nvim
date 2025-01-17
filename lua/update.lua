local jobs = require("packer.jobs")
local a = require("packer.async")
local result = require("packer.result")
local await = a.wait
local async = a.sync
local fmt = string.format
local check_dependencies = require("utils").check_dependencies

check_dependencies({ "curl", "npm", "rg", { "fd", "fdfind" } })

local memo = { status = "" }

local function notify(title, type, msg)
	if vim.in_fast_event() then
		vim.schedule(function()
			vim.notify_once(msg, type, { title = fmt("[Config] %s", title) })
		end)
	else
		vim.notify_once(msg, type, { title = fmt("[Config] %s", title) })
	end
end

local function printerr(title, msg)
	notify(msg, "error", title)
end

local function warn(title, msg)
	notify(msg, "warn", title)
end

local function async_command(cmd, ignore_error)
	return async(function()
		local r = result.ok()
		local opts = { capture_output = true, cwd = CONFIG_PATH }
		r:and_then(await, jobs.run(cmd, opts))
			:map_err(function(err)
				if not ignore_error then
					printerr("Failed to update config.", fmt("%s:\n%s", cmd, err.output.data.stderr[1]))
				end
				return nil
			end)
			:map_ok(function(ok)
				return ok.output.data.stdout[1]
			end)

		return r.ok
	end)
end

local function remote_version()
	return await(async_command("git rev-parse @{u}"))
end

local function local_version()
	return await(async_command("git rev-parse @"))
end

local function merge_base()
	return await(async_command("git merge-base @ @{u}"))
end

local M = {}

function M.status()
	return memo.status
end

function _G.config_update()
	async(function()
		local did_update = await(async_command("git checkout main"))
		if did_update == -1 then
			printerr("Failed updating config", "Try doing a git pull in the repository directly.")
			return
		end
	end)()
end

config_update()

return M
