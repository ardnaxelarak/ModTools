#!/usr/bin/ruby
require 'digest/sha2'
require 'securerandom'

def check_mail(verbose = false)
	list = $wi.geekmail_list(nil, true)
	return if list.length <= 0
	pattern = /(reset password)/i
	for item in list
		if item[:subject].match(pattern)
			puts "#{item[:from]} has requested a password reset." if verbose
			$wi.get_geekmail(item[:id])
			res = $conn.query("SELECT pid FROM players WHERE username = \"#{item[:from]}\";")
			if (res.num_rows <= 0)
				next unless pid = create_user(item[:from])
			else
				pid = res.fetch_row[0].to_i
			end
			pass = gen_password
			set_password(pid, pass)
			$wi.send_geekmail(item[:from], "Modkiwi password reset", "Your password has been reset to \"#{pass}\".")
		end
	end
end

def create_user(username)
	salt = Digest::SHA512.hexdigest(SecureRandom.hex)
	$conn.query("INSERT INTO players (username, salt) VALUES (\"#{username}\", \"#{salt}\");")
	res = $conn.query("SELECT pid FROM players WHERE username = \"#{username}\";")
	return nil unless res = res.fetch_row
	return res[0].to_i
end

def set_password(pid, password)
	res = $conn.query("SELECT salt FROM players WHERE pid = #{pid};")
	return false unless salt = res.fetch_row
	salt = salt[0]
	password = Digest::SHA512.hexdigest(password)
	password = password + salt
	passwordhash = Digest::SHA512.hexdigest(password)
	$conn.query("UPDATE players SET password=\"#{passwordhash}\" WHERE pid=#{pid};")
end

def gen_password
	return SecureRandom.urlsafe_base64
end
