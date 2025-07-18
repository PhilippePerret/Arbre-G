class Genea
class Builder

  RANG_DEFAUT = 3
  COLO_DEFAUT = 4

  STARTING_POINT = {rang: 4, col: 4}
  # Pour conserver les mesures maximums (inauguré pour pouvoir 
  # placer la légende qui indique l'année de l'arbre)
  MAX_MESURES = {left: 10_000, right: 0, top: 10_000, bottom: 0}

  COL_GUTTER    = 20
  COL_WIDTH     = 200  # Si changé, mettre div.people width à COL_WIDTH - COL_GUTTER
  COL_FULL = COL_WIDTH + COL_GUTTER
  RANG_GUTTER   = 65
  RANG_HEIGHT   = 100 # Si changé, 
  RANG_FULL     = RANG_HEIGHT + RANG_GUTTER
  CHILDREN_LINK_HEIGHT  = 20
  DEMI_TRAIT_V          = 23
  CHILD_LINK_SHRIKNESS = 2

  BLOCK_LEGEND = '<legend class="main" style="top:%ipx;left:%spx;">Arbre généalogique %s</legend>'.freeze

class << self

  # Pour enregistrer le détail de la construction
  def log(str)
    reflog.puts(str)
  end
  def reflog
    @reflog ||= begin
      File.delete(pathlog) if File.exist?(pathlog)
      File.open(pathlog, 'a')
    end
  end
  def pathlog
    @pathlog ||= File.join(Genea::TMP_FOLDER, 'logs','building.log')
  end

  ##
  # Point d'entrée pour construire l'arbre généalogique
  # 
  # @params {Hash} params Paramètres pour la construction
  #   :annee_reference] Année de référence. Par défaut, l'année cou-
  #                     rante. Permet de produire l'arbre à une autre
  #                     date que l'année courante.
  def build(params = {})

    Genea::LastAction.save(action: 'build')

    # On définit l'année de référence
    unless defined?(ANNEE_REF)
      Genea::Builder.const_set('ANNEE_REF', Genea::Data.annee_reference)
    end

    # On récupère les données des personnes
    data =
      if Genea::Data.fiche_genealogie
        Data.load(Genea::Data.fiche_genealogie)
      else
        Data.get
      end

    # On charge les données couleur
    Genea::Color.load

    # On réinitialise les personnes
    Genea::Person.reset

    main_person = Data.get_main_person
    if main_person.nil?
      # <= Personne n'a de date
      # => J'essaie en mettant tout le monde dans la liste
      Genea::Person.put(Data.persons.values)
      # Il faut définir le rang de la première (mais en fait, 
      # il faudrait définir le rang de tous ceux qui ne dépendent
      # de personne, en fonction de ceux déjà construit)
      premier = Data.persons.values.first
      premier.rang = STARTING_POINT[:rang]
      premier.col  = STARTING_POINT[:col]
    else
      main_person.rang  = STARTING_POINT[:rang]
      main_person.col   = STARTING_POINT[:col]
      Genea::Person.put(main_person)
      # puts "main_person est #{main_person}"
    end

    avant, apres = 
      IO.read(modele_path)
      .sub(/<body>.+<\/body>/m, '<body>$$$</body>')
      .split('$$$')

    code = []

    while (person = Genea::Person.shift)
      next if person.built?
      log "Traitement de #{person.patronyme}"
      person.add_to_arbre(code) || begin
        # Si on n'a pas pu ajouter la personne à l'arbre, on la
        # remet en espérant que ça passera mieux ensuite. Mais 
        # seulement si on n'a pas déjà essayé
        log "IMPOSSIBLE DE PLACER #{person}"
        unless person.retry_building
          Genea::Person.put(person)
          person.retry_building = true
          log "#{person} replacé dans la boucle"
        else
          log "FATAL: Traitement de #{person} abandonné."
        end
        next
      end
      log "#{person.patronyme} : rang=#{person.rang.inspect} col=#{person.col.inspect} | top=#{person.top.inspect} | left=#{person.left.inspect}"
      if person.pere && person.pere.unbuilt?
        Genea::Person.put(person.pere)
      end
      if person.mere && person.mere.unbuilt?
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

    File.write(path, avant + block_repositionnement_in + code.join("\n") + '</div>' + apres)

    puts "🍺 Arbre généalogique construit avec succès.".vert
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

  # Construction du bloc de repositionnement (sa balise 
  # d'ouverture seulement <div ...>)
  # C'est un bloc qui vise à repositionner l'arbre dans la fenêtre
  # afin qu'il soit bien en haut à droite.
  BLOCK_REPO_TEMP = '<div id="bloc_repositionnement" style="top:%spx;left:%spx;">'
  def block_repositionnement_in
    top   = -MAX_MESURES[:top]
    left  = -MAX_MESURES[:left]
    BLOCK_REPO_TEMP % [top, left]
  end

  # Construction de la légende
  def build_legende
    left = MAX_MESURES[:left] + (MAX_MESURES[:right] - MAX_MESURES[:left]) / 2 - 100
    ar = "ANNÉE #{ANNEE_REF}"
    ar = "<strong>#{ar}</strong>" if ar != Time.now
    BLOCK_LEGEND % [MAX_MESURES[:bottom], left, ar]
  end

  # Construction du bloc de personne
  def build_person_bloc(person)
    class_css = ['people']
    class_css << 'ghost' if person.not_borned?
    <<~HTML
      <div class="#{class_css.join(' ')}" style="top:#{person.top}px;left:#{person.left}px;background-color:##{Genea::Color.get(person.couleur)||'white'};">
        #{div_image(person)}
        <div class="name">#{person.f_patronyme}</div>
        <div class="dates">#{person.f_mark_dates}</div>
      </div>
      #{person.block_link}
    HTML
  rescue Exception => e
    puts "ERREUR SURVENUE AVEC #{person} : #{e.message}".rouge
    puts e.backtrace.join("\n").rouge if Genea.debug?
  end

  TEMP_IMG_SEXE = '<img src="assets/images/%s.png" class="sexe" />'
  def div_image(person)
    return "" if person.sexe.nil?
    image = {'F' => 'venus', 'H' => 'mars', 'I' => 'venus-mars'}[person.sexe]
    TEMP_IMG_SEXE % [image]
  end

  # Construction du bloc de liaison entre mari et femme
  TEMP_LINK_EPOUX = '<div class="hlink%s" style="top:%spx;left:%spx;width:%spx;height:%spx;"><span class="annee">%s</span></div>'.freeze
  
  TEMP_DEMITRAIT_VERT_EPOUX = '<div class="trait%s" style="top:%spx;left:%spx;height:%spx;"></div>'.freeze
  
  def build_epoux_link(mari)
    ghosted = mari.not_maried_yet? ? ' ghost' : ''
    traits = []
    top_main    = mari.top + RANG_HEIGHT
    left_main   = mari.left + COL_WIDTH/2
    width_main  = COL_WIDTH - COL_GUTTER
    height_main = DEMI_TRAIT_V
    traits << TEMP_LINK_EPOUX % [
      ghosted, 
      top_main, 
      left_main, 
      width_main,
      height_main,
      mari.annee_mariage || ""
    ]
    # S'il y a des enfants, on ajoute le demi-trait descendant qui va
    # soit rejoindre la barre horizontale joignant tous les enfants, 
    # soit le trait vertical rejoignant l'enfant unique.
    # Si l'enfant unique n'est pas marié, il est mis au centre des
    # deux parent, sinon, il est mis sous le père si c'est le mari
    # (ou assimilé) ou sous la mère si c'est la femme (ou assimilée)
    if mari.has_children?
      enfant_unique = mari.enfants.count == 1
      top_sub = top_main + height_main
      # La longueur du trait, fonction du fait qu'il y a un seul 
      # enfant ou plusieurs
      height_sub = enfant_unique ? DEMI_TRAIT_V * 2 : DEMI_TRAIT_V ;
      # Le placement left du trait, en fonction de fils unique ou 
      # non et si fils unique si 1) non marié, 2) mari (ou assimilée) 
      # 3) femme (ou assimilée)
      left_sub = left_main + case true
        when enfant_unique 
          child = mari.enfants.first
          case true 
          when child.is_single? then width_main / 2
          when child.is_mari?   then 0
          when child.is_femme?  then width_main + 2
          else raise "Ce cas ne devrait jamais survenir."
          end
        else width_main / 2
        end
      traits << TEMP_DEMITRAIT_VERT_EPOUX % [
        ghosted, 
        top_sub,
        left_sub,
        height_sub
      ]
    end

    return traits.join('')
  end

  TRAIT_TEMP = '<div class="trait%s" style="top:%spx;left:%spx;height:%spx;width:%spx;"></div>'.freeze

  # Dessine et retourne le trait vertical supérieur pour un enfant
  # qui n'est pas unique (pour un enfant unique, le trait est déjà
  # dessiné)
  # TODO Quand on améliorera le programme, il faudra envoyer le parent
  # à ces méthodes pour placer l'enfant par rapport à lui et pas dans
  # l'absolu.
  def draw_vlink_child(person)
    ghosted = person.is_borned? ? '' : ' ghost'
    left = person.left + COL_WIDTH/2
    # La personne mémorise le left de sa liaison qui peut 
    # servir (notamment quand c'est le dernier)
    person.left_up_vlink = left
    top = person.top - CHILDREN_LINK_HEIGHT
    traits = []
    traits << TRAIT_TEMP % [
      ghosted,
      top,
      left,
      CHILDREN_LINK_HEIGHT,
      CHILD_LINK_SHRIKNESS
    ]
    if person.is_last_child?
      parent = (person.pere||person.mere)
      one_is_born = false
      parent.sorted_children.each do |p| # Ici un problème si c'est la mère…
        one_is_born = true unless p.not_borned?
      end
      ghosted = one_is_born ? '' : ' ghost'
      aine = parent.sorted_children.first
      aine_left  = aine.left_up_vlink
      width = left - aine_left
      traits << TRAIT_TEMP % [
        ghosted,
        top,
        aine_left,
        CHILD_LINK_SHRIKNESS,
        width
      ]
    end
    return traits.join('')
  end
  # Construction des traits si enfant
  # 1. Il y a un trait vertical entre les parents (todo: traiter l'adoption)
  # 2. Il y a un train horizontal pour accrocher les enfants (à définir suivant les enfants)
  # 3. Il y a autant de trait verticaux qu'il faut entre les enfants et le trait horizontal
  def build_children_links(mari)
    return ''
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