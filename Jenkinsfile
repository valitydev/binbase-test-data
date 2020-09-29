#!groovy
build("binbase-test-data", "docker-host") {

    def registry = "dr2.rbkmoney.com"
    def registryCredsId = "jenkins_harbor"

    runStage("git checkout") {
        withGithubSshCredentials {
            def opts = env.CHANGE_BRANCH != null ? "--single-branch --branch ${env.CHANGE_BRANCH}" : ""
            sh "git clone ${opts} --depth 1 git@github.com:rbkmoney/${env.REPO_NAME}.git ${env.WORKSPACE}"
            dir(env.WORKSPACE) {
                getCommitId()
            }
        }
    }

    runStage("Build local service docker image") {
        def imgShortName = "rbkmoney/${env.REPO_NAME}:${env.COMMIT_ID}"
        docker.withRegistry("https://${registry}/v2/", registryCredsId) {
            def serviceImage = docker.build(imgShortName, ".")
            try {
                if (env.BRANCH_NAME == 'master' || env.BRANCH_NAME.startsWith('epic')) {
                    runStage("Push service docker image to rbkmoney docker registry") {
                        serviceImage.push()
                        sh "docker rmi ${registry}/${imgShortName}"
                    }
                }
            } finally {
                runStage("Remove local docker image") {
                    // Remove the image to keep Jenkins runner clean.
                    sh "docker rmi ${imgShortName}"
                }
            }
        }
    }

}
