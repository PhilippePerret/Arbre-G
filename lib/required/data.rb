class Genea::Data
class << self

  # Table {Hash} avec en clé l'identifiant de la personne et en valeur son instance
  attr_reader :persons
  attr_reader :main_person

  def annee_reference
    @annee_reference ||= CLI.params[:ar] || CLI.params[:annee_reference] || Time.now.year
  end

  def fiche_genealogie
    @fiche_genealogie ||= CLI.params[:fg] || CLI.params[:fiche_genealogie]
  end

  # Charge la fiche généalogique de chemin d'accès +path+
  def load(path)
    path_ini = path.freeze
    path =
      if File.exist?(path)
        path
      else
        path = "#{path}.yaml" unless path.end_with?('.yaml')
        if File.exist?(path)
          path
        elsif File.exist?(path = File.join(Genea::FICHES_FOLDER, path))
          path
        else
          raise "💣 Impossible de trouver la fiche #{path_ini.inspect}"
        end
      end
    # Puisque la fiche généalogique existe, on la met en mémoire
    Genea::LastAction.save(fiche: path_ini)
    # Et on charge les données
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

  # Sauvegarde de toutes les données
  def save(persons: @persons, couleurs: Genea::Color::COLORS)
    content = {
      persons: persons,
      colors:  couleurs
    }
    File.write(path, YAML.dump(content))
  end

  # @return une liste des instances Genea::Personn entièrmenent 
  # préparée et vérifiée.
  def get
    @persons = {}
    YAML.safe_load(IO.read(path, **Genea::YAML_OPTIONS))['persons']
    .map do |pid, dperso|
      dperso.store('id', pid)
      Genea::Person.new(dperso).tap do |p| 
        @persons.store(p.id, p)
        @main_person = p if p.main?
      end
    end
    # .tap do |persos| 
    #   puts "PERSOS: #{persos.inspect}"
    #   puts "@persons : #{@persons.inspect}"
    #   raise "Pour voir"
    # end
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