

begin
  require_relative 'lib/required'
  Genea.run
rescue Exception => e
  puts e.message.rouge
  puts e.backtrace.join("\n").rouge
end