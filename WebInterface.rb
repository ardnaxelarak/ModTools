#!/usr/bin/ruby
# encoding: utf-8

require 'mechanize'

class Interface
	attr_accessor :agent, :logged_in
	def initialize(filename = nil)
		@agent = Mechanize.new
		@logged_in = false
		login_from_file(filename) if filename
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
		return false unless form
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
			times += 1
		end
		return times < 3
	end

	def send_geekmail(user, subject, content)
		page = @agent.post("http://boardgamegeek.com/geekmail_controller.php", {"B1" => "Send", "action" => "save", "body" => content, "savecopy" => "1", "subject" => subject, "touser" => user})
		times = 0
		while page.body.include?("You have sent too many messages in too short a time--please wait before sending your next message.") && times < 3
			show_message("Too many messages in too short a time -- waiting one minute...") do
				sleep 60
			end
			show_message("Retrying...") do
				page = @agent.post("http://boardgamegeek.com/geekmail_controller.php", {"B1" => "Send", "action" => "save", "body" => content, "savecopy" => "1", "subject" => subject, "touser" => user})
			end
			times += 1
		end
		puts "gave up" if times >= 3
	end

	def login(username, password)
		show_message("Logging into BGG...") do
			page = @agent.post("http://boardgamegeek.com/login", {"username" => username, "password" => password})
			@logged_in = !page.body.include?("Invalid Username/Password")
		end
		return @logged_in
	end

	def login_from_file(filename)
		f = File.open(filename)
		username = f.lines.next.chomp
		password = f.lines.next.chomp
		login(username, password)
	end

	def get_geekmail(id)
		page = @agent.post("http://boardgamegeek.com/geekmail_controller.php", {"action" => "getmessage", "messageid" => id.to_s})
		item = page.parser.css('div[class="gm_subject"]')[0].parent
		bolds = item.css('b').select{|b| b.parent.get_attribute(:class) != "quote" && b.parent.get_attribute(:class) != "gm_subject"}.collect{|b| b.text}
	end

	def geekmail_list
		pagenum = 1
		messages = []
		page = @agent.post("http://boardgamegeek.com/geekmail_controller.php", {"action" => "viewfolder", "folder" => "inbox", "pageID" => pagenum.to_s})
		items = page.parser.css('table[class="gm_messages"]')
		while (items.length > 0)
			for item in items
				read = (item.css('input[name="msgread[]"]')[0].get_attribute(:value) == "1")
				messageid = item.css('input[name="messagelist[]"]')[0].get_attribute(:value).to_i
				from = item.css('td[class="gm_prefix"] a')[0].text
				list = item.css('div').select{|div| div.get_attribute(:class) && div.get_attribute(:class).start_with?("js-rollable article")}
				subject = item.css('td[style="gm_messageline"] a[style]')[0].text
				messages.push({:read => read, :id => messageid, :from => from, :subject => subject})
			end

			pagenum += 1
			page = @agent.post("http://boardgamegeek.com/geekmail_controller.php", {"action" => "viewfolder", "folder" => "inbox", "pageID" => pagenum.to_s})
			items = page.parser.css('table[class="gm_messages"]')
		end
		return messages.uniq
	end

	def mail_since(mid = nil)
		list = geekmail_list
		# list.select!{|item| !item[:read]}
		list.select!{|item| item[:id].to_i > mid.to_i}
		list.reverse!
		return list.collect{|item| item.merge(:body => get_geekmail(item[:id]))}
	end

	def get_posts(id, start = nil)
		start = 0 unless start
		page = @agent.get("http://boardgamegeek.com/thread/#{id}")
		posts = []
		loop do
			ng = page.parser
			list = ng.css('div').select{|div| div.get_attribute(:class) && div.get_attribute(:class).start_with?("js-rollable article")}
			for item in list
				articleid = item.get_attribute('data-objectid').to_i
				next if articleid.to_i <= start.to_i
				username = item.css('div[class="username"]').text[1...-1]
				bolds = item.css('dd[class="right"] b').select{|b| b.parent.get_attribute(:class) != "quote"}.collect{|b| b.to_html}
				posts.push({:user => username, :id => articleid, :posts => bolds})
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
