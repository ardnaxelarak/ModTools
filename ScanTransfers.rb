#!/usr/bin/ruby

def scan_transfers(m, wi, pl, verbose = false)
	list = wi.mail_since(m.last_mail)
	return if list.length <= 0
	m.last_mail = list.last[:id]
	transfermail = []
	for item in list
		for post in item[:body]
			transfermail.push([item[:from], post]) if post.downcase.include?("transfer ") || post.downcase.include?("send ")
		end
	end
	for tr in transfermail
		matches = m.get_player_room(tr[0], m.all_players, verbose)
		next unless matches
		(sender, room) = matches
		matches = tr[1].match(/transfer ([^ ,]+)/i)
		matches = tr[1].match(/send ([^ ,]+)/i) unless matches
		next unless matches
		next unless matches.length > 1
		matches = pl.get_player(matches[1], room.players, verbose)
		next unless matches
		sent = matches

		puts "#{pl[sender].name} wants to send #{pl[sent].name}" if verbose
		room.add_transfer(sender, sent)
	end
end
