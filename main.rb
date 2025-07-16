

begin
  # Dossier dans lequel a été appelée la commande
  # Ne sert à rien pour le moment
  CUR_FOLDER = ARGV.shift
  require_relative 'lib/required'
  Genea.run
rescue TTY::Reader::InputInterrupt => e
  clear
  puts "Bye bye".bleu
rescue Exception => e
  puts e.message.rouge
  puts e.backtrace.join("\n").rouge
end