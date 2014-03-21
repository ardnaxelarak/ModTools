#!/usr/bin/ruby

require_relative "WebInterface"
require_relative "Room"
require_relative "PlayerList"

def scan_room(wi, pl, room)
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
		matches = pl.match(vote[0], room.players)
		next if matches.length != 1
		voter = matches[0]
		matches = vote[1].match(/vote ([a-zA-Z0-9]+)/i)
		next unless matches
		next unless matches.length > 1
		matches = pl.match(matches[1], room.players)
		next if matches.length != 1
		votee = matches[0]

		lock = false
		lock = true if vote[1].downcase.include?("lock vote")
		lock = true if vote[1].downcase.include?("lockvote")

		room.vote(voter, votee, lock)
		# puts "#{pl[voter].name} votes for #{pl[votee].name}"
	end
end
