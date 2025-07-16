class Genea::LastAction
class << self

  def save(action: nil, fiche: nil, annee: nil, options: {})
    return if Genea.same_command?
    @action   = action unless action.nil?
    @fiche    = fiche  unless fiche. nil?
    @annee    = annee  unless annee.nil?
    @options  = options unless options.empty?
    command = []
    command << @action
    command << @options.map{|o|"-#{o}"}.join(' ') unless @options.nil?
    command << "fg=#{@fiche}" unless @fiche.nil?
    command << "ar=#{@annee}" unless @annee.nil?
    command = command.compact.join(' ')
    # puts "Commande mémorisée : #{command.inspect}"
    File.write(path, Marshal.dump(command))
  end

  def load
    if File.exist?(path)
      CLI.parse(Marshal.load(IO.read(path)))
    end
  end

  def path
    @path_last_action ||= File.join(Genea::APP_FOLDER, '.LASTACTION')
  end

end #/class << self
end #/class Genea::LastAction