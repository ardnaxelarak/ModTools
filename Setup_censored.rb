require_relative 'WebInterface'
require_relative 'PlayerList'
require_relative 'BaseFunctions'
require 'mysql'

$conn = Mysql.new("localhost", "ruby_user", "xxx", "modbot_data")
$pl = PlayerList.new($conn)
$wi = Interface.new($conn)
