require_relative "Player"
require_relative "Vote"

class Room
	attr_accessor :players, :name, :thread, :last_tally, :leader, :locked, :last_article, :to_send

	def initialize(name, thread, players, leader = nil)
		@name = name
		@thread = thread
		@players = players
		@votes_for = {}
		@votes_from = {}
		@to_send = {}
		@index = 0
		@last_tally = 0
		@leader = leader
		@last_leader = leader
		@changes = false
		@locked = []
		@last_article = nil
		for player in @players
			@votes_for[player] = []
			@votes_from[player] = []
			@to_send[player] = []
		end
	end

	def next_round(thread, players = @players)
		return Room.new(@name, thread, players, leader)
	end

	def add_player(pid)
		return if @players.include?(pid)
		@players.push(pid)
		@votes_for[pid] = []
		@votes_from[i] = []
	end

	def remove_player(pid)
		@players -= [pid]
	end

	def contain?(player)
		@players.include?(player)
	end

	def need_tally?
		return @changes || ((@last_tally < @index) && (@leader == @last_leader))
	end

	def leader_name(pl)
		return "None" unless @leader
		return pl[@leader].name
	end

	def tally(pl, update = false)
		if update
			@last_tally = @index
			@last_leader = @leader
			@changes = false
		end
		text = ""
		text << "[b][color=purple]#{pl[@leader].name} has become leader![/color][/b]\n\n" if @last_leader != @leader
		text << "[color=#009900]Current Leader: #{leader_name(pl)}"
		text << "\n\nVOTE TALLY:"
		
		plist = players.sort_by {|p| count(p) * 1000 - last(p)}
		for p in plist.reverse
			next if @votes_for[p].length == 0
			text << "\n#{pl[p].name} - #{count(p)} - #{@votes_for[p].collect {|vote| vote_desc(pl, vote)}.join(", ")}"
		end

		nv = players.select{|p| @votes_from[p].length == 0}.sort_by{|p| pl[p].name.upcase}.collect{|p| pl[p].name}
		text << "\n\nNot voting: #{nv.join(", ")}" if nv.length > 0
		text << "\n\n'*' indicates a locked vote."

		text << "[/color]"
	end

	def count(votee)
		count = 0
		for vote in @votes_for[votee]
			count += 1 if current_vote?(vote)
		end
		return count
	end

	def last(votee)
		for vote in @votes_for[votee].reverse
			return vote.order if current_vote?(vote)
		end
		return -1
	end

	def vote(voter, votee, locked = false)
		v = Vote.new(votee, voter, @index)
		@votes_from[voter].push(v)
		@votes_for[votee].push(v)
		@index = @index + 1
		@locked[votee] = locked
		update_leader(votee) if count(votee) > (players.length / 2)
	end

	def add_transfer(sender, sent)
		@to_send[sender] = [] unless @to_send[sender]
		@to_send[sender].push(sent)
	end

	def get_transfer
		return nil unless @leader
		return nil unless @to_send[@leader]
		return @to_send[@leader].last
	end

	def update_leader(newleader)
		@leader = newleader
		@changes = true
	end

	def lock(votee)
		@locked[votee] = true
		@changes = true
	end

	def unlock(votee)
		@locked[votee] = false
		@changes = true
	end

	def current_vote?(vote)
		return vote == @votes_from[vote.voter].last
	end

	def locked_vote?(vote)
		return false unless current_vote?(vote)
		return @locked[vote.votee]
	end

	def vote_desc(pl, vote, old_prefix = "[-]", old_suffix = "[/-]", locked_ind = "*")
		text = pl[vote.voter].name
		text += locked_ind if locked_vote?(vote)
		text += "(#{vote.order + 1})"
		text = old_prefix + text + old_suffix unless current_vote?(vote) 
		return text
	end
end
