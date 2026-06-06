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

        stage('Terraform Format') {
            steps {
                script {
                    runTerraformForEnv(params.CLOUD, params.ENV) { path ->
                        terraformFmt(path)
                    }
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                script {
                    runTerraformForEnv(params.CLOUD, params.ENV) { path ->
                        terraformValidate(path)
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    runTerraformForEnv(params.CLOUD, params.ENV) { path ->
                        terraformApply(path)
                    }
                }
            }
        }
    }
}
