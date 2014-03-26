#!/usr/bin/ruby

require_relative "WebInterface"
require_relative "Room"
require_relative "PlayerList"

def scan_votes(list)
	return if list.length <= 0
	voteposts = []
	pattern = /(lock ?)?vote (\w+)/i
	for item in list
		for post in item[:posts]
			for vote in post.scan(pattern)
				voteposts.push([item[:user], vote[1], vote[0]])
			end
		end
	end
	voteposts
end

def scan_room(wi, pl, room, only_new = true, verbose = false)
	if only_new
		list = wi.get_posts(room.thread, room.last_article)
	else
		list = wi.get_posts(room.thread)
		room.clear_votes
	end
	return if list.length <= 0
	room.last_article = list.last[:id]
	voteposts = scan_votes(list)
	for vote in voteposts
		next unless voter = pl.get_player(vote[0], room.players, verbose)
		next unless votee = pl.get_player(vote[1], room.players, verbose)

		puts "#{pl[voter].name} #{vote[2] ? "lock" : ""}votes for #{pl[votee].name}" if verbose
		room.vote(voter, votee, vote[2])
	end
end
