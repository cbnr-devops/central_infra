@Library('my-shared-lib') _

pipeline {
    agent any

    parameters {
        choice(name: 'CLOUD', choices: ['aws', 'azure'], description: 'Cloud Provider')
        choice(name: 'ENV', choices: ['dev', 'staging', 'all'], description: 'Environment')
    }

    stages {
        stage('Checkout') {
            steps {
                checkoutCode()
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    def basePath = "terraform/${params.CLOUD}/envs"
                    switch(params.ENV) {
                        case 'dev':
                            terraformApply("${basePath}/dev")
                            break
                        case 'staging':
                            terraformApply("${basePath}/staging")
                            break
                        case 'all':
                            terraformApply("${basePath}/dev")
                            terraformApply("${basePath}/staging")
                            break
                    }
                }
            }
        }
    }
}
