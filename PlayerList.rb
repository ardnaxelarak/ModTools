require_relative 'Player'

class PlayerList
	def initialize(filename)
		@players = []
		f = File.open(filename, "r")

		for line in f.each_line
			p = Player.new(line.chomp);
			@players[p.pid] = p
		end

		f.close
	end

	def [] (index)
		return @players[index]
	end

	def get_player(name, list = nil, verbose = true,
				   none_message = nil, many_message = nil)
		none_message = "%s: No match found\n" unless none_message
		many_message = "%s: Ambiguous - %s\n" unless many_message
		opt = match(name, list)
		if opt.length == 0
			printf(none_message, name) if verbose
			return nil
		elsif opt.length > 1
			printf(many_message, name, opt.collect{|val| @players[val].name}.join(", ")) if verbose
			return nil
		else
			return opt[0]
		end
	end

	def match(name, valid = nil)
		if valid
			plist = valid.collect{|ind| @players[ind]}
		else
			plist = @players
		end
		list = []
		max = 300000;
		for p in plist
			match = p.match(name)
			#puts match
			next if match < 0

			if match < max
				max = match;
				list = [p.pid]
			elsif match == max
				list.push(p.pid)
			end
		end

		return list
	end
end

if (__FILE__ == $0)
	pl = PlayerList.new("players")
	while (line = gets)
		line.chomp!
		puts pl.match(line)
	end
end
