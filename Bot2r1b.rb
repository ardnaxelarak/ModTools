#!/usr/bin/ruby

require_relative 'Setup'
require_relative 'Scan'
require_relative 'Room'
require 'yaml'

class Bot2r1b
	attr_accessor :roundnum, :filename, :last_mail, :rooms, :index
	attr_accessor :gid, :name, :thread, :hidden

	def initialize(gid)
		@gid = gid
		res = $conn.query("SELECT name, thread_id, rooms_hidden FROM games WHERE gid = #{@gid}")
		return unless row = res.fetch_row
		(@name, @thread, @hidden) = row
		@hidden = @hidden != "0"
	end

	def self.create(index, name, thread)
		$conn.query("INSERT INTO games (tid, game_index, name, thread_id) VALUES (1, '#{index}', '#{name}', '#{thread}')")
		return nil unless row = $conn.query("SELECT max(gid) FROM games WHERE tid = 1 AND game_index = '#{index}'").fetch_row
		return Bot2r1b.new(row[0].to_i)
	end

	def initialize_mail
		# @last_mail = $wi.latest_geekmail
	end

	def all_players
		res = $conn.query("SELECT pid FROM current_rooms INNER JOIN room_players ON current_rooms.rid = room_players.rid WHERE current_rooms.gid = #{@gid}")
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

	def round_num
		res = $conn.query("SELECT round_num FROM games WHERE games.gid = #{@gid}")
		return nil unless row = res.fetch_row
		return row[0].to_i
	end

	def name_list(pids, verb = false)
		return "" if pids.length == 0
		return "#{$pl[pids[0]].name}#{verb ? " is" : ""}" if pids.length == 1
		return "#{pids.collect{|pid| $pl[pid].name}.join{" and "}}#{verb ? " are" : ""}" if pids.length == 2
		return "#{pids[0...-1].collect{|pid| $pl[pid].name}.join(", ")}, and #{$pl[pids[-1]].name}#{verb ? " are" : ""}"
	end

	def get_player_room(name, list = all_players, verbose = true,
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

	def new_room
		print "Name: "
		name = gets.chomp
		print "Thread: "
		thread = gets.chomp
		puts "Players:"
		players = []
		print "- "
		while (line = gets)
			line.chomp!
			if (opt = $pl.get_player(line))
				players.push(opt)
				puts "Added #{$pl[opt].name}"
			end
			print "- "
		end
		print "\b\b"
		players.uniq!
		rid = create_room(name, thread, players)
		if rid
			puts "#{name} created. (#{players.collect{|ind| $pl[ind].name}.sort_by{|name| name.upcase}.join(", ")})"
		else
			puts "Error occurred"
		end
	end

	def create_room(name, thread, players, leader = nil)
		rn = round_num
		$conn.query("INSERT INTO rooms (gid, thread_id, round_num, name, leader) VALUES (#{@gid}, '#{thread}', #{round_num}, '#{name}', #{leader ? leader : "NULL"})")
		res = $conn.query("SELECT rid FROM rooms WHERE gid = #{@gid} AND round_num = #{rn} AND thread_id = '#{thread}' AND name = '#{name}'")
		return nil unless row = res.fetch_row
		return nil unless players
		rid = row[0].to_i
		plist = players.collect{|pid| "(#{rid}, #{pid})"}.join(", ")
		$conn.query("INSERT INTO room_players (rid, pid) VALUES #{plist}")
		return rid
	end

	def next_round
		curround = round_num
		newround = curround + 1
		res = $conn.query("SELECT rid FROM rooms WHERE gid = #{@gid} AND round_num = #{newround}")
		if res.num_rows > 0
			print "Data already exists for round #{newround}. Overwrite? "
			return unless gets.chomp.upcase == "YES"
			$conn.query("DELETE FROM rooms WHERE gid = #{@gid} AND round_num = #{newround}")
		end

		res = $conn.query("SELECT rid, leader, name FROM rooms WHERE rooms.gid = #{@gid} AND round_num = #{curround}")
		rooms = []
		for row in res
			leader = row[1]
			leader = leader.to_i if leader
			rooms.push({:rid => row[0].to_i, :leader => leader, :name => row[2], :players => []})
		end

		if (hidden)
			for room in rooms
				print "#{room[:name]} round #{newround} thread: "
				thread = gets.chomp
				room[:thread] = thread
			end

			$conn.query("UPDATE games SET round_num = #{newround} WHERE gid = #{@gid}")
			for room in rooms
				rid = create_room(room[:name], room[:thread], nil, nil)
				puts "#{room[:name]} created."
			end
		else
			for room in rooms
				res = $conn.query("SELECT pid FROM room_players WHERE rid = #{room[:rid]}")
				for row in res
					room[:players].push(row[0].to_i)
				end

				print "#{room[:name]} round #{newround} thread: "
				thread = gets.chomp
				room[:thread] = thread
				unless room[:leader]
					leader = Room.new(room[:rid], hidden).choose_leader
					room[:leader] = leader
					puts "#{$pl[leader].name} has become leader of #{room[:name]}!" if leader
				end
			end

			for fromdata in rooms
				for todata in rooms
					next if fromdata == todata
					puts "Transfers from #{fromdata[:name]} to #{todata[:name]}#{fromdata[:leader] ? " (#{$pl[fromdata[:leader]].name})" : ""}"
					print "- "
					while (line = gets)
						line.chomp!
						if (pid = $pl.get_player(line, fromdata[:players]))
							fromdata[:players] -= [pid]
							todata[:players] += [pid]
							puts "Transferred #{$pl[pid].name}"
						end
						print "- "
					end
					print "\b\b"
				end
			end

			$conn.query("UPDATE games SET round_num = #{newround} WHERE gid = #{@gid}")
			for room in rooms
				rid = create_room(room[:name], room[:thread], room[:players], room[:leader])
				puts "#{room[:name]} created. (#{room[:players].collect{|ind| $pl[ind].name}.sort_by{|name| name.upcase}.join(", ")})"
			end
		end
	end

	# TODO: fix this
	def auto_next_round(new_deadline, additional = nil)
		newround = @roundnum + 1
		@rooms[newround] = [] unless @rooms[newround]
		unless @rooms[newround] == []
			print "Data already exists for round #{newround + 1}. Overwrite? "
			return unless gets.chomp.upcase == "YES"
			@rooms[newround] = []
		end

		data = []

		for oldroom in @rooms[@roundnum]
			data.push([oldroom, nil, oldroom.players, nil])
			unless oldroom.leader
				leader = oldroom.choose_leader
				puts "#{$pl[leader].name} has become leader of #{oldroom.name}!"
			end
		end

		data[0][3] = data[0][0].get_transfer
		data[1][3] = data[1][0].get_transfer

		for datum in data
			next if datum[3]
			opts = datum[0].players - [datum[0].leader]
			# should really check how many transfers need to happen
			datum[3] = opts[0...1]
			puts "No orders for #{datum[0].name}; randomly selected #{name_list(datum[3])}"
		end

		data[0][2] -= data[0][3]
		data[1][2] += data[0][3]

		data[1][2] -= data[1][3]
		data[0][2] += data[1][3]

		for piece in data
			puts "Transferred #{name_list(piece[3])}"
		end

		for datum in data
			otherroom = (data - [datum])[0][0]
			room = datum[0]
			pl = datum[2]
			text = "[b]Players beginning in #{room.name} in Round ##{newround + 1}:[/b]\n"
			text << pl.collect{|pid| $pl[pid].name}.join("\n")
			text << "\n\n[b]Starting Leader:[/b]\n[o]#{$pl[room.leader].name}[/o]\n\n"

			text << "Room, please elect a leader and choose ONE PERSON to transfer from #{room.name} to #{otherroom.name}.\nLeader, please PM modkiwi your choice in bold in the body of the GM, written as either [b]send [i]player[/i][/b] or [b]transfer [i]player[/i][/b].\n"
			text << "Links for Lazy Leaders:\n"
			text << pl.collect{|pid| $pl[pid].name}.collect{|name| "[url=http://boardgamegeek.com/geekmail/compose?touser=modkiwi&subject=#{index.gsub(" ", "%20")}%20Transfer%20Orders&body=%5Bb%5Dtransfer%20#{name.gsub(" ", "%20")}%5B/b%5D]Send #{name}[/url]"}.join("\n")
			
			text << "\n\nTo ensure the proper functioning of the modbot, please follow these guidlines:\n- all in-game actions should be in bold\n- when referring to players, use either a username or nickname that [u]does not contain any spaces[/u]. To refer to Hal 2000, Hal2000 will work fine (as will Hal or 2000).\n- To vote for a player, use [b]vote [i]player[/i][/b]. To make a locked vote, use [b]lock vote [i]player[/i][/b] or [b]lockvote [i]player[/i][/b].\n- To offer leadership to another player, use [b]leaderoffer [i]player[/i][/b]. If you previously offered leadership to another player, this will override the previous offer; if your offer of leadership has already been accepted, this will have no function.\n- To accept leadership from another player, use [b]leaderaccept [i]player[/i][/b]. If this player has not offered you leadership, nothing will happen. If they have offered you leadership, you will become leader if they are the current leader, or otherwise will become the leader instead of them if they gain leadership in the future.\n- To revoke an offer of leadership, whether it has already been accepted or not (unless they have already become leader), use [b]revokeoffer[/b].\n\n"
			text << "Your deadline to do this is #{new_deadline} BGG time (CST).\n\nIf you have a rules or role question, [COLOR=#FF9900][b][u][url=http://boardgamegeek.com/geekmail/compose?touser=Kiwi13cubed&subject=PBF%20#{index.gsub(" ", "%20")}%20-%20Clarification%20Request]PM me[/url][/u][/b][/COLOR], and I'll answer them in the main thread.\n"
			text << "Please remember: [u]All players assigned into a room MUST NOT CHEAT and look at the other room's thread.[/u] They may only read and post in their assigned room and chambers (unless of course, your role power violates that)."
			text << "\n\n#{additional}" if additional
			datum[1] = $wi.post_thread(134352, 194, "2R1B PBF ##{index} - #{datum[0].name} - Round #{newround + 1}", text)
		end

		@roundnum = newround
		for datum in data
			room = datum[0].next_round(datum[1], datum[2])
			@rooms[@roundnum].push(room)
			puts "#{room.name} created. (#{room.players.collect{|ind| $pl[ind].name}.sort_by{|name| name.upcase}.join(", ")})"

			text = "[color=#009900]"
			incoming = []
			for toroom in data
				next if datum == toroom
				text << "#{name_list(datum[3], true)} sent to [thread=#{toroom[1]}]#{toroom[0].name}[/thread]\n"
				incoming += toroom[3]
			end
			text << "Everyone else remains in [thread=#{datum[1]}]#{datum[0].name}[/thread], joined by #{incoming.collect{|pid| $pl[pid].name}.join{", "}}."
			text << "[/color]"
			$wi.post(datum[0].thread, text)
		end
	end

	def tally(force = false, rl = nil, verbose = true)
		rl = all_rooms unless rl
		for rid in rl
			room = Room.new(rid, hidden)
			if force || room.need_tally?
				if $wi.post(room.thread, room.tally(true))
					puts "Updated vote tally of #{room.name}" if verbose
				else
					puts "Update of #{room.name} failed!"
				end
			else
				puts "Nothing has happened since the last vote tally of #{room.name}" if verbose
			end
		end
	end

	def scan(verbose = false, only_new = true, rl = nil)
		rl = all_rooms unless rl
		for rid in rl
			scan_room(rid, hidden, only_new, verbose)
		end
	end

	def transfer(p1, list)
		# return unless (pid_room = get_player_room(p1))
		# (sender, room) = pid_room
		# sent = []
		# for name in list
			# return unless cur = $pl.get_player(name, room.players)
			# sent.push(cur)
		# end
		# room.add_transfer(sender, sent)
	end

	def vote(p1, p2, locked = false)
		return unless (pid_room = get_player_room(p1))
		(voter, rid) = pid_room
		room = Room.new(rid, hidden)
		return unless (votee = $pl.get_player(p2, room.players))
		room.vote(voter, votee, locked)
	end

	def appoint(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, rid) = pid_room
		room = Room.new(rid, hidden)

		puts "#{$pl[pid]} has been appointed leader of #{room.name}"
		room.update_leader(pid)
	end

	def remove(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, rid) = pid_room
		room = Room.new(rid, hidden)
		room.remove_player(pid)
	end

	def add_player(p1, r1)
		return unless (pid = $pl.get_player(p1))
		# return if @rooms[@roundnum].collect{|r| r.players}.flatten.include?(pid)
		room = Room.new(r1, hidden)
		room.add_player(pid)
	end

	def lock(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, rid) = pid_room
		room = Room.new(rid, hidden)
		room.lock(pid)
	end

	def unlock(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, rid) = pid_room
		room = Room.new(rid, hidden)
		room.unlock(pid)
	end

	def get_rooms(names)
		return all_rooms if (names.nil? || names.length == 0)
		input = names.collect{|name| name.upcase}
		rl = []
		for name in names
			res = $conn.query("SELECT rid FROM current_rooms WHERE gid = #{@gid} AND name LIKE '#{name}'")
			puts "Unrecognized: #{name}" if res.num_rows == 0
			for row in res
				rl.push(row[0].to_i)
			end
		end
		if rl.length <= 0
			puts "No rooms selected"
			return nil
		else
			return rl
		end
	end

	def post(rl = nil)
		rl = all_rooms unless rl
		rooms = rl.collect{|rid| Room.new(rid, hidden)}
		puts "Type a message to post to the following rooms: #{rooms.collect{|room| room.name}.join(", ")}."

		text = ""
		while (line = gets)
			text << line
		end
		text.chomp!
		if (text == "")
			puts "You did not enter any text."
			return
		end
		puts "How would you like to post?"
		case gets.chomp.downcase
		when "green"
			text = "[color=#009900]#{text}[/color]"
		when "orange"
			text = "[b][color=orange]#{text}[/color][/b]"
		when "purple"
			text = "[b][color=purple]#{text}[/color][/b]"
		when "normal"
			text = text
		else
			return
		end
		for room in rl.collect{|rid| Room.new(rid, hidden)}
			$wi.post(room.thread, text)
		end
	end

	def change_round(num)
		$conn.query("UPDATE games SET round_num = #{num} WHERE gid = #{@gid}")
	end

	def print_status
		puts "Round #{round_num}"
		for rid in all_rooms
			room = Room.new(rid, hidden)
			puts "#{room.name}#{(room.need_tally?)?"*":""} - #{room.leader_name}"
			# puts "#{room.name}#{(room.need_tally?)?"*":""} - #{room.get_leader_name} (#{room.get_transfer ? room.get_transfer.collect{|pid| $pl[pid].name}.join(", ") : "none"})"
		end
	end
end
