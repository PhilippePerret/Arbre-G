class Genea
class Define
class << self

  # Point d'entrée
  # 
  def define
    # Année de référence
    Genea::Builder.const_set('ANNEE_REF', Genea::Data.annee_reference)

    if CLI.params[:fg]
      Genea::Data.load(CLI.params[:fg])
    else
      if Q.yes?("Dois-je repartir d'une généalogie existante ?".jaune)
        Genea::Data.ask_and_load_fiche || return
      else
        fiche_name = Q.ask("Nom de la fiche", default: 'nouvelle_fiche')
        Genea::Data.reset
        Genea::Data.path= File.join(Genea::FICHES_FOLDER, "#{fiche_name}.yaml")
        define_a_person
      end
    end

    choices = update_persons_choices(persons)

    while true
      clear
      case (choix = Q.select("Modifier".jaune, choices, per_page: choices.count, cycle: true))
      when :create
        new_person = define_a_person
        Genea::Data.add_person(new_person)
        choices = update_persons_choices(persons)
      when :quit
        break if Q.yes?("Veux-tu vraiment quitter sans sauver ?".orange)
        save(persons) and break
      when :quit_and_save
        save(persons) and break
      else
        define_a_person(choix)
      end
    end #/ while
    if Q.yes?("Veux-tu construire l'arbre généalogique ?".jaune)
      Genea::Builder.build
      Genea.action_open
    end
  end

  def persons
    Genea::Data.persons
  end

  def save(lespersons)
    hashpersons = {}
    lespersons.values.each {|p| hashpersons.store(p.id, p.data)}
    Genea::Data.save(persons: hashpersons)
  end

  def update_persons_choices(lespersons)
    Genea::Person.persons_as_choices +
    [
      {name: "Nouvelle personne…".bleu, value: :create},
      {name: "Enregistrer et finir".bleu, value: :quit_and_save},
      {name: "Finir sans enregistrer".orange, value: :quit}
    ]
  end

  # Définit une personne, la met dans la table et la retourne
  def define_a_person(person = Genea::Person.new({}))
    person.define
    Genea::Data.add_person(person)
    return person
  end

end #/class << self
end #/class Define

class Person
  class << self

    # Raccourci
    def persons; Genea::Data.persons end

    def choose_someone(params = {})
      choices = persons_as_choices(params)
      if choices.empty?
        # Il n'y a personne, il faut donc créer cette personne
        Genea::Define.define_a_person
      else
        # On choisit parmi les personnes présentes
        allchoices = choices + [
          {name: "Ne mettre personne", value: nil},
          {name: "Nouvelle personne…", value: :create}
        ]
        case choix = Q.select("Choisis #{params[:quest] || "la personne"} :".jaune, allchoices, per_page: allchoices.count, cycle: true)
        when :create
          Genea::Define.define_a_person
        when nil then nil
        else choix
        end
      end
    end

    def persons_as_choices(params = {})
      persons.map do |pid, p|
        next if params[:but] && p.id == params[:but]
        {name: "#{p.patronyme} (#{p.f_mark_dates})", value: p}
      end.compact
    end

  end #/class << self

  # Grande méthode pour définir les valeurs de la personne
  def define
    clear
    while true
      case Q.select("Choisis la propriété à modifier".jaune, choices_properties, {per_page: choices_properties.count, cycle: true})
      when nil then return self
      when :patronyme 
        self.patronyme = Q.ask("Patronyme : ".jaune, default: patronyme)
        id if @id.nil?
      when :sexe
        self.sexe = choose_sexe(default: sexe)
      when :naissance 
        self.naissance = choose_date("Année de naissance : ", :birth)
      when :mort 
        self.mort = choose_date("Année de décès : ", :death)
      when :couleur
        self.couleur = Genea::Color.choose(prompt: "Couleur pour #{patronyme}", default: couleur)
      when :annee_mariage
        self.annee_mariage = choose_date("Année de mariage : ", :mariage)
      when :mari
        good_one = self.class.choose_someone(but: self, as: :mari, quest: "le mari")
        if good_one.nil?
          self.mari.femme = nil unless self.mari.nil?
          self.mari = nil
        elsif is_good_person?(good_one, :mari)
          self.mari = good_one 
          good_one.femme = self
        end
      when :femme
        good_one = self.class.choose_someone(but: self, as: :femme, quest: "la femme")
        if good_one.nil?
          self.femme.mari = nil unless self.femme.nil?
          self.femme = nil
        elsif is_good_person?(good_one, :femme)
          self.femme = good_one
          good_one.mari = self
        end
      when :pere
        good_one = self.class.choose_someone(but: self, as: :pere, quest: "le père")
        if good_one.nil?
          # Le père était défini et il est supprimé
          self.pere.remove_from_enfants(self) unless self.pere.nil?
          self.pere = nil
        elsif is_good_person?(good_one, :pere)
          self.pere = good_one
          good_one.add_enfant(self)
        end
      when :mere
        good_one = self.class.choose_someone(but: self, as: :mere, quest: "la mère")
        if good_one.nil? 
          self.mere.remove_from_enfants(self) unless self.mere.nil?
          self.mere = nil
        elsif is_good_person?(good_one, :mere)
          self.mere = good_one
          good_one.add_enfant(self)
        end
      end
      clear
    end
  end

  def is_good_person?(who, as)
    case as
    when :femme
      !([pere, mere, mari]).include?(who).tap {|v| alerte( "#{who} ne peut être la femme…") if v}
    when :mari
      true
    when :pere
      true
    when :mere
      true
    end
  end

  def alerte(msg)
    puts msg.rouge
    sleep 2
  end

  def choose_sexe(default: 'F')
    choices = [
      {name: "Femme", value: 'F'},
      {name: "Homme", value: 'H'},
      {name: "Indéterminé", value: 'I'},
      {name: "Retirer l'information", value: nil}
    ]
    puts "default = #{default.inspect}"
    Q.select("Sexe : ".jaune, choices, per_page: choices.count, cycle: true, default: default)
  end

  def choose_date(message, type)
    Q.ask(message.jaune, convert: :int) do |q| 
      q.convert ->(input) { input.to_i }
      q.validate ->(input) { 
        quatre_chiffres = input =~ /^[0-9]{4}$/
        input = input.to_i
        good_for_other_date =
          case type
          when :mariage
            (naissance.nil? || input >= naissance) && (mort.nil? || input <= mort)
          when :death
            naissance.nil? || input >= naissance
          when :birth
            mort.nil? || input <= mort
          end
        quatre_chiffres && good_for_other_date
      }
      q.messages[:valid?] = "La valeur doit être une date supérieure à #{naissance}".rouge
      q.messages[:convert?] = "La valeur doit être une date en 4 chiffres".rouge
    end
  end

  def choices_properties
    [
      {name: "Patronyme : #{patronyme.inspect}", value: :patronyme, default: patronyme},
      {name: "ID : #{id.inspect}", value: :id, default: id },
      {name: "Sexe : #{sexe}", value: :sexe},
      {name: "Naissance : #{naissance.inspect}", value: :naissance, default: nil},
      {name: "Mort : #{mort.inspect}", value: :mort, default: nil},
      {name: "Mari : #{mari}", value: :mari, default: mari},
      {name: "Femme : #{femme}", value: :femme, default: femme},
      {name: "Année de mariage: #{annee_mariage}", value: :annee_mariage, default: femme},
      {name: "Père : #{pere}", value: :pere, default: pere},
      {name: "Mère : #{mere}", value: :mere, default: mere},
      {name: "Enfants : #{enfants.count}", value: :enfants, default: []},
      {name: "Couleur: #{couleur}", value: :couleur, default: nil},
      {name: "Note : #{@note.inspect}", value: :note},
      {name: "Cause de la mort : #{@death_cause.inspect}", value: :death_cause},
      {name: "Finir".orange, value: nil}
    ]
  end

end #/class Person


end #/class Genea