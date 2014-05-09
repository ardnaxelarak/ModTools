class Player
	attr_reader :pid, :name, :votes, :alts
	MAX_CHECK = 5

	def initialize(pid, name, alts)
		@pid = pid
		@name = name
		@capname = @name.upcase
		@alts = alts

		@votes = []
	end

	def match(input)
		up = input.upcase
		return 0 if up == @capname

		for alt in @alts
			return 1 if up == alt
		end

		for i in (0...MAX_CHECK - 2)
			len = MAX_CHECK - i;
			next if len > up.length
			return 2 + 2 * i if up[0...len] == @capname[0...len]
			return 2 + 2 * i if up[-len..-1] == @capname[-len..-1]
			next if len < 4
			for alt in @alts
				return 3 + 2 * i if up[0...len] == alt[0...len]
				return 3 + 2 * i if up[-len..-1] == alt[-len..-1]
			end
		end

		return -1;
	end

	def vote_for(person, order)
		@votes.push(Vote.new(person, self, order))
		current_vote
	end

	def current_vote
		@votes.last
	end

	def to_s
		@name
	end
end
