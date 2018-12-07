library(
    identifier: 'pipeline-lib@4.3.1',
    retriever: modernSCM([$class: 'GitSCMSource',
                          remote: 'https://github.com/SmartColumbusOS/pipeline-lib',
                          credentialsId: 'jenkins-github-user'])
)

properties([
    pipelineTriggers([scos.dailyBuildTrigger()]),
])

def image
def doStageIf = scos.&doStageIf
def doStageIfRelease = doStageIf.curry(scos.changeset.isRelease)
def doStageUnlessRelease = doStageIf.curry(!scos.changeset.isRelease)
def doStageIfPromoted = doStageIf.curry(scos.changeset.isMaster)

node ('infrastructure') {
    ansiColor('xterm') {
        scos.doCheckoutStage()

        doStageUnlessRelease('Build') {
            image = docker.build("scos/discovery-api:${env.GIT_COMMIT_HASH}")
        }

        doStageUnlessRelease('Deploy to Dev') {
            scos.withDockerRegistry {
                image.push()
                image.push('latest')
            }
            deployDiscoveryApiTo(environment: 'dev')
        }

        doStageIfPromoted('Deploy to Staging')  {
            def promotionTag = scos.releaseCandidateNumber()

            deployDiscoveryApiTo(environment: 'staging')

            scos.applyAndPushGitHubTag(promotionTag)

            scos.withDockerRegistry {
                image.push(promotionTag)
            }
        }

        doStageIfRelease('Deploy to Production') {
            def releaseTag = env.BRANCH_NAME
            def promotionTag = 'prod'

            deployDiscoveryApiTo(environment: 'prod', internal: false)

            scos.applyAndPushGitHubTag(promotionTag)

            scos.withDockerRegistry {
                image = scos.pullImageFromDockerRegistry("scos/discovery-api", env.GIT_COMMIT_HASH)
                image.push(releaseTag)
                image.push(promotionTag)
            }
        }
    }
}

def deployDiscoveryApiTo(params = [:]) {
    def environment = params.get('environment')
    if (environment == null) throw new IllegalArgumentException("environment must be specified")
    def internal = params.get('internal', true)

    scos.withEksCredentials(environment) {

        def prodCertificateARN = scos.terraformOutput('prod').tls_certificate_arn.value
        def ingressScheme = internal ? 'internal' : 'internet-facing'

        sh("""#!/bin/bash
            set -e
            source setup.sh
            export INGRESS_SCHEME=${ingressScheme}
            export ENVIRONMENT=${environment}
            export IMAGE_TAG=${env.GIT_COMMIT_HASH}

            if [ 'prod' == \$ENVIRONMENT ] ; then
              export CERTIFICATE_ARN=${prodCertificateARN}
            fi

            ./install.sh
        """.trim())
    }
}
