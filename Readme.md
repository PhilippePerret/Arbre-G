# Arbre G(énéalogique)

## Présentation de l'application

Petit outil pour fabriquer vite et facilement des arbres généralogique, fabriqué pour développer la série « Passé sous silence ». Grâce à elle, on peut :

1. Définir une généalogie simple (arbre généalogique)
2. Construire l'image de cet arbre (à n'importe quelle date)

## Lancement de l'application

* Ouvrir un terminal au dossier
* jouer la commande `bundle exec ruby genea.rb`
* choisir ensuite l'action à exécuter

Pour rejouer exactement la même sous-commande (avec les mêmes options), jouer :

~~~
bundle exec ruby genea.rb -s
~~~

## Installation de l'application

* Télécharger le dossier sur son disque dur
* ouvrir une fenêtre de Terminal (une console) à son dossier,
* jouer la commande `bundle install` pour installer des gems (les librairies),
* jouer la commande `bundle exec ruby genea.rb` pour lancer l'application
* choisir ce que l'on veut faire.

## Production de l'image à une certaine date

Cet outil ayant été développé pour facilité le développement de la série romanesque [Passé sous silence](https://www.icare-editions.fr), on avait besoin de produire la généalogie à différents temps donnés (par exemple l'année de chaque évènement important dans l'histoire de la famille). Pour ce faire, il suffit d'appeler la commande avec l'option `ar` (pour « Année de Référence ») réglée à l'année voulue :

~~~
bundle exec ruby genea.rb -ar

ou 

bundle exec ruby genea.rb --annee-reference

ou 

bundle exec ruby genea.rb ar=1995

~~~
