class Vote
	attr_accessor :votee, :voter, :order

	def initialize(votee, voter, order)
		@votee = votee
		@voter = voter
		@order = order
	end
end
