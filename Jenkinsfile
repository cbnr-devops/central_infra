@Library('my-shared-lib') _

pipeline {
    agent any

    parameters {
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
                    switch(params.ENV) {
                        case 'dev':
                            terraformApply("terraform/envs/dev")
                            break
                        case 'staging':
                            terraformApply("terraform/envs/staging")
                            break
                        case 'all':
                            terraformApply("terraform/envs/dev")
                            terraformApply("terraform/envs/staging")
                            break
                    }
                }
            }
        }
    }
}
