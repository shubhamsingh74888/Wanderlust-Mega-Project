// ============================================================
//  Wanderlust · Main Pipeline Entry Point
//  All logic lives in the Shared Library → @Library('Shared')
//  This file should never exceed ~30 lines.
// ============================================================
@Library('Shared') _

wanderlustPipeline(
  // ── Project Identity ──────────────────────────────────
  projectName        : 'wanderlust',
  gitRepoUrl         : 'https://github.com/shubhamsingh74888/Wanderlust-Mega-Project.git',
  gitopsRepoUrl      : 'https://github.com/shubhamsingh74888/Wanderlust-Mega-Project.git',

  // ── Registry ──────────────────────────────────────────
  registryNamespace  : 'shubham74888',
  imageFrontend      : 'shubham74888/wanderlust-frontend',
  imageBackend       : 'shubham74888/wanderlust-backend',

  // ── Source Layout ─────────────────────────────────────
  frontendDir        : 'frontend',
  backendDir         : 'backend',
  k8sManifestsDir    : 'kubernetes',

  // ── Jenkins Credential IDs ────────────────────────────
  dockerCredId       : 'dockerhub-creds',
  gitCredId          : 'github-token',
  nvdApiKeyId        : 'nvd-api-token',

  // ── SonarQube ─────────────────────────────────────────
  sonarServerName    : 'sonar-server',
  sonarProjectKey    : 'Wanderlust-Core',

  // ── Notifications ─────────────────────────────────────
  slackChannel       : '#wanderlust-cicd',
  slackCredId        : 'slack-token',

  // ── Pipeline Behaviour ────────────────────────────────
  timeoutMinutes     : 60,
  trivyExitCode      : 0,     // set 1 to hard-fail on CRITICAL
  qualityGateWait    : true
)
