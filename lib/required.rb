require 'clir'
require 'yaml'

class Genea; end
Dir["#{__dir__}/required/*.rb"].each{|m|require(m)}