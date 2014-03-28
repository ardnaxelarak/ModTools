#!/usr/bin/ruby

require 'trollop'
require_relative "Bot2r1b"

opts = Trollop::options do
	banner "Usage:
	#{__FILE__} [options]\n\nwhere common options are:"
	opt :file, "File to use", :required => :true, :type => :string
	opt :create, "Create a new game"
	opt :next_round, "Initialize next round"
	opt :quiet, "Quiet mode"
	opt :post, "Make a post"
	opt :rooms, "Set rooms", :type => :strings
	opt :status, "Display current game status"
	opt :show_votes, "Display current votes"
	opt :appoint, "Appoint a player leader of their room", :type => :string
	opt :help, "Show this message", :short => "h"
	banner "\nand options that have mostly become unnecessary are:"
	opt :scan, "Scan the rooms", :short => "s"
	opt :rescan, "Reset vote counts and rescan", :short => "S"
	opt :tally, "Post vote tallies", :short => "t"
	opt :force_tally, "Force a posting of a vote tally", :short => "T"
	opt :vote, "Vote for a player", :type => :strings, :multi => true, :short => "v"
	opt :lock_vote, "Locked vote for a player", :type => :strings, :multi => true, :short => "V"
	opt :transfer, "Transfer a player", :type => :strings, :multi => true
	opt :lock, "Lock a player's vote", :type => :strings, :multi => true
	opt :unlock, "Unlock a player's vote", :type => :strings, :multi => true
	opt :round, "Set the current round", :type => :int
end

for vote in opts[:vote]
	Trollop::die :vote, "needs exactly two players" if vote.length != 2
end
for vote in opts[:lock_vote]
	Trollop::die :lock_vote, "needs exactly two players" if vote.length != 2
end

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__

if (File.exist?(opts[:file]))
	Trollop::die("file already exists") if (opts[:create_given])
	b = YAML::load(File.read(opts[:file]))
	Trollop::die("file does not contain a 2R1B bot") unless b.class == Bot2r1b
else
	Trollop::die("file does not exist") unless (opts[:create_given])
	b = Bot2r1b.new(filename)
end

begin
	@@pl = PlayerList.new(File.expand_path("../players", THIS_FILE))
rescue
	Trollop::die("cannot open players file")
end
@@wi = Interface.new(File.expand_path("../default_auth", THIS_FILE))
@@wi.verbose = !opts[:quiet]

b.update

if opts[:create]
	2.times do
		b.new_room
	end
end

b.next_round if opts[:next_round]

Trollop::die "invalid round number" if opts[:round_given] && !b.rooms[opts[:round]]

Trollop::die "rooms not recognized" unless rl = b.get_rooms(opts[:rooms])

b.transfer(opts[:transfer][0], opts[:transfer][1..-1]) if opts[:transfer_given]

b.vote(opts[:vote][0], opts[:vote][1], false) if opts[:vote_given]
b.vote(opts[:lock_vote][0], opts[:lock_vote][1], true) if opts[:lock_vote_given]

for name in opts[:lock].flatten
	b.lock(name)
end
for name in opts[:unlock].flatten
	b.unlock(name)
end

b.change_round(opts[:round]) if opts[:round_given]

b.scan(!opts[:quiet], true, rl) if opts[:scan]
b.scan(!opts[:quiet], false, rl) if opts[:rescan]

b.tally(false, rl) if opts[:tally]
b.tally(true, rl) if opts[:force_tally]

if opts[:show_votes]
	for room in rl
		puts room.tally(@@pl)
	end
end

b.appoint(opts[:appoint]) if opts[:appoint_given]

b.post(rl) if opts[:post]

if opts[:list_rooms]
	for room in b.rooms[b.roundnum]
		puts "#{room.name}: #{room.players.collect{|ind| @@pl[ind].name}.sort_by{|name| name.upcase}.join(", ")}"
	end
end

b.print_status if opts[:status]
