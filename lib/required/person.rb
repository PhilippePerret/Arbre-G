class Genea::Person
  class << self

    def reset
      @all = []
    end

    # Pour ajouter une personne aux personnes à ajouter dans l'arbre
    # généalogique. C'est lors de la construction que cette donnée
    # est utilisées
    # 
    # @param {Person|Array} person Une personne ou une liste de personnes
    def put(person)
      if person.is_a?(Array)
        @all += person
      else
        @all << person
      end
    end

    # Prendre la première personne de toutes celles qu'il faut trai-
    # ter et la retirer.
    def shift
      @all.shift
    end

  end #/class << self


  attr_reader :data
  attr_accessor :rang, :col

  def initialize(data)
    @data     = data
  end

  def to_s
    "<<Person #{patronyme} indice:#{indice_enfant}>>"
  end

  def add_to_arbre(code)
    calc_position
    code << Genea::Builder.build_person_bloc(self)
    @is_built = true
  end

  def built?
    @is_built === true
  end
  def unbuilt?
    @is_built != true
  end

  # La marque des dates
  # -------------------
  # Date de naissance ou ?
  def f_mark_dates
    @f_mark_dates ||= begin
      mark_mort = mort ? mort.to_s : "   "
      mark_naissance = naissance ? naissance.to_s : " ? "
      mark_age = age ? "(#{age} ans)" : ""

      "#{mark_naissance} – #{mark_mort} #{mark_age}"
    end
  end

  def block_link
      @block_link ||= begin
      elements = []

      if is_mari?
        elements << Genea::Builder.build_epoux_link(self)
      end

      if (pere || mere) && indice_enfant == 0
        elements << Genea::Builder.build_children_links(pere || mere)
      end


      elements.flatten.compact.join('')
    end
  end

  def calc_position
    return if col && rang
    if is_femme? && mari.built?
      @rang = mari.rang
      @col  = mari.col + 1
    elsif is_mari? && femme.built?
      @rang = femme.rang
      @col  = femme.col - 1
    elsif pere && pere.built?
      # Normalement, si je passe ici, c'est forcément que c'est le 
      # premier enfant
      @rang = pere.rang + 1
      if has_sibling?
        @col  = pere.col - siblings.count/2 + indice_enfant * 2 - 1
      else
        @col  = (pere.col) + 0.5
      end
    elsif mere && mere.built?
      # Même remarque que ci-dessus (ici, on n'a pas le père)
      @rang = mere.rang + 1
      if has_sibling?
        @col  = mere.col - 2 - siblings.count/2 + indice_enfant * 2
      else
        @col = mere.col - 0.5
      end
    end
  end

  def top
    @top ||= begin
      # puts "rang de #{self}: #{rang.inspect}"
      rang * Genea::Builder::RANG_FULL
    end.tap {|val| Genea::Builder.set_max(:top, val + Genea::Builder::RANG_FULL)}
  end
  def left
    @left ||= begin
      # puts "col de #{self}: #{col.inspect}"
      col * Genea::Builder::COL_WIDTH    
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
        puts "Femme de #{@mari.patronyme} mise à #{self.patronyme}".bleu
        @mari.femme = self
      elsif @mari.femme.id != self.id
        puts "La femme devrait avoir l'identifiant #{self.id}. Or c'est @mari.femme.id (je corrige).".rouge
        @mari.femme = self
      end
    end

    if data['femme']
      # puts "data['femme'] = #{data['femme'].inspect}"
      @femme = Genea::Data.persons[data['femme']] || begin
        puts "Impossible de trouver la femme #{data['mari'].inspect}".rouge
      end
      if @femme.mari.nil?
        puts "Mari de #{femme.patronyme} mis à #{self.patronyme}".bleu
        @femme.mari = self
      elsif @femme.mari.id != self.id
        puts "Le mari de la femme #{femme.patronyme} devait être #{self.patronyme} (je corrige).".rouge
        @femme.mari = self
      end
    end

    if data['pere']
      # puts "data['pere'] = #{data['pere'].inspect}"
      @pere = Genea::Data.persons[data['pere']]
      unless @pere.enfants.include?(self)
        puts "Ajout de l'enfant #{self.patronyme} au père #{pere.patronyme}".bleu
        @pere.enfants << self
      end
    end

    if data['mere']
      @mere   = Genea::Data.persons[data['mere']]
      unless @mere.enfants.include?(self)
        puts "Ajout de l'enfant #{self.patronyme} à la mère #{mere.patronyme}".bleu
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
          puts "Père de #{p.patronyme} mis à #{self.patronyme}".bleu
          p.pere = self
        elsif is_femme?
          puts "Mère de #{p.patronyme} mis à #{self.patronyme}".bleu
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
      mots = (data['patronyme']||"").split(" ")
      nom  = (mots.pop||"").upcase
      prenom = mots.join(" ")
      @f_patronyme = "#{prenom}<br>#{nom}".strip
      "#{prenom} #{nom}".strip
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
    @enfants ||= (data['enfants']||[]).map{|pid| self.class.get(pid)}
  end
  def add_enfant(person)
    @enfants ||= []
    @enfants << person
    @data['enfants'] ||= []
    @data['enfants'] << person.id
  end

  # Attention : pas utilisé en mode définition 
  def id
    @id = nil if @id == ""
    @id ||= data["id"] 
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

  def age 
    @age ||= begin
      if naissance.nil? || naissance == '?'
        '?'
      elsif mort
        if mort.is_a?(Integer)
          mort - naissance
        else
          '?'
        end
      else
        Time.now.year - naissance # TODO Plus tard en fonction du format de date de la naissance
      end
    end
  end

  def main; @main ||= data["main"] end
  def main?
    # puts "#{id} est #{main.inspect}"
    # puts "data: #{data}"
    self.main === true 
  end


end #/Genea::Person