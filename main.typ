// LTeX: language=fr
#import "classic-evry-report/lib.typ": appendix, backmatter, chapters, mainmatter, project, smallprint, use-roman-numbering, use-arabic-numbering, use-binary-numbering

#import "classic-evry-report/template/setup/macros.typ": *

// https://github.com/PaulVerot03/classic-evry-report typst remplate 


// revision to use for add, rmv and change

// it is also possible to apply show rules to the entire project
// it is more or less a search and replace when applying it to a string.
// see https://typst.app/docs/reference/styling/#show-rules
// #show "naive": "naïve"
// #show "Dijkstra's": smallcaps

// Initialize acronyms / glossary
// See https://typst.app/universe/package/glossy for additional details.


#show: init-glossary.with(
  (
    PBL: "Problem Based Learning", // will automatically infer plurality
    web: (
      short: "WWW", // @web will show WWW
      long: "World Wide Web",
    ),
    LTS: (
      short: "LTS",
      long: "Labelled Transition System",
      plural: "LTSs", // override plural explicitly
    ),
  ),
  term-links: true,
) // terms link to the index

#show: project.with(
  meta: (
    project-group: "Master 1 CNS-SR",
    participants: (
      "Paul VEROT, 20212888",
    ),
    email: (
      "pauljeanlouisverot@protonmail.com",
      "paul.verot@etud.univ-evry.fr",
    ),
    supervisors: "Damien PLOIX",
    //field-of-study: "CS",
    project-type: "Semestre 7",
  ),

  fr: (
    title: "Rendu de Projet",
    theme: "Bases de Données",
    abstract: "Mise en place d'une machine virtuelle Oracle Linux 10, installation et configuration de bases de données Oracle SQL et MongoDB, puis interaction avec ces données.",
  ),

  // clear-double-page: false,
)
#let blue(body) = text(fill: rgb("#003b69"), body)


= Mise en Place
J'ai commencé par suivre les instructions du document fourni :
J'ai installé #blue("Oracle Linux 10") sur VMware avec les partitions suivantes :

#figure(
  image("Media/lsblk.png", width: 100%),
  caption: "lsblk",
)
Avec les ressources système suivantes :
#figure(
  image("Media/neofetch.png", width: 100%),
  caption: "neofetch",
)
\
Overview de Cockpit:
#figure(
  image("Media/overview.png", width: 100%),
  caption: "",
)

\
J'ai ensuite installé les conteneurs en suivant les commandes indiquées.\
Comme mentioné en cours, une ligne du fichier de configuration devait être modifiée : 
```sh
podman run -d --network dbnet --name E20212888 \
  -e ORACLE_PWD=motdepasse -p 1521:1521 \
  -v ~/partage:/tmp/partage \
  container-registry.oracle.com/database/free:latest
```
Devient : 
```bash  
podman run -d --network dbnet --name E20212888 \
  -e ORACLE_PWD=motdepasse -p 1521:1521 \
  -v ~/partage:/tmp/partage:z \
  container-registry.oracle.com/database/free:latest
```
Le flag #blue[:z] indique à SELinux que le contenu du dossier sera partagé entre plusieurs conteneurs. #footnote[https://docs.docker.com/engine/storage/bind-mounts/#configure-bind-propagation]

#figure(
  image("Media/dockers.png", width: 100%),
  caption: "podman overview",
)
\
J'ai ensuite configuré le pare-feu pour permettre l'accès aux services depuis l'interface web de Cockpit.
- #blue("MongoDB") → port 20017
- #blue("OracleSQL") → port 1521
#figure(
  image("Media/firewall.png", width: 100%),
)
J'ai ensuite installé sur ma machine hôte SQL Developer et MongoDB Compass. MongoDB Compass n'étant pas disponible au format #blue[.deb], j'ai dû convertir le #blue[.rpm] avec #blue[alien] : ```bash alien --to-deb mongodb-compass*.rpm```, que j'ai installé avec ```bash dpkg -i mongodb-compass*.deb```

Je n'ai pas pu convertir le fichier #blue[.rpm] de SQL Developer. Je suis donc passé par DistroBox, qui permet de créer un environnement Oracle Linux virtualisé, permettant, entre autres, d'installer simplement des applications qui ne sont pas nativement disponibles pour ma distribution (Ubuntu 25.04).
\

```bash
distrobox create --name oracle-dev --image oraclelinux:9
distrobox enter oracle-dev
sudo dnf install -y java-17-openjdk
sudo dnf install -y /home/paul/Downloads/sqldeveloper-*.rpm
```
#linebreak()
J'ai ensuite pu me connecter à la base de données.
#figure(
  image("Media/sqldev1.png", width: 100%),
  caption: "Visualisation d'une instance SQL Developer",
)
\
Avec les bases de données mises en place et les logiciels d'exploration de base installés, on peut intéroger la base OracleSQL.
\
Le contenu des TD en relation avec la base de données mise en place pour le projet sont disponnible sur mon GitHub : #link("https://github.com/PaulVerot03/TD-BDD"), ainsi que le code Typst nécessaire pour générer ce PDF.

= Export des données vers MongoDB
Pour exporter des données vers MongoDB, on a besoin d'un script.
Par exemple, pour exporter une liste des adresses, on peut utiliser le script bash suivant :
```bash
cat << 'END_OF_SCRIPT' > import2.sh
#!/bin/bash
(/usr/lib/sqlcl/bin/sql -s HR/paul@//E20212888:1521/freepdb1 <<EOF
set pagesize 0
set trimspool on
set headsep off
set null '0'
set echo off
set feedback off
set linesize 1000

SELECT JSON_OBJECT( 'adresses' value JSON_ARRAYAGG( JSON_OBJECT(
    'address'     VALUE l.STREET_ADDRESS,
    'ville'       VALUE l.CITY,
    'code postal' VALUE l.POSTAL_CODE
)))
FROM LOCATIONS l;

exit;
EOF
) | mongoimport --host=mongodb --port=27017 --db HR --collection HR2 --mode upsert
END_OF_SCRIPT
``` #footnote[Ce script doit être exécuté dans le conteneur _Tools_ et disposer des permissions appropriées]
\
Ce script permet de réaliser les actions suivantes :
- se connecter à la base de données
- réduire la quantité d'informations retournées
  - #blue("set pagesize 0") désactive les sauts de ligne et les en-têtes de colonne
  - #blue("set trimspool on") supprime les espaces en fin de ligne
  - #blue("set null '0'") spécifie la valeur à inscrire si le champ est nul
  - #blue("set echo off") désactive l'affichage de la commande exécutée
  - #blue("set feedback off") masque les informations de retour à la fin des sélections
  - #blue("set linesize 1000") définit la longueur maximale des lignes affichées
- lancer une requête SQL pour obtenir les informations souhaitées (retournées au format JSON)
  - #blue("adresse")
  - #blue("ville")
  - #blue("code postal")
- importer les données dans la base Mongo en définissant une nouvelle collection
\
#blue("JSON_ARRAYAGG") sert à agréger les données en une seule ligne JSON. Sans cela, le script renverrait autant de lignes que d'entrées dans la table.
L'emploi de #blue("JSON_ARRAYAGG") définit la structure des données dans MongoDB.
Si cette fonction n'est pas utilisée, on obtient une structure plate avec un document par adresse.
Si elle est utilisée, on obtient une structure imbriquée dans laquelle un document contient plusieurs adresses.\
\
Sans : \
Document 1 : `{ "_id": 1, "address": "123 Grand Rue", "ville": "Paris" }` \
Document 2 : `{ "_id": 2, "address": "456 Rue du Four", "ville": "Nice" }` \
Document 3 : `{ "_id": 3, "address": "789 Avenue de Villerbane", "ville": "Lyon" }` \
\
\
Avec : \
Document 1:
```json
{
  "_id": 1,
  "adresses": [
     { "address": "123 Grand Rue", "ville": "Paris" },
     { "address": "456 Rue du Four", "ville": "Nice" },
     { "address": "789 Avenue de Villerbane", "ville": "Lyon" }
  ]
}
```

#figure(
  image("Media/mongo1.png", width: 100%),
  caption: "Capture dans Compass après l'import des données avec le script",
)
