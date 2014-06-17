require_relative 'Constants'

def close_connections
	$wi.stop
	$conn.close
end

def create_user(username)
	salt = Digest::SHA512.hexdigest(SecureRandom.hex)
	$conn.query("INSERT INTO players (username, salt) VALUES ('#{username}', '#{salt}')")
	res = $conn.query("SELECT pid FROM players WHERE username = '#{username}'")
	return nil unless res = res.fetch_row
	return res[0].to_i
end

def set_nicks(username, *nicks)
	res = $conn.query("SELECT pid FROM players WHERE username = '#{username}'")
	if res = res.fetch_row
		pid = res[0].to_i
	else
		pid = create_user(username)
	end

	return false unless pid
	
	nicklist = nicks.collect {|nick| "(#{pid}, '#{nick.upcase}')"}.join(", ")
	$conn.query("INSERT INTO nicks (pid, nick) VALUES #{nicklist}")
end

def set_password(pid, password)
	res = $conn.query("SELECT salt FROM players WHERE pid = #{pid}")
	return false unless salt = res.fetch_row
	salt = salt[0]
	password = Digest::SHA512.hexdigest(password)
	password = password + salt
	passwordhash = Digest::SHA512.hexdigest(password)
	$conn.query("UPDATE players SET password='#{passwordhash}' WHERE pid=#{pid}")
end

def temp_password(pid, password)
	res = $conn.query("SELECT salt FROM players WHERE pid = #{pid}")
	return false unless salt = res.fetch_row
	salt = salt[0]
	password = Digest::SHA512.hexdigest(password)
	password = password + salt
	passwordhash = Digest::SHA512.hexdigest(password)
	$conn.query("INSERT INTO temppass (pid, pass, time) VALUES (#{pid}, '#{passwordhash}', NOW())")
end

def gen_password
	return SecureRandom.urlsafe_base64
end

def escape(string)
	return "'#{string.gsub("'", "\\\\'")}'"
end
