require 'digest/sha2'
require 'securerandom'
require_relative 'Setup'
require_relative 'Room'

def scan_actions(list)
	return if list.length <= 0
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

def scan_room(rid, only_new = true, verbose = false)
	room = Room.new(rid)
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
			set_password(pid, pass)
			$wi.send_geekmail(item[:from], "Modkiwi password reset", "Your password has been reset to \"#{pass}\".")
		end
	end
end
