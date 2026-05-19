@Library('Shared@main') _

pipeline {
    agent any

    environment {
        // Continuous Delivery runtime variables using automated build counts
        FRONTEND_TAG = "frontend-b${env.BUILD_NUMBER}"
        BACKEND_TAG  = "backend-b${env.BUILD_NUMBER}"
        
        PROJECT_NAME = "wanderlust"
        DOCKER_USER  = "shubhamsingh74888"
        
        // SonarQube Target Project Aliases
        SONAR_SERVER = "sonar-server"
        SONAR_PRJ_KEY= "Wanderlust-Core"
    }

    stages {
        stage('Initialize Workspace') {
            steps {
                echo "Wiping lingering tracking debris from past workspace sessions..."
                cleanWs()
            }
        }

        stage('Source SCM: Code Checkout') {
            steps {
                code_checkout("https://github.com/shubhamsingh74888/Wanderlust-Mega-Project.git", "main")
            }
        }

        stage('SecOps: Trivy Filesystem Scan') {
            steps {
                trivy_scan()
            }
        }

        stage('SecOps: OWASP Dependency Analysis') {
            steps {
                // Invokes your updated, fully automated fast scanning script
                owasp_dependency('OWASP', 'NVD_API_KEY')
            }
        }

        stage('Quality Assurance: SonarQube Code Scan') {
            steps {
                sonarqube_analysis(env.SONAR_SERVER, env.PROJECT_NAME, env.SONAR_PRJ_KEY)
            }
        }

        stage('QA Quality Gates: Quality Gate Check') {
            steps {
                sonarqube_code_quality()
            }
        }

        stage('Build Phase: Compile Frontend App') {
            steps {
                dir('frontend') {
                    docker_build(env.PROJECT_NAME, env.FRONTEND_TAG, env.DOCKER_USER)
                }
            }
        }

        stage('Build Phase: Compile Backend API') {
            steps {
                dir('backend') {
                    docker_build(env.PROJECT_NAME, env.BACKEND_TAG, env.DOCKER_USER)
                }
            }
        }

        stage('Release Phase: Push Frontend to Registry') {
            steps {
                dir('frontend') {
                    docker_push(env.PROJECT_NAME, env.FRONTEND_TAG, env.DOCKER_USER)
                }
            }
        }

        stage('Release Phase: Push Backend to Registry') {
            steps {
                dir('backend') {
                    docker_push(env.PROJECT_NAME, env.BACKEND_TAG, env.DOCKER_USER)
                }
            }
        }

        stage('Post-Build Tasks: Infrastructure Cleanup') {
            steps {
                dir('frontend') { docker_cleanup(env.PROJECT_NAME, env.FRONTEND_TAG, env.DOCKER_USER) }
                dir('backend')  { docker_cleanup(env.PROJECT_NAME, env.BACKEND_TAG, env.DOCKER_USER) }
            }
        }
    }
}
