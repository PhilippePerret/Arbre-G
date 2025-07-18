class Genea
class << self

  # Point d'entrée
  # 
  def run
    LastAction.load if same_command?

    action ||= CLI.main_command || choose_action || return
    fichegene = CLI.params[:fg]
    anneeref  = CLI.params[:ar]
    methode = "action_#{action}".to_sym
    # puts "Méthode: #{methode.inspect}".bleu
    if self.respond_to?(methode)
      send(methode)
      # On mémorise la dernière action pour option -s/--same
      LastAction.save(action: action, fiche: fichegene, annee: anneeref, options: CLI.options) unless same_command?
    else
      puts "Je ne connais pas la commande #{action.inspect}. Mieux vaut ne rien mettre".rouge
    end
  end

  
  def action_define
    require_relative '../modules/define'
    Genea::Define.define
  end
  def action_build
    Builder.build
    action_open if Q.yes?("Veux l'ouvrir dans le navigateur ?".jaune)
  end
  def action_open
    puts "Ouverture de l'arbre dans le navigateur…".bleu
    `open -a Finder "#{File.dirname(Genea::Builder.path)}"`
    `open "#{Genea::Builder.path}"`
  end

  # Fabrication PNG
  # Note : Rien de ce qui a été essayé (chromium, google chrome, playwright, whtmltoimage, etc.) n'a été foutu de garder les position:absolute. Je dois donc passer par un screenshot de l'écran.
  def action_png
    puts "Fabrication de l'image PNG…".jaune
    puts "Pour le moment, le seul moyen est de faire un screenshot. Joue Cmd+Maj+4 puis sélectionne la zone voulue."
    sleep 4
    action_open
  end
  def action_open_svg
    puts "Je dois apprendre à ouvrir l'image SVG de l'arbre".jaune
  end

  def same_command?
    :TRUE == @same_command ||= begin
      (CLI.option(:same) || CLI.option(:s)) ? :TRUE : :FALSE
    end
  end

  def debug?
    :TRUE == @debug_it ||= CLI.option(:debug) ? :TRUE : :FALSE
  end

  DATA_ACTIONS = [
    {name: "Définir la généalogie [define]", value: :define},
    {name: "Construire l'arbre généalogique [build]", value: :build},
    {name: "Faire l'image PNG de l'arbre [png]", value: :png},
    {name: "Ouvrir l'arbre dans le navigateur [open]", value: :open},
    {name: "Ouvrir l'image SVG de l'arbre [open_svg]", value: :open_svg}

  ] + [{name: "Quitter".orange, value: nil}]
  def choose_action
    clear
    Q.select("Action généalogique à accomplir : ".jaune, DATA_ACTIONS, cycle: true)
  end
end #/class << self
end #/Genea