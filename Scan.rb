require_relative 'Setup'
require_relative 'Room'
require_relative 'Game'

def action_list(list, action_hash)
	return [] if list.length <= 0
	return [] if action_hash.length <= 0
	newhash = {}
	action_hash.each do |key, piece|
		regex = piece.gsub("%p", "([^ ,]+(?: ?[^ ,]+))")
		newhash[key] = Regexp.new("(#{regex})", Regexp::IGNORECASE)
	end
	ret = []
	for item in list
		next if item[:user] == "modkiwi"
		for post in item[:posts]
			newhash.each do |key, regex|
				ret += post.scan(regex).collect{|piece| [item[:user], key] + piece}
			end
		end
	end
	return ret
end

def scan_actions(list)
	return [] if list.length <= 0
	actions = []
	pattern = /(lock ?)?(vote|leaderoffer|leaderaccept|revokeoffer|mayor)(?: (?:for )?(\w+))?/i
	for item in list
		for post in item[:posts]
			for action in post.scan(pattern)
				action[1] = "" unless action[1]
				actions.push([item[:user], action[1].downcase, action[2], action[0]])
			end
		end
	end
	actions
end

def scan_room(rid, hidden, only_new = true, verbose = false)
	room = Room.new(rid, hidden)
	if only_new
		list = $wi.get_posts(room.thread, room.last_article)
	else
		list = $wi.get_posts(room.thread)
		room.clear_votes
	end
	return if list.length <= 0
	room.last_article = list.last[:id]
	actions = scan_actions(list)
	for action in actions
		next unless actor = $pl.get_player(action[0], room.players, verbose)
		case action[1]
			when "revokeoffer"
				puts "#{$pl[actor].name} revokes all offers of leadership" if verbose
				room.revoke_offer(actor)
			when "mayor"
				puts "#{$pl[actor].name} has public revealed as mayor" if verbose
				room.set_weight(actor, 2.5)
		end

		next unless action[2]
		next unless actee = $pl.get_player(action[2], room.players, verbose)
		case action[1]
			when "vote"
				puts "#{$pl[actor].name} #{action[3] ? "lock" : ""}votes for #{$pl[actee].name}" if verbose
				room.vote(actor, actee, action[3])
			when "leaderoffer"
				puts "#{$pl[actor].name} offers leadership to #{$pl[actee].name}" if verbose
				room.offer_player(actor, actee)
			when "leaderaccept"
				if room.accept_offer(actor, actee)
					puts "#{$pl[actor].name} accepts leadership from #{$pl[actee].name}" if verbose
				else
					puts "#{$pl[actor].name} tries to accept leadership from #{$pl[actee].name}, but it has not been offered" if verbose
				end
		end
	end
end

def scan_signups(gid, verbose = false, only_new = true)
	res = $conn.query("SELECT thread_id, last_scanned, max_players, acronym FROM games WHERE gid = #{gid}")
	return unless row = res.fetch_row
	thread = row[0]
	if only_new
		last = row[1]
	else
		last = nil
	end
	max_players = row[2]
	max_players = max_players.to_i if max_players
	acronym = row[3]
	g = Game.new(gid)
	plist = g.all_players
	plist.collect!{|pid| $pl[pid].name.downcase}
	current_players = plist.length
	list = $wi.get_posts(thread, last)
	return if list.length <= 0
	new_last = list.last[:id]

	action_hash = Constants::SIGNUP_ACTIONS

	if (acronym)
		acronym = acronym.upcase.split(" ")
		acregex = acronym.collect{|word| "(#{word[0]}\\w*)"}.join("\\W+")
		action_hash[:acronym] = acregex
	end

	actions = action_list(list, action_hash)

	add = []
	remove = []

	guesses = []

	for action in actions
		case action[1]
		when :signup
			puts "#{action[0]} has signed up for #{g.name}" if verbose
			if (plist.include?(action[0].downcase))
				remove -= [action[0]]
			else
				add.push(action[0]) unless add.include?(action[0])
			end
		when :remove
			puts "#{action[0]} has removed from #{g.name}" if verbose
			if (plist.include?(action[0].downcase))
				remove.push(action[0]) unless remove.include?(action[0])
			else
				add -= [action[0]]
			end
		when :acronym
			puts "#{action[0]} has guessed #{action[2]} in #{g.name}" if verbose
			guess = action.drop(3).collect{|word| word.upcase}
			num = 0
			tot = acronym.length
			for i in (0...tot)
				num += 1 if acronym[i] == guess[i]
			end
			result = "#{num}/#{tot}"
			guesses.push([action[0], action[2], result])
			if (result == tot)
				$conn.query("UPDATE games SET acronym = NULL WHERE gid = #{gid}")
			end
		end
	end

	add = add[0...(max_players - current_players + remove.length)] if max_players

	add.collect!{|pname| $pl.get_id(pname, true)}
	remove.collect!{|pname| $pl.get_id(pname)}

	$conn.query("DELETE FROM game_players WHERE gid = #{gid} AND pid IN (#{remove.join(", ")}") if remove.length > 0
	
	$conn.query("INSERT INTO game_players (gid, pid) VALUES #{add.collect{|pid| "(#{gid}, #{pid})"}.join(", ")}") if add.length > 0
	if (add.length > 0 || remove.length > 0)
		$conn.query("UPDATE games SET signup_modified = TRUE, last_scanned = #{new_last} WHERE gid = #{gid}")
	else
		$conn.query("UPDATE games SET last_scanned = #{new_last} WHERE gid = #{gid}")
	end

	post = guesses.collect{|guess| "[q=\"#{guess[0]}\"][b]#{guess[1]}[/b][/q][color=#008800]#{guess[2]}[/color]"}.join("\n\n")
	$wi.post(thread, post)
end

# TODO: Fix this
def scan_transfers(m, verbose = false)
	list = $wi.mail_since(m.last_mail)
	return if list.length <= 0
	m.last_mail = list.last[:id]
	transfermail = []
	pattern = /(?:transfer|send) (\w+)/i
	for item in list
		for post in item[:body]
			for order in post.scan(pattern)
				transfermail.push([item[:from], order[0]])
			end
		end
	end
	for tr in transfermail
		matches = m.get_player_room(tr[0], m.all_players, verbose)
		next unless matches
		(sender, room) = matches
		matches = $pl.get_player(tr[1], room.players, verbose)
		next unless matches
		sent = matches

		puts "#{$pl[sender].name} wants to send #{$pl[sent].name}" if verbose
		room.add_transfer(sender, [sent])
	end
end

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
			temp_password(pid, pass)
			$wi.send_geekmail(item[:from], "Modkiwi password reset", "You may use the following temporary password to log in to ModKiwi:\n\nUsername: #{item[:from]}\nPassword: #{pass}\n\nYou will be prompted to change your password when you log in. Temporary passwords expire after use or after 24 hours. Passwords should be at least six characters in length. Passwords may not be transmitted securely, so do not use a password that you use for anything else.")
		end
	end
end
