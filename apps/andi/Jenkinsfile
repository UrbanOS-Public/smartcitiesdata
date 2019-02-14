library(
    identifier: 'pipeline-lib@4.3.4',
    retriever: modernSCM([$class: 'GitSCMSource',
                          remote: 'https://github.com/SmartColumbusOS/pipeline-lib',
                          credentialsId: 'jenkins-github-user'])
)

properties([
    pipelineTriggers([scos.dailyBuildTrigger('10-12')]), //UTC
])

def image

def doStageIf = scos.&doStageIf
def doStageIfRelease = doStageIf.curry(scos.changeset.isRelease)
def doStageUnlessRelease = doStageIf.curry(!scos.changeset.isRelease)
def doStageIfPromoted = doStageIf.curry(scos.changeset.isMaster)

node('infrastructure') {
    ansiColor('xterm') {
        scos.doCheckoutStage()

        doStageUnlessRelease('Build') {
            image = docker.build("scos/andi:${env.GIT_COMMIT_HASH}")
        }

        doStageUnlessRelease('Deploy to Dev') {
            scos.withDockerRegistry {
                image.push()
                image.push('latest')
            }

            deployProducerTo('dev')
        }

        doStageIfPromoted('Deploy to Staging') {
            def promotionTag = scos.releaseCandidateNumber()

            deployProducerTo('staging')

            scos.applyAndPushGitHubTag(promotionTag)

            scos.withDockerRegistry {
                image.push(promotionTag)
            }
        }

        doStageIfRelease('Deploy to Production') {
            def releaseTag = env.BRANCH_NAME
            def promotionTag = 'prod'

            deployProducerTo('prod')

            scos.applyAndPushGitHubTag(promotionTag)

            scos.withDockerRegistry {
                image = scos.pullImageFromDockerRegistry("scos/andi", env.GIT_COMMIT_HASH)
                image.push(releaseTag)
                image.push(promotionTag)
            }
        }
    }
}

def deployProducerTo(environment) {
    scos.withEksCredentials(environment) {
        sh("""#!/bin/bash
            set -e
            helm init --client-only
            helm upgrade --install andi \
                ./chart \
                --namespace=andi \
                --set image.tag="${env.GIT_COMMIT_HASH}" \
        """.trim())
    }
}
