require 'mechanize'

class Interface
	def initialize
		@agent = Mechanize.new
		login
	end

	def show_message(message)
		len = message.length
		print message
		yield
		print "\b" * len + " " * len + "\b" * len
	end

	def post(thread, content)
		page = @agent.get("http://boardgamegeek.com/thread/#{thread}")
		page = @agent.click("Reply")
		form = page.form_with(:name => "MESSAGEFORM")
		form.body = content
		show_message("Submitting post...") do
			page = @agent.submit(form, form.button_with(:value => 'Submit'))
		end
		times = 0
		while page.body.include?("You have posted too many items in too short a time--please wait a minute before posting again.") && times < 3
			show_message("Too many posts in too short a time -- waiting one minute...") do
				sleep 60
			end
			show_message("Retrying...") do
				page = @agent.submit(form, form.button_with(:value => 'Submit'))
			end
		end
	end

	def login(username = 'modkiwi', password = 'modkiwi157')
		show_message("Logging into BGG...") do
			@agent.post("http://boardgamegeek.com/login", {"username" => username, "password" => password})
		end
	end

	def get_posts(id, start = nil)
		start = 0 unless start
		page = @agent.get("http://boardgamegeek.com/thread/#{id}")
		posts = []
		loop do
			ng = page.parser
			list = ng.css('div[class="js-rollable article "]')
			for item in list
				articleid = item.get_attribute('data-objectid').to_i
				next if articleid <= start
				username = item.css('div[class="username"]').text[1...-1]
				bolds = item.css('dd[class="right"] b').select{|b| b.parent.get_attribute(:class) != "quote"}.collect{|b| b.text}
				posts.push([username, articleid, bolds])
			end
			if page.links_with(:text => "Next »").length > 0
				page = page.link_with(:text => "Next »").click
			else
				break
			end
		end
		posts
		# list
	end

	def stop
		@agent.shutdown()
	end
end
