RSpec.describe Genea::Builder do

  describe "Le positionnement" do
    context "d'un enfant unique avec deux parents" do
      it "se met dessous entre les deux" do
        Genea::Data.reset
        pere = Genea::Person.new({'patronyme' => "Le Père", 'id' => "LP"})
        Genea::Data.add_person(pere)
        pere.rang = 4
        pere.col  = 10
        pere.set_built
        expect(pere.built?).to be true
        mere = Genea::Person.new({'patronyme' => "La Mère", 'id' => "LM"})
        Genea::Data.add_person(mere)
        mere.rang = 4
        mere.col  = 11
        mere.set_built
        expect(mere.built?).to be true
        fils = Genea::Person.new({'patronyme' => "Le Fils", 'id' => 'LD', 'pere' => "LP", 'mere' => "LM", 'sexe' => 'H'})
        Genea::Data.add_person(fils)
        fils.affect_relatives
        # - État de départ -
        expect(fils.rang).to be_nil
        expect(fils.col).to be_nil
        # - test -
        fils.calc_position
        # - vérification -
        expect(fils.rang).to eq(5)
        expect(fils.col).to eq(10.5)
      end
    end
    context "d’un enfant unique avec un seul parent" do
      it "se met juste en dessous du parent" do

      end
    end
  end

end