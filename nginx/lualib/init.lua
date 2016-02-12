ssplit = require "ssplit"

local mapStrToInt = function (source, maxint)
	local hash = ngx.md5(source)
	local hashNumber = tonumber(hash:sub(31-8, 31-1), 16)
	return (hashNumber % maxint) + 1
end

local readResolvConf = function()
	local f = assert(io.open("/etc/resolv.conf", "r"))

	local search_domain
	local nameserver

	local line
	while true do 
		line = f:read()
		if line == nil then break end

		local sp = ssplit.split(line)

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
	for _, group in pairs(config) do
		num_groups = num_groups + 1
		for _, subgroup in pairs(group) do
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
			return subgroup[1]
		end
	else
		function router.get (key, subgroup_name)
			if key == "" then
				return config[math.random(#config)][subgroup_name][1]
			else
				local index = mapStrToInt(key, num_groups)
				local subgroup = config[index][subgroup_name]
				return subgroup[1]
			end
		end
	end

	return router
end

local search_domain, ns = readResolvConf()

nameserver = ns
upstream_servers = getRouter("SERVER_CONFIG", search_domain)
