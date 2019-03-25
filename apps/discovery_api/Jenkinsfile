library(
    identifier: 'pipeline-lib@4.3.6',
    retriever: modernSCM([$class: 'GitSCMSource',
                          remote: 'https://github.com/SmartColumbusOS/pipeline-lib',
                          credentialsId: 'jenkins-github-user'])
)

properties([
    pipelineTriggers([scos.dailyBuildTrigger()]),
])

def image
def imageName = "scos/discovery-api"
def doStageIf = scos.&doStageIf
def doStageIfRelease = doStageIf.curry(scos.changeset.isRelease)
def doStageUnlessRelease = doStageIf.curry(!scos.changeset.isRelease)
def doStageIfPromoted = doStageIf.curry(scos.changeset.isMaster)

node ('infrastructure') {
    ansiColor('xterm') {
        scos.doCheckoutStage()

        imageTag = "${env.GIT_COMMIT_HASH}"

        doStageUnlessRelease('Build') {
            withCredentials([string(credentialsId: 'hex-read', variable: 'HEX_TOKEN')]) {
                image = docker.build("${imageName}:${imageTag}", '--build-arg HEX_TOKEN=$HEX_TOKEN .')

                stage('Integration') {
                    sh('''
                        export HOST_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
                        mix local.hex --force
                        mix local.rebar --force
                        mix hex.organization auth smartcolumbus_os --key $HEX_TOKEN
                        mix deps.get
                        mix test.integration 
                    ''')
                }
            }
        }

        doStageUnlessRelease('Deploy to Dev') {
            scos.withDockerRegistry {
                image.push()
                image.push('latest')
            }
            deployDiscoveryApiTo(environment: 'dev', tag: imageTag)
        }

        doStageIfPromoted('Deploy to Staging')  {
            def environment = 'staging'

            deployDiscoveryApiTo(environment: environment, tag: imageTag)

            scos.applyAndPushGitHubTag(environment)

            scos.withDockerRegistry {
                image.push(environment)
            }
        }

        doStageIfRelease('Deploy to Production') {
            def releaseTag = env.BRANCH_NAME
            def promotionTag = 'prod'

            deployDiscoveryApiTo(environment: 'prod', internal: false, tag: imageTag)

            scos.applyAndPushGitHubTag(promotionTag)

            scos.withDockerRegistry {
                image = scos.pullImageFromDockerRegistry(imageName, env.GIT_COMMIT_HASH)
                image.push(releaseTag)
                image.push(promotionTag)
            }
        }
    }
}

def deployDiscoveryApiTo(params = [:]) {
    def extraVars = [
      'image_tag': params.get('tag')
    ]
    def environment = params.get('environment')
    if (environment == null) throw new IllegalArgumentException("environment must be specified")

    def terraform = scos.terraform(environment)
    sh "terraform init && terraform workspace new ${environment}"
    terraform.plan(terraform.defaultVarFile, extraVars)
    terraform.apply()
}
