require_relative "Player"
require_relative "Vote"
require_relative "Setup"

class Room
	attr_accessor :players, :name, :thread, :last_tally, :leader, :locked, :last_article, :to_send, :added, :removed, :offered_to, :accepted, :weight

	def initialize(name, thread, players, leader = nil)
		@name = name
		@thread = thread
		@players = players
		@votes_for = {}
		@votes_from = {}
		@to_send = {}
		@offered_to = {}
		@accepted = {}
		@weight = {}
		@index = 0
		@last_tally = 0
		@leader = leader
		@last_leader = leader
		@changes = false
		@added = []
		@removed = []
		@locked = []
		@last_article = nil
		for player in @players
			@votes_for[player] = []
			@votes_from[player] = []
			@to_send[player] = []
			@weight[player] = 1
		end
	end

	def offer_player(pid1, pid2)
		@offered_to[pid1] = pid2 unless @accepted[pid1]
	end

	def accept_offer(pid2, pid1)
		return nil unless @offered_to[pid1] == pid2
		@offered_to[pid1] = nil
		if @leader == pid1
			update_leader(pid2)
		else
			@accepted[pid1] = pid2
		end
		return true
	end

	def revoke_offer(pid1)
		@offered_to[pid1] = nil
		@accepted[pid1] = nil
	end

	def total_votes
		@weight.collect!{|item| item ? item : 1}
		return @players.collect{|pid| @weight[pid]}.reduce(0, :+)
	end

	def clear_votes
		for player in @players
			@votes_for[player] = []
			@votes_from[player] = []
		end
		@index = 0
	end

	def next_round(thread, players = @players)
		return Room.new(@name, thread, players, leader)
	end

	def add_player(pid)
		return if @players.include?(pid)
		@players.push(pid)
		@votes_for[pid] = []
		@votes_from[pid] = []
		@added.push(pid)
		@changes = true
	end

	def remove_player(pid)
		@players -= [pid]
		@removed.push(pid)
		@changes = true
		recalc
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

	def tally(update = false)
		text = ""
		for pid in @added
			text << "[b][color=purple]#{$pl[pid].name} has joined the room![/color][/b]\n"
		end
		for pid in @removed
			text << "[b][color=purple]#{$pl[pid].name} has been removed![/color][/b]\n"
		end
		text << "[b][color=purple]#{$pl[@leader].name} has become leader![/color][/b]\n" if @last_leader != @leader
		text << "\n" unless text == ""
		text << "[color=#009900]Current Leader: #{leader_name(pl)}"
		text << "\n\nVOTE TALLY:"
		
		plist = players.sort_by {|p| count(p) * 1000 - last(p)}
		for p in plist.reverse
			next if @votes_for[p].length == 0
			text << "\n#{$pl[p].name} - #{count(p)} - #{@votes_for[p].collect {|vote| vote_desc(vote)}.join(", ")}"
		end

		nv = players.select{|p| @votes_from[p].length == 0}.sort_by{|p| $pl[p].name.upcase}.collect{|p| $pl[p].name}
		text << "\n\nNot voting: #{nv.join(", ")}" if nv.length > 0
		text << "\n\n'*' indicates a locked vote."

		text << "[/color]"
		if update
			@last_tally = @index
			@last_leader = @leader
			@changes = false
			@added = []
			@removed = []
		end
		return text
	end

	def choose_leader
		plist = players.sort_by {|p| count(p) * 1000 - last(p)}.reverse
		update_leader(plist.first)
		@leader
	end

	def count(votee)
		count = 0
		for vote in @votes_for[votee]
			@weight[vote.voter] = 1 unless @weight[vote.voter]
			count += @weight[vote.voter] if current_vote?(vote)
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
		@locked[voter] = locked
		recalc
	end

	def recalc
		for votee in @players
			update_leader(votee) if count(votee) > (players.length / 2)
		end
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
		@leader = @accepted[newleader] if @accepted[newleader]
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
		return (vote == @votes_from[vote.voter].last) && @players.include?(vote.voter)
	end

	def locked_vote?(vote)
		return false unless current_vote?(vote)
		return @locked[vote.voter]
	end

	def vote_desc(vote, old_prefix = "[-]", old_suffix = "[/-]", locked_ind = "*")
		text = $pl[vote.voter].name
		text += locked_ind if locked_vote?(vote)
		text += "(#{vote.order + 1})"
		text = old_prefix + text + old_suffix unless current_vote?(vote) 
		return text
	end
end
