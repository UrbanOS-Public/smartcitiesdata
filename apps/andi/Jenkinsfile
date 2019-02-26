library(
    identifier: 'pipeline-lib@4.3.4',
    retriever: modernSCM([$class: 'GitSCMSource',
                          remote: 'https://github.com/SmartColumbusOS/pipeline-lib',
                          credentialsId: 'jenkins-github-user'])
)

properties([
    pipelineTriggers([scos.dailyBuildTrigger('10-12')]), //UTC
])

def image, imageName

def doStageIf = scos.&doStageIf
def doStageIfRelease = doStageIf.curry(scos.changeset.isRelease)
def doStageUnlessRelease = doStageIf.curry(!scos.changeset.isRelease)
def doStageIfPromoted = doStageIf.curry(scos.changeset.isMaster)

node('infrastructure') {
    ansiColor('xterm') {
        scos.doCheckoutStage()

        imageName = "scos/andi"
        imageTag = "${env.GIT_COMMIT_HASH}"

        doStageUnlessRelease('Build') {
            image = docker.build("${imageName}:${imageTag}")
        }
        

        doStageUnlessRelease('Deploy to Dev') {
            scos.withDockerRegistry {
                image.push()
                image.push('latest')
            }

            deployAndiTo('dev', imageName, imageTag)
        }

        doStageIfPromoted('Deploy to Staging') {
            def environment = 'staging'

            deployAndiTo(environment, imageName, imageTag)

            scos.applyAndPushGitHubTag(environment)

            scos.withDockerRegistry {
                image.push(environment)
            }
        }

        doStageIfRelease('Deploy to Production') {
            def releaseTag = env.BRANCH_NAME
            def promotionTag = 'prod'

            deployAndiTo('prod', imageName, imageTag)

            scos.applyAndPushGitHubTag(promotionTag)

            scos.withDockerRegistry {
                image = scos.pullImageFromDockerRegistry(imageName, imageTag)
                image.push(releaseTag)
                image.push(promotionTag)
            }
        }
    }
}

def deployAndiTo(environment,imageName, tag) {
    def extraVars = [
        'image_repository': "${scos.ecrHostname}/${imageName}",
        'tag': tag
    ]

    def terraform = scos.terraform(environment)
    sh "terraform init && terraform workspace new ${environment}"
    terraform.plan(terraform.defaultVarFile, extraVars)
    terraform.apply()
}
