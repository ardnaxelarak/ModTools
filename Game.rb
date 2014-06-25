#!/usr/bin/ruby

require_relative 'Setup'
require_relative 'Room'

class Game
	attr_accessor :gid, :name, :thread, :index, :history_id, :status_id

	def initialize(gid)
		@gid = gid
		res = $conn.query("SELECT name, game_index, thread_id, history_id, status_id FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		(@name, @index, @thread, @history_id, @status_id) = row
	end

	def all_players
		res = $conn.query("SELECT pid FROM game_players WHERE gid = #{@gid}")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		return list
	end

	def turn_order
		res = $conn.query("SELECT pid FROM turn_order WHERE gid = #{@gid} ORDER BY id")
		list = []
		for row in res
			list.push(row[0].to_i)
		end
		return list
	end

	def all_room_players
		res = $conn.query("SELECT pid FROM current_rooms INNER JOIN room_players ON current_rooms.rid = room_players.rid WHERE current_rooms.gid = #{@gid}")
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

	def all_rooms
		res = $conn.query("SELECT rid FROM current_rooms WHERE gid = #{@gid}")
		rl = []
		for row in res
			rl.push(row[0].to_i)
		end
		return rl
	end

	def name_list(pids, verb = false)
		return "" if pids.length == 0
		return "#{$pl[pids[0]].name}#{verb ? " is" : ""}" if pids.length == 1
		return "#{pids.collect{|pid| $pl[pid].name}.join{" and "}}#{verb ? " are" : ""}" if pids.length == 2
		return "#{pids[0...-1].collect{|pid| $pl[pid].name}.join(", ")}, and #{$pl[pids[-1]].name}#{verb ? " are" : ""}"
	end

	def round_num
		res = $conn.query("SELECT round_num FROM games WHERE games.gid = #{@gid}")
		return nil unless row = res.fetch_row
		return row[0].to_i
	end

	def get_player_room(name, list = all_room_players, verbose = true,
						none_message = nil, many_message = nil,
						room_message = nil)
		room_message = "%s: No room found\n"
		return nil unless (pid = $pl.get_player(name, list, verbose, none_message, many_message))
		res = $conn.query("SELECT current_rooms.rid FROM current_rooms INNER JOIN room_players ON current_rooms.rid = room_players.rid WHERE gid = #{@gid} AND pid = #{pid}")
		if row = res.fetch_row
			return [pid, row[0].to_i]
		else
			printf(room_message, $pl[pid].name) if verbose
			return nil
		end
	end

	def add_to_history(content, post = true)
		$conn.query("INSERT INTO game_history (gid, message) VALUES (#{@gid}, #{escape(content)})")
		$wi.post(thread, text) if post
		if @history_id
			text = ""
			res = $conn.query("SELECT message FROM game_history WHERE gid = #{@gid} ORDER BY id")
			for row in res
				text << "\n\n" unless text == ""
				text << row[0]
			end
			$wi.edit_article(@history_id, "Voting History", text)
		end
	end
end
