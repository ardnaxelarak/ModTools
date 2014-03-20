#!/usr/bin/ruby
# encoding: utf-8

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
end
