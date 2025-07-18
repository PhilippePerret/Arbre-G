RSpec.describe Genea do

  before(:each) do
    Genea::Data.reset
    @prenoms_feminins   = PRENOMS[:feminin].dup
    @prenoms_masculins  = PRENOMS[:masculin].dup
    @noms = NOMS.dup
  end

  def make_homme(params = {})
    make_a_person(nil, 'H', params)
  end
  alias :make_h :make_homme

  def make_femme(params = {})
    make_a_person(nil, 'F', params)
  end
  alias :make_f :make_femme

  def make_a_anonym(sexe = 'H', params = {})
    make_a_person(nil, sexe, params)
  end
  # @params {Hash} params
  #   :rang   |
  #   :col    | Pour positionner la personne sur l'arbre
  # 
  def make_a_person(patro = nil, sexe = 'H', params = {})
    patro ||= begin
      prenoms = sexe == 'F' ? @prenoms_feminins : @prenoms_masculins
      random_patronyme(prenoms, @noms)
    end
    # Sera-t-il positionné ?
    rang = params.delete(:rang) || params.delete('rang')
    col  = params.delete(:col)  || params.delete('col')
    # Identifiant unique
    id = params[:id] || params['id'] || Genea::Person.make_uniq_id(patro)
    # On met toutes les clés en string
    data = {}
    params.each do |prop, val| data.store(prop.to_s, val) end
    # Transformation de certaines valeurs
    ['pere','mere','mari','femme'].each do |prop|
      data.store(prop, data[prop].id) if data[prop].is_a?(Genea::Person)
    end
    # Instanciation
    data = data.merge(data, {'id' => id, 'patronyme' => patro, 'sexe' => sexe})
    person = Genea::Person.new(data)
    Genea::Data.add_person(person)
    person.affect_relatives
    positionne(person, rang, col) if rang && col
    return person
  end

  # Pour positionner la {Personn} sur l'arbre (donc il est construit
  # après cette opération)
  def positionne(who, rang, col)
    who.rang = rang
    who.col  = col
    who.set_built
    expect(who.built?).to be true # check
  end

  describe "Le positionnement d'une fille" do
    # En réalité, plutôt que "fille", il faudrait parler du
    # conjoint "droit", qui peut être homme ou femme, comme 
    # le conjoint "gauche", appelé "mari" ici, peut être homme
    # ou femme
    before(:each) do
      rang = rand(10) + 1
      @pere = make_homme(rang: 2, col: 11)
      @mere = make_femme(rang:2, col: 12, mari: @pere)
      @fille = make_femme(pere: @pere, mere: @mere)
    end
    context "unique avec ses parents, non mariée" do
      it "se met dessous entre les deux" do
        @fille.calc_position
        expect(@fille.rang).to be(@pere.rang + 1)
        expect(@fille.col).to be(@pere.col + 0.5)
      end
    end
    context "unique avec ses parents, mariée" do
      it "se met juste en dessous de la mère (et son mari sous le père)" do
        mari = make_homme(femme: @fille)
        @fille.calc_position
        expect(@fille.rang).to be(@pere.rang + 1)
        expect(@fille.col).to be(@mere.col)
        @fille.set_built
        mari.calc_position
        expect(mari.rang).to be(@pere.rang + 1)
        expect(mari.col).to be(@pere.col)
      end
    end
  end #/describe positionnement d'une fille


  describe "Le positionnement d'un garçon" do
    before(:each) do
      rang = rand(10) + 1
      @pere = make_homme(rang:8, col: 11)
      @mere = make_femme(rang:8, col: 12, mari: @pere)
      @fils = make_homme(pere: @pere, mere: @mere)
    end
    let(:fils) { @fils }
    context "unique et non marié, avec deux parents" do
      it "se met dessous entre les deux" do
        # - État de départ -
        expect(fils.rang).to be_nil
        expect(fils.col).to be_nil
        # - test -
        fils.calc_position
        # - vérification -
        expect(fils.rang).to eq(9)
        expect(fils.col).to eq(11.5)
      end
    end
    context "unique marié avec deux parents" do
      it "se met juste en dessous du père et sa femme", only: true do
        femme = make_femme(mari: fils)
        fils.calc_position
        expect(fils.rang).to eq(9)
        expect(fils.col).to eq(11)
        fils.set_built
        femme.calc_position
        expect(femme.rang).to eq(9)
        expect(femme.col).to eq(12)
      end
    end
  end

end