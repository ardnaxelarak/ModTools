#!/usr/bin/ruby

require_relative "WebInterface"
require_relative "Room"
require_relative "PlayerList"

def scan_room(wi, pl, room, verbose = false)
	list = wi.get_posts(room.thread, room.last_article)
	return if list.length <= 0
	room.last_article = list.last[:id]
	voteposts = []
	for item in list
		for post in item[:posts]
			voteposts.push([item[:user], post]) if post.downcase.include?("vote ")
		end
	end
	for vote in voteposts
		matches = pl.get_player(vote[0], room.players, verbose)
		next unless matches
		voter = matches
		matches = vote[1].match(/vote ([^ ,]+)/i)
		next unless matches
		next unless matches.length > 1
		matches = pl.get_player(matches[1], room.players, verbose)
		next unless matches
		votee = matches

		lock = false
		lock = true if vote[1].downcase.include?("lock vote")
		lock = true if vote[1].downcase.include?("lockvote")

		puts "#{pl[voter].name} #{lock ? "lock" : ""}votes for #{pl[votee].name}" if verbose
		room.vote(voter, votee, lock)
	end
end
