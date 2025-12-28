# Projet d'Administration de Base de Donnée

## Objectif

Mettre en place une machine virtuelle Oracle Linux 10, installer et configurer des bases de données et interagir avec les données.

## Mise en Place

J'ai commencé par suivre les instructions sur le document fournit : 

J'ai installé Oracle Linux 10 sur VMware avec les partitions suivantes : 

![lsblk.png](/home/paul/Documents/Evry/M1/S7/BDD/Projet/Media/lsblk.png)

et les ressources système suivantes :

![neofetch.png](/home/paul/Documents/Evry/M1/S7/BDD/Projet/Media/neofetch.png)

Overview de cockpit:

![overview.png](/home/paul/Documents/Evry/M1/S7/BDD/Projet/Media/overview.png)

J'ai ensuite installé les conteneurs en suivant les commandes indiquées.

![dockers.png](/home/paul/Documents/Evry/M1/S7/BDD/Projet/Media/dockers.png)

J'ai ensuite paramétré le pare-feu pour permettre l'accès aux services depuis l'interface web cockpit: 

- MongoDB → port 27017

- OracleSQL → port 1521

![firewall.png](/home/paul/Documents/Evry/M1/S7/BDD/Projet/Media/firewall.png)

J'ai ensuite installé sur ma machine hôte `sqldeveloper` et `MongoDBCompass`. `MongoDbCompass` n'étant pas disponible comme `.deb,` j'ai du convertir le `.rpm` avec `alien` : `alien --to-deb mongodb-compass-1.47.1.x86_64.rpm`, que j'ai installé avec `dpkg -i mongodb-compass-1.47.1.x86_64.deb`. 

Je n'ai pas pu convertir le `.rpm` de `sqldeveloper`, je suis donc passé par  `DistroBox` qui permet de créer un environnement OracleLinux virtualisé. Permettant, entre autre, d'installer simplement des application qui ne sont pas nativement disponible pour ma distribution (Ubuntu 25.04)

```
distrobox create --name oracle-dev --image oraclelinux:9
distrobox enter oracle-dev
sudo dnf install -y java-17-openjdk
sudo dnf install -y /home/paul/Downloads/sqldeveloper-*.rpm
```

J'ai ensuite pu me connecter à la base de donnée 

![sqldev1.png](/home/paul/Documents/Evry/M1/S7/BDD/Projet/Media/sqldev1.png)

## TD3 :

Pour chacune des requêtes expliquez :

- ce qu'elle fait,
- son plan d'exécution,
- si une optimisation vous semble possible.

A)

```sql
select e.first_name, e.last_name, count(*)
from EMPLOYEES e, JOB_HISTORY jh
where e.EMPLOYEE_ID = jh.EMPLOYEE_ID
group by e.first_name, e.last_name;
```

- ce qu'elle fait : donne le prénom, nom et ID des employés

- plan d'exécution : 

![A.png](/home/paul/Documents/Evry/M1/S7/BDD/Projet/Media/A.png)

- optimisation : on peut créer un fichier qui comprend les données des deux tables, pour éviter un join

B)

- rend les employés dont le poste commence par "Sales"

## TD4

On modifie le script de creation du conteneur Tools pour ajouter ce dont on aura besoin ;
J'installe python, pip et des librairies pour dialoguer avec Oracle

```bash
mkdir Tools
cd Tools
cat <<EOF > Dockerfile
FROM oraclelinux:10
RUN yum update -y
RUN dnf install -y python3-pip python3-setuptools python3-pip-wheel
RUN python3 -m venv --system-site-packages ToolsSetupPy
RUN source ToolsSetupPy/bin/activate
RUN python3 -m pip install --user oracledb schedule
RUN export DEBIAN_FRONTEND=noninteractiveRUN yum install tzdata -y
RUN ln -fs /usr/share/zoneinfo/Europe/Paris /etc/localtime
RUN yum install wget -y
RUN yum install libaio -y
RUN yum install zip -y
RUN dnf install -y java-21-openjdk && dnf clean all
RUN wget https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-25.2.2.199.0918.zip
RUN wget https://github.com/oracle-samples/db-sample-schemas/archive/refs/heads/main.zip
RUN wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-rhel88-x86_64-100.13.0.rpm
RUN rpm -Uhv mongodb-database-tools-rhel88-x86_64-100.13.0.rpm
RUN cd /usr/lib && unzip /sqlcl-25.2.2.199.0918.zip
RUN cd / && unzip main.zip
EOF
```

## TD5

**Obtenir la liste des adresses**

On cherche à obtenir quelque chose de la forme : 

*1 rue Jules Vales, Evry-Courcouronnes, 91000*

```sql
SELECT JSON_OBJECT(
    'address'     VALUE l.STREET_ADDRESS,
    'ville'       VALUE l.CITY,
    'code postal' VALUE l.POSTAL_CODE
) AS json_result
FROM LOCATIONS l;
```

Pour avoir toutes les données dans plusieurs fichiers

```bash
cat << 'END_OF_SCRIPT' > import.sh
#!/bin/bash
(/usr/lib/sqlcl/bin/sql -s HR/paul@//E20212888:1521/freepdb1 <<EOF
set pagesize 0
set trimspool on
set headsep off
set null '0'
set echo off
set feedback off
set linesize 1000

SELECT JSON_OBJECT(
    'address'     VALUE l.STREET_ADDRESS,
    'ville'       VALUE l.CITY,
    'code_postal' VALUE l.POSTAL_CODE
)
FROM LOCATIONS l;

exit;
EOF
) | mongoimport --host=mongodb --port=27017 --db HR --collection locations --mode upsert
END_OF_SCRIPT
```

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
```

Pour avoir tout dans un seul fichier

**Obtenir l'historique des lieux de travail**

On cherche quelque chose de la forme :

*Richard Dubois, a travaillé à Ressources Humaines au 14 rue de la pompe, Paris, 75014*

```sql
SELECT JSON_OBJECT(
    'employee'    VALUE e.first_name || ' ' || e.last_name,
    'start_date'  VALUE jh.start_date,
    'end_date'    VALUE jh.end_date,
    'old_address' VALUE JSON_OBJECT(
        'street'      VALUE l.street_address,
        'city'        VALUE l.city,
        'postal_code' VALUE l.postal_code,
        'country'     VALUE l.country_id
    )
)
FROM employees e
JOIN job_history jh ON e.employee_id = jh.employee_id
JOIN departments d  ON jh.department_id = d.department_id
JOIN locations l    ON d.location_id = l.location_id;
```

**Historique des employés et managers de départements**

On cherche par département une liste des employés et des managers
