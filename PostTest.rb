require 'mechanize'

class Poster
	def initialize
		@agent = Mechanize.new
	end

	def login(username = 'modkiwi', password = 'modkiwi157')
		@agent.post("http://boardgamegeek.com/login", {"username" => username, "password" => password})
	end

	def post_first(id, subject, body)
		params = {}
		params["action"] = "save"
		params["replytoid"] = id.to_s
		params["subject"] = subject
		params["body"] = body
		@agent.post("http://boardgamegeek.com/article/save", params)
	end

	def post_second(thread_id, body)
		page = @agent.get("http://boardgamegeek.com/thread/#{thread_id}")
		page = @agent.click("Reply")
		# page = page.link_with(:text => "Reply").click
		form = page.form_with(:name => "MESSAGEFORM")
		form.body = body
		page = @agent.submit(form, form.button_with(:value => "Submit"))
	end
end
