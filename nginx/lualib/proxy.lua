ssplit = require "ssplit"

local isWebsocket = function()
	local headers = ngx.req.get_headers()
	return headers["Upgrade"] == "websocket"
end

local getURLAndPort = function()
	local sp = ssplit.split(ngx.var.uri, "/")
	--ngx.log(ngx.WARN, ngx.var.uri)
	--ngx.log(ngx.WARN, #sp, " O ", sp[1], " a ", sp[2], " b ", sp[3], " c ", sp[4])

	local target_url_port
	local target_url
	local target_port
	if isWebsocket() then
		ngx.req.set_uri("/")
		target_url_port = upstream_servers.get(sp[2], "pushpin")
	elseif #sp <= 2 then
		target_url_port = upstream_servers.get("", "frontend")
	elseif ngx.var.arg_stream == "true" or ngx.var.arg_streamonly == "true"  then
		target_url_port = upstream_servers.get(sp[2], "pushpin")
	elseif #sp >= 4 then
		target_url_port = upstream_servers.get(sp[2]..sp[3]..sp[4], "frontend")
	else
		target_url_port = upstream_servers.get("", "frontend")
	end

	local sp = ssplit.split(target_url_port, ":")
	if #sp == 1 then target_url=target_url_port; target_port="80"
	else target_url=sp[1]; target_port=sp[2] end

	return target_url, target_port
end

local resolveURL = function(target_url)
	local address

	local appbase_env = os.getenv("APPBASE_ENV")
	if appbase_env == "PRODUCTION" then
		local resolver = require "resty.dns.resolver"
		local r, err = resolver:new{
			nameservers = {nameserver},
			retrans = 5,  -- 5 retransmissions on receive timeout
			timeout = 2000,  -- 2 sec
		}

		if not r then
			ngx.log(ngx.ERR, "failed to instantiate the DNS resolver: ", err)
			return
		end

		local answers, err = r:query(target_url)
		if not answers then
			ngx.log(ngx.ERR, "failed to query the DNS server: ", err)
			return
		end

		local count = 0
		for a,answer in pairs(answers) do
			if answer["address"] then
				address = answer["address"]
				break
			end
		end
	else
		address = target_url
	end

	return address
end

local target_url, target_port = getURLAndPort()
local address = resolveURL(target_url)

ngx.var.target = address..":"..target_port
