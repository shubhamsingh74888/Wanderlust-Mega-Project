// ============================================================
//  Jenkinsfile  →  place in: Wanderlust-Mega-Project/Jenkinsfile
//
//  CI Pipeline — delegates ALL stages to the shared library.
//  This file is intentionally thin: all logic lives in shared-lib.
//
//  TRIGGER: GitHub Webhook or Poll SCM (H/5 * * * *)
//           on Wanderlust-Mega-Project repo → main branch
//
//  WHAT IT DOES (via shared-lib/vars/wanderlustPipeline.groovy):
//    01 · Pipeline Init      — validate tools + credentials
//    02 · Source Checkout    — shallow clone, capture git metadata
//    03 · Install Deps       — npm install (frontend + backend, parallel)
//    03.5 · NPM Audit Fix    — auto-fix known vulnerabilities
//    04 · Unit Tests         — jest tests (frontend + backend, parallel)
//    05 · SonarQube SAST     — static code analysis
//    06 · Quality Gate       — pass/fail gate
//    07 · SCA + Trivy FS     — OWASP dependency check + Trivy filesystem scan
//    08 · Docker Build       — build frontend + backend images (parallel)
//    09 · Trivy Image Scan   — scan built images for CVEs
//    10 · Push to DockerHub  — push tagged + latest images
//    11 · GitOps Update      — clone wanderlust-gitops, sed image tags,
//                              commit + push → ArgoCD auto-syncs
//
//  CREDENTIAL IDs (must match Jenkins Manage Credentials exactly):
//    docker        → Username/Password  (DockerHub user + token)
//    github        → Username/Password  (GitHub token)
//    NVD_API_KEY   → Secret Text        (NVD API key for OWASP)
//    slack-token   → Secret Text        (Slack bot token)
//
//  JENKINS TOOLS (must be configured in Global Tool Configuration):
//    sonar-scanner → SonarQube Scanner installation
//    node-21       → NodeJS 21 (optional — pipeline uses Docker for npm)
//
//  SHARED LIBRARY (must be configured in Jenkins):
//    Name: Shared
//    Default version: main
//    Retrieval method: Modern SCM → GitHub
//    URL: https://github.com/shubhamsingh74888/shared-lib.git
//    Credentials: github
// ============================================================

@Library('Shared') _

wanderlustPipeline(
  // ── Project Identity ─────────────────────────────────
  projectName        : 'wanderlust',
  gitRepoUrl         : 'https://github.com/shubhamsingh74888/Wanderlust-Mega-Project.git',
  gitopsRepoUrl      : 'https://github.com/shubhamsingh74888/wanderlust-gitops.git',

  // ── Docker Registry ───────────────────────────────────
  // DockerHub namespace — images will be pushed as:
  //   shubham74888/wanderlust-frontend:frontend-b<N>
  //   shubham74888/wanderlust-backend:backend-b<N>
  registryNamespace  : 'shubham74888',
  imageFrontend      : 'shubham74888/wanderlust-frontend',
  imageBackend       : 'shubham74888/wanderlust-backend',

  // ── Source Directories ────────────────────────────────
  // Relative to repo root — must match actual folder names
  frontendDir        : 'frontend',
  backendDir         : 'backend',

  // ── GitOps Manifests Path ─────────────────────────────
  // pipelineDeploy.gitopsUpdate appends /production to this path.
  // Resolves to: kubernetes/production/frontend.yaml
  //                             and: kubernetes/production/backend.yaml
  // This matches your wanderlust-gitops repo structure exactly.
  k8sManifestsDir    : 'kubernetes',

  // ── Credential IDs ───────────────────────────────────
  dockerCredId       : 'docker',
  gitCredId          : 'github',
  nvdApiKeyId        : 'NVD_API_KEY',

  // ── SonarQube ─────────────────────────────────────────
  // sonarServerName must match the name in:
  //   Jenkins > Configure System > SonarQube Servers
  sonarServerName    : 'sonar-server',
  sonarProjectKey    : 'sonar',

  // ── Slack Notifications ───────────────────────────────
  slackChannel       : '#wanderlust-cicd',
  slackCredId        : 'slack-token',

  // ── Pipeline Behaviour ────────────────────────────────
  timeoutMinutes     : 60,
  trivyExitCode      : 0,      // 0 = warn only; 1 = fail on HIGH/CRITICAL
  qualityGateWait    : true
)
