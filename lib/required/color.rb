=begin
  Pour la gestion de la couleur qui peut être attribuée aux personnes.
  De cette manière, par exemple, on peut suivre un fil particulier ou
  mettre en exergue certaines personnes.
=end
class Genea::Color
  COLORS = {}
class << self

  # @return La couleur "HHHHHH" d'identifiant {String} +color_id+
  def get(color_id)
    COLORS[color_id]
  end

  # @return le nom de la couleur choisie
  def choose(prompt: "Couleur", default: nil)
    choices = COLORS.map do |name, color|
      {name: name, value: name}
    end + [
      {name: "Renoncer".orange, value: nil},
      {name: "Nouvelle couleur…".bleu, value: :new}
    ]
    case (choix = Q.select("#{prompt} : ".jaune, choices, default: default, per_page: choices.count, cycle: true))
    when :new 
      return define(prompt: prompt)
    when NilClass 
      return
    else 
      return choix
    end
  end

  def load
    reset
    (Genea::Data.get_yaml_data['colors'] || {})
    .each do |color_id, color|
      COLORS.store(color_id, color)
    end
  end

  def reset
    COLORS.clear
  end

  # Point d'entrée pour définir une couleur particulière
  # 
  # @return name Le nom de la couleur
  def define(prompt: "Couleur")
    couleur = Q.ask("#{prompt} : ".jaune) do |q|
      q.validate ->(input) {
        input =~ /[A-F0-9]{6}/i
      }
      q.messages[:valid?] = "Format HHHHHHH"
    end
    while true
      name = Q.ask("Nom de cette couleur".jaune) || return
      break unless name_exists?(name)
      puts "Le nom #{name.inspect} existe déjà.".rouge
    end
    COLORS.store(name, couleur)
    save
    return name
  end

  def name_exists?(name)
    !COLORS[name].nil?
  end

  def save
    Genea::Data.save(couleurs: COLORS)
  end

end #/class << self
end #/class Genea::Color