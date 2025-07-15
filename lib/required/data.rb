class Genea::Data
class << self

  # Table {Hash} avec en clé l'identifiant de la personne et en valeur son instance
  attr_reader :persons
  attr_reader :main_person

  # Charge la fiche généalogique de chemin d'accès +path+
  def load(path)
    path =
      if File.exist?(path)
        path
      else
        path = "#{path}.yaml" unless path.end_with?('.yaml')
        if File.exist?(path)
          path
        elsif File.exist?(path = File.join(Genea::FICHES_FOLDER, path))
          path
        end
      end
    self.path = path
    self.get
  end

  # @return une liste des instances Genea::Personn entièrmenent 
  # préparée et vérifiée.
  def get
    @persons = {}
    YAML.safe_load(IO.read(path, **Genea::YAML_OPTIONS))
    .map do |pid, pdata|
      pdata.store("id", pid)
      # puts  "pdata: #{pdata}"
      Genea::Person.new(pdata).tap do |p| 
        @persons.store(p.id, p)
        @main_person = p if p.main?
      end
    end
    .map do |person|
      # Si la personne définit des relatifs, on doit mettre cette
      # personne dans ses relatifs (et prévenir les erreurs)
      person.affect_relatives
    end
    puts "@main_person dans data : #{@main_person}"

    return @persons
  end

  def fname
    @fname ||= File.basename(path)
  end
  def fbase
    @fbase ||= File.basename(path, File.extname(path))
  end
  def path=(value)
    @path = value 
    @fname = nil
    @fbase = nil
  end
  def path
    # @path ||= File.join(Genea::FICHES_FOLDER, 'simple.yaml') # TODO Pouvoir la régler
    @path ||= File.join(Genea::FICHES_FOLDER, 'famille.yaml') # TODO Pouvoir la régler
  end
end #/class << self
end #/Gena::Data