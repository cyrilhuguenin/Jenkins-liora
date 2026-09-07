// Pipeline SkyBlue — 3 microservices FastAPI, images DockerHub, deploiement Helm
// sur 4 namespaces Kubernetes (dev, qa, staging, prod).
//
// Prerequis cote Jenkins :
//   - credential « dockerhub » de type Username with password (token DockerHub R/W)
//   - job de type Multibranch Pipeline : sans lui BRANCH_NAME n'existe pas et la
//     restriction de branche sur la production ne serait pas reellement appliquee.
//
// Le kubeconfig n'est pas transporte : k3s tourne sur la meme machine que Jenkins
// et /etc/rancher/k3s/k3s.yaml y est lisible. L'utilisateur systeme « jenkins »
// appartient au groupe docker, donc aucun agent dind n'est necessaire.

// Factorise les quatre deploiements : trois releases Helm du meme chart generique.
// fullnameOverride fixe le nom du Service, car la gateway joint ses dependances
// par les noms DNS « users » et « orders » attendus par son code.
def deployTo(String namespace, String nodePort) {
    sh """
        set -eu

        for SVC in users orders; do
            helm upgrade --install "\$SVC" "${env.HELM_CHART}" \
                --namespace ${namespace} --create-namespace \
                --set fullnameOverride="\$SVC" \
                --set image.repository="${env.DOCKERHUB_USER}/${env.IMAGE_PREFIX}-\$SVC" \
                --set image.tag="${env.IMAGE_TAG}" \
                --set service.type=ClusterIP \
                --wait --timeout 5m
        done

        helm upgrade --install gateway "${env.HELM_CHART}" \
            --namespace ${namespace} --create-namespace \
            --set fullnameOverride=gateway \
            --set image.repository="${env.DOCKERHUB_USER}/${env.IMAGE_PREFIX}-gateway" \
            --set image.tag="${env.IMAGE_TAG}" \
            --set service.type=NodePort \
            --set service.nodePort=${nodePort} \
            --set env.USERS_SERVICE_URL=http://users:8000 \
            --set env.ORDERS_SERVICE_URL=http://orders:8000 \
            --wait --timeout 5m

        echo "--- releases de ${namespace} ---"
        helm list --namespace ${namespace}
        kubectl get pods,svc --namespace ${namespace}
    """
}

pipeline {
    // Les builds s'executent sur l'agent « worker », jamais sur le controleur :
    // bonne pratique Jenkins (isolation du controleur) et noeud d'execution
    // deterministe d'un build a l'autre.
    agent { label 'worker' }

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        // Deux builds simultanes deploieraient deux tags differents dans le meme
        // namespace : on serialise.
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        DOCKERHUB_USER = 'chuguenin'
        IMAGE_PREFIX   = 'skyblue'
        HELM_CHART     = './fastapi'
        KUBECONFIG     = '/etc/rancher/k3s/k3s.yaml'
        // Injecte DOCKERHUB_USR et DOCKERHUB_PSW ; Jenkins masque le mot de passe
        // dans toute la sortie console.
        DOCKERHUB      = credentials('dockerhub')
        // NodePort d'exposition de la gateway, un par environnement.
        NODEPORT_DEV     = '30000'
        NODEPORT_QA      = '30001'
        NODEPORT_STAGING = '30002'
        NODEPORT_PROD    = '30003'
    }

    stages {

        stage('Init') {
            steps {
                script {
                    // Tag d'image = SHA court du commit : chaque build est tracable
                    // jusqu'a l'image deployee dans le cluster.
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                }
                sh 'echo "branche=$BRANCH_NAME  tag=$IMAGE_TAG"'
                sh 'docker --version; helm version --short; kubectl version --client'
            }
        }

        stage('Lint') {
            steps {
                // Le lint signale la qualite sans bloquer le rendu : le code fourni
                // par l'enonce n'est pas flake8-clean.
                catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
                    sh '''
                        set -eu
                        docker run --rm -v "$PWD":/src -w /src python:3.11-slim \
                            sh -c "pip install --no-cache-dir --quiet flake8 && \
                                   flake8 --max-line-length=100 gateway users orders"
                    '''
                }
            }
        }

        stage('Test') {
            steps {
                // Tests unittest fournis avec l'application, joues dans la version
                // de Python reellement utilisee par les images (3.7).
                sh '''
                    set -eu
                    docker run --rm -v "$PWD/users":/src -w /src python:3.7-slim \
                        sh -c "pip install --no-cache-dir --quiet passlib==1.7.2 bcrypt==3.1.7 && \
                               python -m tests.auth"
                '''
            }
        }

        stage('Build & push') {
            steps {
                sh '''
                    set -eu
                    echo "$DOCKERHUB_PSW" | docker login -u "$DOCKERHUB_USR" --password-stdin

                    for SVC in gateway users orders; do
                        IMAGE="$DOCKERHUB_USER/$IMAGE_PREFIX-$SVC"
                        docker build -t "$IMAGE:$IMAGE_TAG" "./$SVC"
                        docker push "$IMAGE:$IMAGE_TAG"

                        # « latest » ne suit que master : une branche de travail ne
                        # doit pas ecraser le tag que la production reflete.
                        if [ "$BRANCH_NAME" = "master" ]; then
                            docker tag "$IMAGE:$IMAGE_TAG" "$IMAGE:latest"
                            docker push "$IMAGE:latest"
                        fi
                    done
                '''
            }
        }

        stage('Deploy dev') {
            steps { script { deployTo('dev', env.NODEPORT_DEV) } }
        }

        stage('Deploy qa') {
            steps { script { deployTo('qa', env.NODEPORT_QA) } }
        }

        stage('Deploy staging') {
            steps { script { deployTo('staging', env.NODEPORT_STAGING) } }
        }

        stage('Deploy prod') {
            // beforeInput est essentiel : sans lui, Jenkins demande la validation
            // AVANT d'evaluer la condition de branche, et une branche autre que
            // master reclamerait quand meme une approbation avant d'etre ignoree.
            when {
                beforeInput true
                branch 'master'
            }
            input {
                message "Deployer en PRODUCTION ? (branche master uniquement)"
                ok "Deployer en prod"
            }
            steps { script { deployTo('prod', env.NODEPORT_PROD) } }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
        success {
            echo "Build ${env.BUILD_NUMBER} : images ${env.IMAGE_TAG} deployees."
        }
    }
}
