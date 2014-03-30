#!/usr/bin/ruby

require_relative 'PlayerList'
require_relative 'WebInterface'
require_relative 'Room'
require_relative 'ScanRoom'
require 'yaml'

class Bot2r1b
	attr_accessor :roundnum, :filename, :last_mail, :rooms

	def initialize(filename)
		@roundnum = 0
		@filename = File.expand_path(filename)
		@rooms = [[]]
	end

	def save
		File.write(@filename, YAML::dump(self))
	end

	def all_players
		return nil unless @rooms[@roundnum]
		return nil if @rooms[@roundnum] == []
		return @rooms[@roundnum].collect{|room| room.players}.flatten.uniq
	end

	def get_player_room(name, list = all_players, verbose = true,
						none_message = nil, many_message = nil,
						room_message = nil)
		room_message = "%s: No room found\n"
		return nil unless (pid = @@pl.get_player(name, list, verbose, none_message, many_message))
		for r in @rooms[@roundnum]
			return [pid, r] if r.contain?(pid)
		end
		printf(room_message, @@pl[pid].name)
		return nil
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
			if (opt = @@pl.get_player(line))
				players.push(opt)
				puts "Added #{@@pl[opt].name}"
			end
			print "- "
		end
		print "\b\b"
		players.uniq!
		room = Room.new(name, thread, players)
		@rooms[@roundnum].push(room)
		puts "#{room.name} created. (#{room.players.collect{|ind| @@pl[ind].name}.sort_by{|name| name.upcase}.join(", ")})"
	end

	def next_round
		newround = @roundnum + 1
		@rooms[newround] = [] unless @rooms[newround]
		unless @rooms[newround] == []
			print "Data already exists for round #{newround + 1}. Overwrite? "
			return unless gets.chomp.upcase == "YES"
			@rooms[newround] = []
		end

		data = []

		for oldroom in @rooms[@roundnum]
			print "#{oldroom.name} round #{newround + 1} thread: "
			thread = gets.chomp
			data.push([oldroom, thread, oldroom.players])
			unless oldroom.leader
				leader = oldroom.choose_leader
				puts "#{@@pl[leader].name} has become leader of #{oldroom.name}!"
			end
		end

		for fromdata in data
			for todata in data
				next if fromdata == todata
				puts "Transfers from #{fromdata[0].name} to #{todata[0].name} (#{fromdata[0].leader_name(@@pl)}):"
				print "- "
				while (line = gets)
					line.chomp!
					if (pid = @@pl.get_player(line, fromdata[0].players))
						fromdata[2] -= [pid]
						todata[2] += [pid]
						puts "Transferred #{@@pl[pid].name}"
					end
					print "- "
				end
				print "\b\b"
			end
		end

		@roundnum = newround
		for datum in data
			room = datum[0].next_round(datum[1], datum[2])
			@rooms[@roundnum].push(room)
			puts "#{room.name} created. (#{room.players.collect{|ind| @@pl[ind].name}.sort_by{|name| name.upcase}.join(", ")})"
		end
	end

	def tally(force = false, rl = nil, verbose = true)
		rl = @rooms[@roundnum] unless rl
		for room in rl
			if force || room.need_tally?
				if @@wi.post(room.thread, room.tally(@@pl, true))
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
		rl = @rooms[@roundnum] unless rl
		for room in rl
			scan_room(@@wi, @@pl, room, only_new, verbose)
		end
	end

	def transfer(p1, list)
		return unless (pid_room = get_player_room(p1))
		(sender, room) = pid_room
		sent = []
		for name in list
			return unless cur = @@pl.get_player(name, room.players)
			sent.push(cur)
		end
		room.add_transfer(sender, sent)
	end

	def vote(p1, p2, locked = false)
		return unless (pid_room = get_player_room(p1))
		(voter, room) = pid_room
		return unless (votee = @@pl.get_player(p2, room.players))
		room.vote(voter, votee, locked)
	end

	def appoint(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, room) = pid_room

		puts "#{@@pl[pid]} has been appointed leader of #{room.name}"
		room.update_leader(pid)
	end

	def remove(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, room) = pid_room
		room.remove_player(pid)
	end

	def lock(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, room) = pid_room
		room.lock(pid)
	end

	def unlock(p1)
		return unless (pid_room = get_player_room(p1))
		(pid, room) = pid_room
		room.unlock(pid)
	end

	def get_rooms(names)
		return @rooms[@roundnum] if (names.nil? || names.length == 0)
		input = names.collect{|name| name.upcase}
		for bad in names.select{|name| !@rooms[@roundnum].collect{|room| room.name.upcase}.include?(name.upcase)}
			puts "Unrecongnized: #{bad}"
		end
		rl = @rooms[@roundnum].select{|room| input.include?(room.name.upcase)}
		if rl.length <= 0
			puts "No rooms selected"
			return nil
		else
			return rl
		end
	end

	def post(rl = nil)
		rl = @rooms[@roundnum] unless rl
		puts "Type a message to post to the following rooms: #{rl.collect{|room| room.name}.join(", ")}."

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
		for room in rl
			@@wi.post(room.thread, text)
		end
	end

	def change_round(num)
		@rooms[num] = [] unless @rooms[num]
		@roundnum = num - 1
	end

	def print_status
		puts "Round #{@roundnum + 1}"
		for room in @rooms[@roundnum]
			puts "#{room.name}#{(room.need_tally?)?"*":""} - #{room.leader ? @@pl[room.leader].name : "No leader"} (#{room.get_transfer ? room.get_transfer.collect{|pid| @@pl[pid].name}.join(", ") : "none"})"
		end
	end

	def update
		for room in @rooms.flatten
			next unless room
			room.locked = [] unless room.locked
			room.added = [] unless room.added
			room.removed = [] unless room.removed
			room.to_send = {} unless room.to_send
		end
	end
end
