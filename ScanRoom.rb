#!/usr/bin/ruby

require_relative "WebInterface"
require_relative "Room"
require_relative "PlayerList"

def scan_actions(list)
	return if list.length <= 0
	actions = []
	pattern = /(lock ?)?(vote|leaderoffer|leaderaccept|revokeoffer|mayor)(?: (\w+))?/i
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

def scan_room(wi, pl, room, only_new = true, verbose = false)
	if only_new
		list = wi.get_posts(room.thread, room.last_article)
	else
		list = wi.get_posts(room.thread)
		room.clear_votes
	end
	return if list.length <= 0
	room.last_article = list.last[:id]
	actions = scan_actions(list)
	for action in actions
		next unless actor = pl.get_player(action[0], room.players, verbose)
		case action[1]
			when "revokeoffer"
				puts "#{pl[actor].name} revokes all offers of leadership" if verbose
				room.revoke_offer(actor)
			when "mayor"
				puts "#{pl[actor].name} has public revealed as mayor" if verbose
				room.weight[actor] = 2.5
		end

		next unless action[2]
		next unless actee = pl.get_player(action[2], room.players, verbose)
		case action[1]
			when "vote"
				puts "#{pl[actor].name} #{action[3] ? "lock" : ""}votes for #{pl[actee].name}" if verbose
				room.vote(actor, actee, action[3])
			when "leaderoffer"
				puts "#{pl[actor].name} offers leadership to #{pl[actee].name}" if verbose
				room.offer_player(actor, actee)
			when "leaderaccept"
				if room.accept_offer(actor, actee)
					puts "#{pl[actor].name} accepts leadership from #{pl[actee].name}" if verbose
				else
					puts "#{pl[actor].name} tries to accept leadership from #{pl[actee].name}, but it has not been offered" if verbose
				end
		end
	end
end
