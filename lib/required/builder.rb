class Genea
class Builder

  RANG_DEFAUT = 3
  COLO_DEFAUT = 4

  STARTING_POINT = {rang: 4, col: 4}
  # Pour conserver les mesures maximums (inauguré pour pouvoir 
  # placer la légende qui indique l'année de l'arbre)
  MAX_MESURES = {left: 10_000, right: 0, top: 0}

  COL_GUTTER    = 20
  COL_WIDTH     = 200  # Si changé, mettre div.people width à COL_WIDTH - COL_GUTTER
  COL_FULL = COL_WIDTH + COL_GUTTER
  RANG_GUTTER   = 65
  RANG_HEIGHT   = 100 # Si changé, 
  RANG_FULL     = RANG_HEIGHT + RANG_GUTTER
  CHILDREN_LINK_HEIGHT = 20

  BLOCK_LEGEND = '<legend class="main" style="top:%ipx;left:%spx;">Arbre généalogique %s</legend>'.freeze

class << self


  ##
  # Point d'entrée pour construire l'arbre généalogique
  # 
  # @params {Hash} params Paramètres pour la construction
  #   :annee_reference] Année de référence. Par défaut, l'année cou-
  #                     rante. Permet de produire l'arbre à une autre
  #                     date que l'année courante.
  def build(params = {})
    # On définit l'année de référence
    unless defined?(ANNEE_REF)
      Genea::Builder.const_set('ANNEE_REF', params[:annee_reference])
    end
    # On récupère les données
    data = Data.get
    # puts "data: #{data.inspect}"

    main_person = 
    if Data.main_person
      Data.main_person
    else
      puts "Il faut définir la personne principale (en mettant sa propriété `main' à true). Par défaut, je prends la première.".orange
      Data.persons.values.first
    end

    main_person.rang  = STARTING_POINT[:rang]
    main_person.col   = STARTING_POINT[:col]

    avant, apres = 
      IO.read(modele_path)
      .sub(/<body>.+<\/body>/m, '<body>$$$</body>')
      .split('$$$')

    code = []

    Genea::Person.reset
    Genea::Person.put(main_person)
    while (person = Genea::Person.shift)
      puts "Traitement de #{person.patronyme}".jaune
      person.add_to_arbre(code)
      if person.pere && person.pere.unbuilt?
        Genea::Person.put(person.pere)
      end
      if person.mere && person.mere.unbuilt
        Genea::Person.put(person.mere)
      end
      if person.is_mari? && person.femme && person.femme.unbuilt?
        Genea::Person.put(person.femme)
      elsif person.is_femme? && person.mari && person.mari.unbuilt?
        Genea::Person.put(person.mari)
      end
      if person.has_children?
        Genea::Person.put(person.sorted_children)
      end
    end

    # La légende avec l'année, sous la table
    code << build_legende

    File.write(path, avant + code.join("\n") + apres)

  end

  # Pour conserver la trace des valeurs maximale et minimale
  # (utile pour placer la légende sous l'arbre)
  def set_max(prop, value, ref = :greater)
    case ref
    when :greater
      MAX_MESURES.store(prop, value) if MAX_MESURES[prop] < value
    when :smaller
      MAX_MESURES.store(prop, value) if MAX_MESURES[prop] > value
    end
  end

  # Construction de la légende
  def build_legende
    left = MAX_MESURES[:left] + (MAX_MESURES[:right] - MAX_MESURES[:left]) / 2 - 100
    ar = "ANNÉE #{ANNEE_REF}"
    ar = "<strong>#{ar}</strong>" if ar != Time.now
    BLOCK_LEGEND % [MAX_MESURES[:top], left, ar]
  end

  # Construction du bloc de personne
  def build_person_bloc(person)
    class_css = ['people']
    class_css << 'ghost' if person.not_borned?
    <<~HTML
      <div class="#{class_css.join(' ')}" style="top:#{person.top}px;left:#{person.left}px;">
        <div class="name">#{person.f_patronyme}</div>
        <div class="dates">#{person.f_mark_dates}</div>
      </div>
      #{person.block_link}
    HTML
  rescue Exception => e
    puts "ERREUR SURVENUE AVEC #{person} : #{e.message}".rouge
  end

  # Construction du bloc de liaison entre mari et femme
  TEMP_LINK_EPOUX = '<div class="hlink%s" style="top:%spx;left:%spx;width:%spx;"><span class="annee">%s</span></div>'.freeze
  
  def build_epoux_link(mari)
    ghosted = mari.not_maried_yet? ? ' ghost' : ''
    TEMP_LINK_EPOUX % [
      ghosted, 
      mari.top + RANG_HEIGHT, 
      mari.left + COL_WIDTH/2, 
      COL_WIDTH - COL_GUTTER,
      mari.annee_mariage || ""
    ]
  end

  TRAIT_TEMP = '<div class="trait%s" style="top:%spx;left:%spx;height:%spx;width:%spx;"></div>'.freeze

  # Construction des traits si enfant
  # 1. Il y a un trait vertical entre les parents (todo: traiter l'adoption)
  # 2. Il y a un train horizontal pour accrocher les enfants (à définir suivant les enfants)
  # 3. Il y a autant de trait verticaux qu'il faut entre les enfants et le trait horizontal
  def build_children_links(mari)
    enfants = mari.sorted_children
    ecount  = enfants.count
    one_is_born = false
    enfants.each do |p| 
      one_is_born = true unless p.not_borned?
    end
    ghosted = one_is_born ? '' : ' ghost'

    traits  = []
    # Trait 1
    top     = mari.top + RANG_HEIGHT + 25
    left    = mari.left + COL_WIDTH - COL_GUTTER / 2
    height  = CHILDREN_LINK_HEIGHT
    traits << TRAIT_TEMP % [ghosted, top, left, height, 'auto']
    # Le Trait 2 (sauf si un seul enfant)
    top   = top + height
    if ecount > 1
      width = (ecount * 2 - 2) * COL_FULL #- COL_GUTTER
      left  = enfants[0].left + COL_WIDTH / 2
      traits << TRAIT_TEMP % [ghosted, top, left, 'auto', width]
    end
    # Les Traits 3
    top += 2 if ecount > 1
    height = CHILDREN_LINK_HEIGHT
    enfants.each do |p|
      traits << TRAIT_TEMP % [ghosted, top, left, height + 4, 'auto']
      left += COL_WIDTH * 2
    end
    return traits
  end

  def path
    @path ||= File.join(EXPORT_FOLDER, "arbre-#{Genea::Data.fbase}.html")
  end
  def modele_path
    @modele_path ||= File.join(EXPORT_FOLDER, 'assets', 'base.html')
  end

end #/class << self
end 
end