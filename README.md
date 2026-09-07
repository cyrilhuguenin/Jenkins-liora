# PROJET GITLAB DATASCIENTEST


# Microservices, API Gateway, Authentification avec FastAPI

- Ce référentiel est composé d'un ensemble de petits microservices prenant en compte l'approche de la passerelle API
- Le nombre prévu de microservices était de deux, mais étant donné que les services
   ne doivent pas créer de dépendance les uns sur les autres pour empêcher le SPOF, également pour éviter les codes en double,
   j'ai décidé de mettre une passerelle api devant qui fait l'authentification JWT pour les deux services
   dont je suis inspiré par Netflix/Zuul
- Nous avons 3 services dont une passerelle.
- Seule la passerelle peut accéder aux microservices internes via le réseau interne (utilisateurs, commandes)

## Services

- gateway : Construite au-dessus de FastAPI, simple passerelle api dont le seul devoir est de rendre propre
   routage tout en gérant l'authentification et l'autorisation
- utilisateurs (a.k.a admin): conserve les informations de l'utilisateur dans sa propre fausse base de données (système de fichiers).
   Peut être exécuté de simples opérations CRUD via le service. Il y a aussi un autre
   point de terminaison pour la connexion, mais le client est extrait de la réponse réelle. Ainsi, le service passerelle
   gérera la réponse de connexion et générera le jeton jwt en conséquence.
- commandes : Les utilisateurs (abonnés - authentification) peuvent créer et consulter (leurs - autorisations) commandes.

## Exécuttion
- check ./gateway/.env => 2 URL de services sont définies sur la base de la conf de douze facteurs
- docker-composer --build
- visitez l'adresse => http://localhost:8001/docs

# Exemples de requêtes
- Il existe déjà 2 utilisateurs dans la base de données des utilisateurs
- obtenir un jeton api avec l'utilisateur administrateur
  ```
  curl --header "Content-Type: application/json" \
       --request POST \
       --data '{"username":"admin","password":"a"}' \
       http://localhost:8001/api/login
  ```
- Vous verrez quelque chose de similaire à ci-dessous
  ```
  {"access_token":"***","token_type":"bearer"}
  ```
- utiliser ce jeton pour faire des demandes au niveau administratif
  ```
  curl --header "Content-Type: application/json" \
       --header "Authorization: Bearer ***" \
       --request GET \
       http://localhost:8001/api/users
  ```
- Des essais similaires peuvent également être effectués avec l'utilisateur par défaut pour créer et afficher les commandes


##Diagramme
![ScreenShot](https://github.com/DataScientest/gitlab_devops_exams/blob/main/diagram.png)

##Documentation Page
![ScreenShot](https://github.com/DataScientest/gitlab_devops_exams/blob/main/docs.png)

## Pipeline CI/CD (Jenkins)

Le Jenkinsfile est un pipeline declaratif execute sur l'agent "worker" :
les builds ne tournent pas sur le controleur Jenkins.

| Stage | Role |
|---|---|
| Init | calcule le tag d'image a partir du SHA court du commit |
| Lint | flake8 dans un conteneur python:3.11-slim (non bloquant) |
| Test | tests unittest de users en python:3.7-slim |
| Build & push | construit les 3 images et les pousse sur DockerHub |
| Deploy dev / qa / staging | helm upgrade --install dans chaque namespace |
| Deploy prod | validation manuelle, branche master uniquement |

Chaque environnement recoit trois releases Helm du meme chart generique
(fastapi/), la gateway etant exposee en NodePort : 30000 (dev), 30001 (qa),
30002 (staging), 30003 (prod).

La production est restreinte par une directive when contenant "branch master"
et l'option "beforeInput true". Cette option est indispensable : sans elle,
Jenkins evaluerait la directive input AVANT la condition de branche, et un
build sur une branche de travail reclamerait quand meme une approbation
avant d'ignorer le stage.
