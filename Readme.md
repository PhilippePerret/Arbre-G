# Arbre G(énéalogique)

## Présentation de l'application

Petit outil pour fabriquer vite et facilement des arbres généralogique, fabriqué pour développer la série « Passé sous silence ». Grâce à elle, on peut :

1. Définir une généalogie simple (arbre généalogique)
2. Construire l'image de cet arbre (à n'importe quelle date)

<a name="run-app"></a>

## Lancement de l'application

### Avec le binaire

Double-cliquer sur le fichier `bin/arbreg`.

### Avec une commande d'alias 

> Avec une commande d'alias il sera possible de mettre des paramètres et options.

Dans un premier temps (mais une seule fois), créer une commande (un lien symbolique) pointant vers le binaire du dossier `bin` :

~~~
ln -s path/to/arbre-G/bin/arbreg /usr/local/bin/arbreg
# Remplacer 'path/to/' par votre emplacement
~~~

Maintenant vous pouvez, simplement en ouvrant une fenêtre de Terminal (une console), taper :

~~~
arbreg
~~~

Pour rejouer la même commande (que la dernière fois par exemple) :

~~~
arbreg -s
~~~

### Sans binaire et sans alias de commande

* Ouvrir un terminal au dossier de l'application,
* jouer la commande `bundle exec ruby main.rb` (avec ou sans arguments),
* choisir ensuite l'action à exécuter.

Pour rejouer exactement la même sous-commande (avec les mêmes options), jouer :

~~~
bundle exec ruby main.rb -s
~~~

## Installation de l'application

* Télécharger le dossier sur son disque dur
* ouvrir une fenêtre de Terminal (une console) à son dossier,
* jouer la commande `bundle install` pour installer des gems (les librairies),
* voir ensuite comment faire pour [lancer l'application](#run-app),
* choisir ce que l'on veut faire.

## Production de l'image à une certaine date

Cet outil ayant été développé pour facilité le développement de la série romanesque [Passé sous silence](https://www.icare-editions.fr), on avait besoin de produire la généalogie à différents temps donnés (par exemple l'année de chaque évènement important dans l'histoire de la famille). Pour ce faire, il suffit d'appeler la commande avec l'option `ar` (pour « Année de Référence ») réglée à l'année voulue :

~~~
bundle exec ruby main.rb -ar

ou 

bundle exec ruby main.rb --annee-reference

ou 

bundle exec ruby main.rb ar=1995

~~~

![Arbre en 2025][/images/annee-2025.png]

![Arbre en 1938][/images/annee-1938.png]