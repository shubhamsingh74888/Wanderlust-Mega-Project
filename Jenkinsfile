@Library('Shared') _

wanderlustPipeline(
  projectName        : 'wanderlust',
  gitRepoUrl         : 'https://github.com/shubhamsingh74888/Wanderlust-Mega-Project.git',
  gitopsRepoUrl      : 'https://github.com/shubhamsingh74888/wanderlust-gitops.git',

  registryNamespace  : 'shubham74888',
  imageFrontend      : 'shubham74888/wanderlust-frontend',
  imageBackend       : 'shubham74888/wanderlust-backend',

  frontendDir        : 'frontend',
  backendDir         : 'backend',
  k8sManifestsDir    : 'kubernetes',    // pipelineDeploy appends /production

  dockerCredId       : 'docker',
  gitCredId          : 'github',
  nvdApiKeyId        : 'NVD_API_KEY',

  sonarServerName    : 'sonar-server',
  sonarProjectKey    : 'sonar',

  slackChannel       : '#wanderlust-cicd',
  slackCredId        : 'slack-token',

  timeoutMinutes     : 60,
  trivyExitCode      : 0,
  qualityGateWait    : true
)
