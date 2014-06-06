#!/usr/bin/ruby

require_relative 'Setup'

class Game
	attr_accessor :gid, :name, :thread, :index

	def initialize(gid)
		@gid = gid
		res = $conn.query("SELECT name, game_index, thread_id FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		(@name, @index, @thread) = row
	end

	def all_players
		res = $conn.query("SELECT pid FROM game_players WHERE gid = #{@gid}")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		return list
	end

	def mod_list
		res = $conn.query("SELECT pid FROM moderators WHERE gid = #{@gid}")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		return list
	end

	def name_list(pids, verb = false)
		return "" if pids.length == 0
		return "#{$pl[pids[0]].name}#{verb ? " is" : ""}" if pids.length == 1
		return "#{pids.collect{|pid| $pl[pid].name}.join{" and "}}#{verb ? " are" : ""}" if pids.length == 2
		return "#{pids[0...-1].collect{|pid| $pl[pid].name}.join(", ")}, and #{$pl[pids[-1]].name}#{verb ? " are" : ""}"
	end
end
