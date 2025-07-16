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

  # Permet de demander de choisir une fiche
  # 
  # ATTENTION ! Doit absolument retourner la table des personnes
  # 
  def ask_and_load_fiche
    choices = 
    Dir["#{Genea::FICHES_FOLDER}/*.yaml"].map do |path|
      fname = File.basename(path, File.extname(path))
      {name: fname.gsub(/_/, ' '), value: fname}
    end + [
      {name: "Autre fiche…", value: nil}
    ]
    case choix = Q.select("Quelle fiche ?".jaune, choices, per_page: choices.count, cycle: true)
    when NilClass
      load Q.ask("Chemin d'accès à la fiche : ".jaune)
    else choix
      load(choix)
    end
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
    # puts "@main_person dans data : #{@main_person}"

    return @persons
  end

  # @return la "main" personne, c'est-à-dire la personne de laquelle 
  # on commence l'arbre (ça peut influencer son apparence)
  # Soit on détermine expliciement qui elle est en lui mettant une
  # propriété :main à True, soit on prend la plus vieille.
  def get_main_person
    if main_person
      main_person
    else
      persons.values.sort_by { |p| p.naissance || 0 }.shift
    end
  end

  # Nom du fichier de généalogie
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
    @path ||= begin
      ask_and_load_fiche
      @path # un peu tordu, mais bon…
    end
  end
end #/class << self
end #/Gena::Data