#!/usr/bin/ruby

require 'trollop'
require_relative 'Bot2r1b'
require_relative 'Setup'

opts = Trollop::options do
	banner "Usage:
	#{__FILE__} [options]\n\nwhere common options are:"
	opt :gid, "Game index", :type => :int, :short => "g"
	opt :create, "Create a new game", :short => "c"
	opt :next_round, "Initialize next round", :short => "n"
	opt :quiet, "Quiet mode", :short => "q"
	opt :post, "Make a post", :short => "p"
	opt :rooms, "Set rooms", :type => :strings
	opt :status, "Display current game status"
	opt :show_votes, "Display current votes"
	opt :appoint, "Appoint a player leader of their room", :type => :string, :short => "a"
	opt :remove, "Remove a player from the game", :type => :strings, :multi => true
	opt :add, "Add a player to a room", :type => :strings, :multi => true
	opt :list_rooms, "List the players occupying each room"
	opt :show_orders, "Display current transfer orders"
	opt :help, "Show this message", :short => "h"
	banner "\nand options that have mostly become unnecessary are:"
	opt :scan, "Scan the rooms", :short => "s"
	opt :new_room, "Create a new room"
	opt :rescan, "Reset vote counts and rescan", :short => "S"
	opt :tally, "Post vote tallies", :short => "t"
	opt :force_tally, "Force a posting of a vote tally", :short => "T"
	opt :vote, "Vote for a player", :type => :strings, :multi => true, :short => "v"
	opt :lock_vote, "Locked vote for a player", :type => :strings, :multi => true, :short => "V"
	opt :transfer, "Transfer a player", :type => :strings, :multi => true
	opt :lock, "Lock a player's vote", :type => :strings, :multi => true
	opt :unlock, "Unlock a player's vote", :type => :strings, :multi => true
	opt :round, "Set the current round", :type => :int
	opt :auto_next_round, "Initialize next round", :short => "N"
end

for vote in opts[:vote]
	Trollop::die :vote, "needs exactly two players" if vote.length != 2
end
for vote in opts[:lock_vote]
	Trollop::die :lock_vote, "needs exactly two players" if vote.length != 2
end

Trollop::die(:create, "may not specify a game index") if opts[:create] && opts[:gid_given]

$wi.verbose = !opts[:quiet]

if opts[:create]
	print "Index: "
	index = gets.chomp
	print "Name: "
	name = gets.chomp
	print "Thread: "
	thread = gets.chomp
	b = Bot2r1b.create(index, name, thread)
	puts "Setting up first room..."
	b.new_room
	puts "Setting up second room..."
	b.new_room
	b.initialize_mail
	puts "Created game #{b.gid}"
else
	Trollop::die(:gid, "must be specified") unless opts[:gid_given]
	Trollop::die(:gid, "does not exist") unless row = $conn.query("SELECT t.tid, t.short_name FROM games g LEFT JOIN game_types t ON g.tid = t.tid WHERE g.gid = #{opts[:gid]}").fetch_row
	Trollop::die(:gid, "refers to a #{row[1]} game") unless row[0].to_i == 1
	b = Bot2r1b.new(opts[:gid])
end

b.new_room if opts[:new_room]

b.next_round if opts[:next_round]
# b.auto_next_round("Friday, 16:00", "[b][color=purple]You may not colour reveal or colour share. Only full reveals are allowed.[/color][/b]") if opts[:auto_next_round]

Trollop::die "invalid round number" if opts[:round_given] && $conn.query("SELECT rid FROM rooms WHERE gid = #{b.gid} AND round_num = #{opts[:round]}").num_rows == 0

Trollop::die "rooms not recognized" unless rl = b.get_rooms(opts[:rooms])
Trollop::die(:add, "must select a room") if opts[:add_given] && rl.length == 0
Trollop::die("Players can only be added to one room") if opts[:add_given] && rl.length > 1

for transfer in opts[:transfer]
	b.transfer(transfer[0], transfer[1..-1])
end

for vote in opts[:vote]
	b.vote(vote[0], vote[1], false)
end
for vote in opts[:lock_vote]
	b.vote(vote[0], vote[1], true)
end

for name in opts[:lock].flatten
	b.lock(name)
end
for name in opts[:unlock].flatten
	b.unlock(name)
end
for name in opts[:remove].flatten
	b.remove(name)
end
for name in opts[:add].flatten
	b.add_player(name, rl[0])
end

b.change_round(opts[:round]) if opts[:round_given]

b.scan(!opts[:quiet], true, rl) if opts[:scan]
b.scan(!opts[:quiet], false, rl) if opts[:rescan]

b.tally(false, rl) if opts[:tally]
b.tally(true, rl) if opts[:force_tally]

if opts[:show_votes]
	for rid in rl
		room = Room.new(rid)
		puts room.tally
	end
end

b.appoint(opts[:appoint]) if opts[:appoint_given]

b.post(rl) if opts[:post]

if opts[:list_rooms]
	for room in b.all_rooms.collect{|rid| Room.new(rid)}
		puts "#{room.name}: #{room.players.collect{|ind| $pl[ind].name}.sort_by{|name| name.upcase}.join(", ")}"
	end
end

if opts[:show_orders]
	# for room in b.rooms[b.roundnum]
		# puts "#{room.name}"
		# for player in room.players
			# next unless room.to_send[player] && room.to_send[player].last
			# puts "   #{$pl[player].name}: #{room.to_send[player].last.collect{|pid| $pl[pid].name}.join{", "}}"
		# end
	# end
end

b.print_status if opts[:status]

close_connections
