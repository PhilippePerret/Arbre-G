class Genea::Person
  class << self

    def reset
      @all = []
      @all_as_table = {}
    end

    # Pour ajouter une personne aux personnes à ajouter dans l'arbre
    # généalogique. C'est lors de la construction que cette donnée
    # est utilisées
    # 
    # @param {Person|Array} person Une personne ou une liste de personnes
    def put(person)
      if person.is_a?(Array)
        person.each do |perso|
          add_in_all(perso) unless @all_as_table[perso.id]
        end
      else
        add_in_all(person) unless @all_as_table[person.id]
      end
      # puts "@all contient (#{@all.count}) #{@all.map{|p|p.patronyme}.pretty_join}"
    end

    def add_in_all(person)
      @all << person 
      @all_as_table.store(person.id, true)
    end

    # Prendre la première personne de toutes celles qu'il faut trai-
    # ter et la retirer pour la renvoyer.
    def shift 
      person = @all.shift || return
      @all_as_table.delete(person.id)
      return person
    end

    # @return la personnne ou Nil si elle n'existe pas
    def get(person_id)
      Genea::Data.persons[person_id]
    end

    def exists?(person_id)
      !Genea::Data.persons[person_id].nil?
    end

  end #/class << self


  attr_reader :data
  attr_accessor :rang, :col

  # Sera mis à true si on a essayé une première fois de construire la
  # personne mais que ça a échoué (on la remet dans la pile)
  attr_accessor :retry_building
  # Position left du trait vertical au-dessus de la boite de nom
  # lorsque la personne est un enfant
  # Défini par la méthode Genea::Builder@draw_vlink_child
  attr_accessor :left_up_vlink

  def initialize(data)
    @data     = data
  end

  def to_s
    "<<Person #{patronyme} indice:#{indice_enfant}>>"
  end

  def add_to_arbre(code)
    return if built?
    calc_position || return
    code << Genea::Builder.build_person_bloc(self)
    @is_built = true
    return true
  end

  def is_borned?
    !not_borned?
  end

  def not_borned?
    naissance && naissance > Genea::Builder::ANNEE_REF
  end

  # L'année de l'arbre généalogique, la personne n'est peut-être pas
  # encore marié
  def not_maried_yet?
    return false if conjoint.nil?
    not_borned? || conjoint.not_borned? || (annee_mariage && annee_mariage > Genea::Builder::ANNEE_REF) || (age && age < 12)
  end

  def built?
    @is_built === true
  end
  def unbuilt?
    @is_built != true
  end
  # Pour les tests
  def set_built(value = true)
    @is_built = value
  end

  # La marque des dates
  # -------------------
  # Date de naissance ou ?
  def f_mark_dates
    @f_mark_dates ||= begin
      mark_mort = 
        if mort.is_a?(Integer)
          if mort < Genea::Builder::ANNEE_REF
            mort.to_s
          else
            '   '
          end
        else 
          mort 
        end

      mark_naissance = naissance ? naissance.to_s : " ? "

      "#{mark_naissance} – #{mark_mort} #{mark_age}"
    end
  end

  def block_link
      @block_link ||= begin
      elements = []

      if is_mari?
        elements << Genea::Builder.build_epoux_link(self)
      end

      if (pere || mere) 
        # Si la personne a un père ou une mère, il faut lui mettre
        # dans tous les cas le trait vertical de liaison, sauf s'il
        # est enfant unique ?
        elements << Genea::Builder.draw_vlink_child(self) if has_sibling?
        # && indice_enfant == 0
        # elements << Genea::Builder.build_children_links(pere || mere)
      end

      elements.flatten.compact.join('')
    end
  end

  # Calcul de la position de la personne en fonction de sa filiation
  # avec les personnes déjà inscrites dans l'arbre.
  # 
  # Principes adoptés
  # -----------------
  #   La "grille" est composée de RANGs et de COLs (colonnes).
  #   - Une femme (ou conjoint) se met toujours à droite de son mari
  #     et sur le même rang
  #   - Un mari (ou coinjoint) se met toujours à gauche de sa femme
  #     et sur le même rang
  #   - Si c'est un enfant, il doit se mettre sous son père ou sa 
  #     mère (rang + 1)
  #   - S'il est enfant unique et seulement du père ou seulement de
  #     la mère, il se met juste en dessous.
  #   - Quand il appartient à une fratrie, on les répartit en dessous
  #     en laissant la place pour les conjoints (du bout côté en 
  #     fonction du sexe)
  #   
  def calc_position
    return true if col && rang
    if is_femme? && mari.built?
      @rang = mari.rang
      @col  = mari.col + 1
    elsif is_mari? && femme.built?
      @rang = femme.rang
      @col  = femme.col - 1
    elsif pere && pere.built?
      # Si la personne a un père
      # puts "-> père et père construit"
      @rang = pere.rang + 1
      if has_sibling?
        # Ce n'est pas un enfant unique. On le place en fonction
        # de son rang dans la fratrie et le nombre de frères et
        # de sœurs
        @col  = pere.col - siblings.count.to_f/2 + indice_enfant * 2
        # Si c'est la femme (ou assimilé) du couple, il faut la 
        # pousser à droite
        @col += 1 if has_conjoint? && is_femme?
      elsif mere && mere == pere.femme
        # Enfant unique du père et de la mère ou si les configuration
        # indiquent qu'il faut toujours mettre l'enfant unique au
        # centre
        # puts "-> mère et mère du père"
        if is_single? || Genea::CONFIG[:uniq_child_always_between]
          @col = pere.col + 0.5
        elsif is_mari?
          @col = pere.col
        elsif is_femme?
          # puts "-> est femme (mere.col = #{mere.col.inspect})"
          @col = mere.col
        else
          raise "Ce cas-là ne devrait jamais arriver"
        end
      else
        # Enfant unique seulement enfant du père
        @col = pere.col
      end
    elsif mere && mere.built?
      # Si la personne n'a pas de père, mais une mère
      @rang = mere.rang + 1
      if has_sibling?
        @col  = mere.col - siblings.count/2 + indice_enfant * 2
      else
        @col = mere.col
      end
    else
      Genea::Builder.log("PROBLEM: avec #{self}. Impossible de déterminer @rang et @col.")
      return nil
    end
    return true
  end

  def top
    @top ||= begin
      # puts "rang de #{self}: #{rang.inspect}"
      (rang * Genea::Builder::RANG_FULL).round
    end.tap do |val| 
      Genea::Builder.set_max(:bottom, val + Genea::Builder::RANG_FULL)
      Genea::Builder.set_max(:top, val, :smaller)
    end
  end
  def left
    @left ||= begin
      # puts "col de #{self}: #{col.inspect}"
      (col * Genea::Builder::COL_WIDTH).round
    end.tap do |val|
      Genea::Builder.set_max(:left, val, :smaller)
      Genea::Builder.set_max(:right, val)
    end
  end


  # Si la personne appartient à une fratrie, il faut déterminer son 
  # indice de naissance pour savoir où le placer
  def indice_enfant
    @indice_enfant ||= begin
      if has_sibling?
        (pere || mere)
        .sorted_children
        .map {|p| p.id }
        .index(self.id)#.tap {|i| puts "Indice de #{self} : #{i}"}
      else
        0
      end
    end
  end

  def siblings
    @siblings ||= (pere||mere).enfants
  end

  def has_sibling? 
    (pere || mere) && siblings.count > 1
  end

  def is_last_child?
    has_sibling? && indice_enfant == siblings.count - 1
  end

  def previous_sibling
    @previous_sibling ||= siblings[indice_enfant - 1]
  end

  def sorted_children
    @sorted_children ||= enfants.sort_by { |p| p.naissance }
  end

  # Après avoir instancié toutes les personnes, on traite les 
  # relatives. Pour l'instant, ça consiste simplement à mettre
  # l'instance dans la propriété correspondante
  # 
  # @return self, pour le chainage
  def affect_relatives

    if data['mari']
      # puts "data['mari'] = #{data['mari'].inspect}"
      @mari = Genea::Data.persons[data['mari']] || begin
        puts "Impossible de trouver le mari #{data['mari'].inspect}".rouge
      end
      if @mari.femme.nil?
        # puts "Femme de #{@mari.patronyme} mise à #{self.patronyme}".bleu
        @mari.femme = self
      elsif @mari.femme.id != self.id
        puts "La femme devrait avoir l'identifiant #{self.id}. Or c'est @mari.femme.id (je corrige).".rouge
        @mari.femme = self
      end
    end

    if data['femme']
      # puts "data['femme'] = #{data['femme'].inspect}"
      @femme = Genea::Data.persons[data['femme']] || begin
        puts "Impossible de trouver la femme #{data['femme'].inspect}".rouge
      end
      if @femme.mari.nil?
        # puts "Mari de #{femme.patronyme} mis à #{self.patronyme}".bleu
        @femme.mari = self
      elsif @femme.mari.id != self.id
        # puts "Le mari de la femme #{femme.patronyme} devait être #{self.patronyme} (je corrige).".rouge
        @femme.mari = self
      end
    end

    if data['pere']
      # puts "data['pere'] = #{data['pere'].inspect}"
      @pere = Genea::Data.persons[data['pere']] || begin
        puts "Impossible de trouver le père #{data['pere'].inspect}…".rouge
      end 
      unless @pere.enfants.include?(self)
        # puts "Ajout de l'enfant #{self.patronyme} au père #{pere.patronyme}".bleu
        @pere.enfants << self
      end
    end

    if data['mere']
      @mere   = Genea::Data.persons[data['mere']] || begin
        puts "Impossible de trouver la mère #{data['mere'].inspect}…".rouge
      end        
      unless @mere.enfants.include?(self)
        # puts "Ajout de l'enfant #{self.patronyme} à la mère #{mere.patronyme}".bleu
        @mere.enfants << self
      end
    end

    if data['enfants']
      @enfants = 
      data['enfants']
      # On transforme la donnée en liste d'instance si ça n'est pas
      # déjà une instance
      .map do |foo| 
        case foo
        when Genea::Person 
          foo
        when String 
          Genea::Data.persons[foo] || puts("Impossible de trouver la personne d’identifiant #{foo.inspect}".rouge)
        end
      end
      # On classe par âge
      .sort_by { |p| p.age }
      # On définit le parent s'il n'est pas défini et si c'est
      # possible
      .each do |p|
        if is_mari?
          # puts "Père de #{p.patronyme} mis à #{self.patronyme}".bleu
          p.pere = self
        elsif is_femme?
          # puts "Mère de #{p.patronyme} mis à #{self.patronyme}".bleu
          p.mere = self
        end
      end
    end

    return self
  end

  def is_femme?
    femme.nil? && !mari.nil?
  end

  def is_mari?
    mari.nil? && !femme.nil?
  end

  def has_conjoint?
    !conjoint.nil?
  end
  
  def is_single?
    conjoint.nil?
  end

  def has_enfants?
    enfants.count > 0
  end
  alias :has_children? :has_enfants?

  def f_patronyme; @f_patronyme end

  def patronyme=(value)
    @patronyme = value
    @data.store('patronyme', value)
    @@f_patronyme = nil
  end
  def patronyme
    @patronyme ||= begin
      if data['patronyme']
        mots = data['patronyme'].split(" ")
        nom  = (mots.pop||"").upcase
        prenom = mots.join(" ")
        @f_patronyme = "#{prenom}<br>#{nom}".strip
        "#{prenom} #{nom}".strip
      end
    end
  end
  
  def femme; @femme end
  def femme=(value)
    @femme = value
    @data.store('femme', value.id)
  end
  def mari; @mari end
  def mari=(value)
    @mari = value
    @data.store('mari', value.id)
  end
  def conjoint
    @conjoint ||= begin
      if is_mari?
        femme
      elsif is_femme?
        mari
      else
        nil
      end
    end
  end
  def pere; @pere end
  def pere=(value)
    @pere = value
    @data.store('pere', value.id)
  end
  def mere; @mere end
  def mere=(value)
    @mere = value
    @data.store('mere', value.id)
  end
  def enfants=(value)
    @enfants = value
    @data.store('enfants', value.map{|p|p.id})
  end
  def enfants
    @enfants ||= begin
      if data['enfants']
        data['enfants'].map{|pid| self.class.get(pid)}
      # NON, on ne prend plus les enfants du conjoint s'ils ne sont
      # pas définis pour soi. Le conjoint peut avoir un enfant d'un
      # autre lit.
      # elsif has_conjoint? && conjoint.data['enfants']
      #   conjoint.enfants
      else
        []
      end
    end
  end
  def add_enfant(person)
    @enfants ||= []
    @enfants << person
    @data['enfants'] ||= []
    @data['enfants'] << person.id
  end
  def remove_from_enfants(enfant)
    @enfants.delete_if { |p| p.id == enfant.id }
  end

  # Attention : pas utilisé en mode définition 
  def id
    @id = nil if @id == ''
    @id ||= data['id'] || begin
      if patronyme
        self.class.make_uniq_id(patronyme)
        # .tap do |paraphe|
        #   puts "Je viens de faire un nouveau parapth pour #{self} : #{paraphe}. Est-il bien unique ?".jaune
        #   raise "Pour voir"
        # end
      end #/si le patronyme est défini
    end
  end

  def self.make_uniq_id(patro)
    motspurs = patro
    .unicode_normalize(:nfd)
    .gsub(/\p{Mn}/, '')
    .upcase
    .split(' ')
    .map { |mot| mot.split('') }

    paraphe = ""
    fin = false
    while !fin
      motspurs.each do |lettres|
        if lettres.empty?
          fin = true
          break
        end
        paraphe += lettres.shift
        if paraphe.length > 1 && get(paraphe).nil?
          return paraphe 
        end
      end
    end
    # Par dépit, si on arrive vraiment ici, on ajoute un suffixe
    # Pour être sûr d'obtenir un id unique
    i = 0
    begin
      tested_paraphe = "#{paraphe}#{i += 1}"
    end while exists?(tested_paraphe)
    return tested_paraphe
  end

  def sexe; @sexe ||= data['sexe'] end
  def sexe=(value)
    @sexe = value
    @data.store('sexe', value)
  end
  def naissance; @naissance ||= data["naissance"] end
  def naissance=(value)
    @naissance = value
    @data.store('naissance', value)
  end
  def mort; @mort ||= data["mort"] end
  def mort=(value)
    @mort = @mort
    @data.store('mort', value)
  end

  def annee_mariage; @annee_mariage ||= data['annee_mariage'] end
  def annee_mariage=(value)
    @annee_mariage = value
    @data.store('annee_mariage', value)
  end

  def mark_age
    @mark_age ||= begin
      age ? "(#{age} an#{"s" if age > 1})" : '?'
    end
  end

  def age 
    @age ||= begin
      if naissance.nil? || naissance == '?'
        nil
      elsif mort.is_a?(Integer) && mort < Genea::Builder::ANNEE_REF
        mort - naissance
      else
        Genea::Builder::ANNEE_REF - naissance
      end
    end
  end

  def couleur; @couleur ||= data['couleur'] end
  def couleur=(val)
    @couleur = val
    data.store('couleur', val)
  end

  def main; @main ||= data["main"] end
  def main?
    # puts "#{id} est #{main.inspect}"
    # puts "data: #{data}"
    self.main === true 
  end


end #/Genea::Person