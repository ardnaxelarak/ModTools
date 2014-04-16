#!/usr/bin/ruby

def scan_transfers(m, wi, pl, verbose = false)
	list = wi.mail_since(m.last_mail)
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
		matches = pl.get_player(tr[1], room.players, verbose)
		next unless matches
		sent = matches

		puts "#{pl[sender].name} wants to send #{pl[sent].name}" if verbose
		room.add_transfer(sender, [sent])
	end
end
