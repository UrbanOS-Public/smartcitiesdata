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
        def terraformOutputs = scos.terraformOutput(environment)
        def subnets = terraformOutputs.public_subnets.value.join(', ')
        def allowInboundTrafficSG = terraformOutputs.allow_all_security_group.value
        def certificateARN = terraformOutputs.tls_certificate_arn.value

        def ingressScheme = internal ? 'internal' : 'internet-facing'
        sh("""#!/bin/bash
            set -e
            export VERSION="${env.GIT_COMMIT_HASH}"
            export DNS_ZONE="${environment}.internal.smartcolumbusos.com"
            export SUBNETS="${subnets}"
            export SECURITY_GROUPS="${allowInboundTrafficSG}"
            export INGRESS_SCHEME="${ingressScheme}"
            export CERTIFICATE_ARN="${certificateARN}"

            helm init --client-only
            helm upgrade --install discovery-api ./chart \
                --set ingress.scheme="\${INGRESS_SCHEME}" \
                --set ingress.subnets="\${SUBNETS//,/\\\\,}" \
                --set ingress.security_groups="\${SECURITY_GROUPS}" \
                --set ingress.dns_zone="\${DNS_ZONE}" \
                --set ingress.certificate_arn="\${CERTIFICATE_ARN}" \
                --set image.tag="\${VERSION}" \
                --timeout=600 \
                --wait
        """.trim())

    }
}
