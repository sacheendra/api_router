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

local getHashRing = function(env_var_name, search_domain)
	local ring

	local env_var = assert(os.getenv(env_var_name))

	local addSearchDomain = function(server)
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

	local sp = ssplit.split(env_var, ";")
	if #sp == 1 then
		ring = {}
		function ring.get_upstream ()
			return addSearchDomain(env_var)
		end
	else
		ring = require "chash"
		for i = 1, #sp do
			ring.add_upstream(addSearchDomain(sp[i]))
		end
	end

	return ring
end

local search_domain, ns = readResolvConf()

nameserver = ns
pushpin_servers = getHashRing("PUSHPIN_SERVERS", search_domain)
frontend_servers = getHashRing("FRONTEND_SERVERS", search_domain)
