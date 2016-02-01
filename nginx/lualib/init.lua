ssplit = require "ssplit"

local readResolvConf = function()
	local f = assert(io.open("/etc/resolv.conf", "r"))

	local search_domain
	local nameserver

	local line
	while true do 
		line = f:read()
		if line == nil then break end

		local sp = ssplit.split(line, "%S+")
		if sp[1] == "search" then
			search_domain = sp[2]
		elseif sp[1] == "nameserver" then
			nameserver = sp[2]
		end
	end

	return search_domain, nameserver
end

local addSearchDomain = function(server, search_domain)
	if search_domain == nil then
		return server
	else
		local sp = ssplit.split(server, ":")
		if #sp == 1 then
			return server.."."..search_domain
		else 
			return sp[1].."."..search_domain..":"..sp[2]
		end
	end
end

local getRouter = function(env_var_name, search_domain)
	local cjson = require "cjson"
	local router = {}

	local env_var = assert(os.getenv(env_var_name))
	local config = cjson.decode(env_var)

	local num_groups = 0
	for group_name, group in pairs(config) do
		num_groups = num_groups + 1
		for subgroup_name, subgroup in pairs(group) do
			for i, server in ipairs(subgroup) do
				subgroup[i] = addSearchDomain(subgroup[i], search_domain)
			end
		end
	end
	assert(num_groups ~= 0, "No server groups found! Check your SERVER_CONFIG environment variable!")

	if num_groups == 1 then
		local lone_group 
		for _, group in pairs(config) do
			lone_group = group
		end

		function router.get (key, subgroup_name)
			local subgroup = lone_group[subgroup_name]
			return subgroup[math.random(#subgroup)]
		end
	else
		local ring = require "chash"
		for group_name, group in pairs(config) do
			ring.add_upstream(group_name)
		end

		function router.get (key, subgroup_name)
			local group_name = ring.get_upstream(key)
			local subgroup = config[group_name][subgroup_name]
			return subgroup[math.random(#subgroup)]
		end
	end

	return router
end

local search_domain, ns = readResolvConf()

nameserver = ns
upstream_servers = getRouter("SERVER_CONFIG", search_domain)
