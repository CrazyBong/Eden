# Eden — Software Requirements Specification (SRS)

> **Project:** Autonomous Self-Evolving Software Engineer (AI SWE) — codename **Eden**
> **Version:** 1.4 | **Status:** Draft
> **Date:** 2026-02-15 | **Classification:** Internal — Confidential

---

## 1. Introduction

### 1.1 Purpose

This document defines the complete set of functional, non-functional, and interface requirements for **Eden**, an autonomous, multi-agent AI system that performs end-to-end software engineering with minimal human intervention. It serves as the binding contract between Product, Engineering, and QA and supersedes all prior requirement notes, emails, and verbal agreements.

### 1.2 Intended Audience

| Audience | Usage |
|---|---|
| Product Owners | Validate that every user need is captured |
| Engineering Leads | Plan sprints, estimate effort, and trace code to requirements |
| QA Engineers | Derive test cases from acceptance criteria |
| Security/Compliance | Verify that regulatory and infosec constraints are addressed |
| Executive Stakeholders | Assess strategic alignment and ROI potential |

### 1.3 Scope

Eden ingests a natural-language Product Requirement Document (PRD), autonomously decomposes it into engineering tasks, generates production-grade code, executes tests, manages containerized deployment, and self-corrects through Reinforcement Learning from Execution Feedback (RLEF). The initial release targets **greenfield** Python and JavaScript/TypeScript web services deployed to a sandboxed Kubernetes cluster.

### 1.4 Definitions and Acronyms

| Term | Definition |
|---|---|
| AI SWE | Autonomous Self-Evolving Software Engineer |
| RLEF | Reinforcement Learning from Execution Feedback |
| MAS | Multi-Agent System |
| DAG | Directed Acyclic Graph |
| RAG | Retrieval-Augmented Generation |
| SAST | Static Application Security Testing |
| IaC | Infrastructure as Code |
| CoT | Chain-of-Thought prompting |
| SWE-bench | Industry benchmark for evaluating software engineering agents |

---

## 2. Overall Description

### 2.1 Product Perspective

Eden is a standalone agentic platform, not an IDE plugin or a copilot. It operates as a **closed-loop autonomous system** stratified into five layers:

1. **Interaction Layer** — CLI / Web Dashboard for human intent.
2. **Orchestration Layer** — Stateful graph engine (LangGraph) managing workflow.
3. **Agent Layer** — Five specialized LLM-driven personas.
4. **Memory Layer** — Persistent semantic (ChromaDB) and episodic (SQLite) stores.
5. **Execution Layer** — Docker sandbox where code is compiled, run, and tested.

### 2.2 User Personas

#### 2.2.1 Engineering Manager — *The Supervisor*

- Oversees agent activity and team velocity via a dashboard.
- Assigns low-priority backlog tickets to the agent for off-hours execution.
- Needs clear **Cost-per-Feature** and **Autonomous Resolution Rate** metrics.

#### 2.2.2 Senior Software Architect — *The Specifier*

- Uploads architecture diagrams and PRDs.
- Expects generated code to strictly follow defined architectural patterns (Repository pattern, SOLID, etc.).
- Interacts via Markdown PRDs and the Code Review interface.

#### 2.2.3 Developer — *The Collaborator*

- Delegates tedious work: writing tests, updating docs, debugging dependency conflicts.
- Reviews agent-generated Pull Requests in the IDE or CLI.
- Expects a transparent "Thought Log" explaining the agent's reasoning.

### 2.3 Assumptions and Dependencies

| # | Assumption / Dependency |
|---|---|
| A-01 | The target hardware provides ≥ 24 GB VRAM (e.g., RTX 3090/4090) for local inference. |
| A-02 | Docker Engine 25.x is installed and operational on the host. |
| A-03 | Ollama 0.1.29+ is available for local model serving. |
| A-04 | Network egress from the sandbox is restricted to allow-listed package registries only (PyPI, npm). |
| A-05 | All development occurs in a greenfield context; brownfield/legacy codebases are excluded from Phase 1. |

### 2.4 Constraints

| # | Constraint |
|---|---|
| C-01 | **Data Privacy:** No source code or IP may leave the host machine; all inference is local. |
| C-02 | **Budget:** Compute cost per resolved feature must remain < $0.50 (electricity). |
| C-03 | **Model Size:** Foundation model is capped at 7B parameters (Qwen2.5-Coder 7B) for hardware compatibility. |
| C-04 | **Context Window:** Active context is limited to 32 K tokens per agent turn for inference speed. |

---

## 3. User Stories and Acceptance Criteria

| ID | Persona | Story | Acceptance Criteria | Priority |
|---|---|---|---|---|
| US-01 | Architect | *"I want to upload a natural-language PRD and receive a visualized Task Graph for approval."* | System parses text/markdown PRD; identifies all functional requirements; produces a DAG in JSON; renders it in the dashboard. | **P0** |
| US-02 | Developer | *"I want the agent to generate comprehensive unit tests for a given module."* | Pytest files are generated; ≥ 80 % branch coverage; tests pass inside the Docker sandbox. | **P0** |
| US-03 | Manager | *"I want the agent to autonomously detect a runtime error, fix it, and verify the fix."* | System detects error in staging; analyzes stack trace; commits fix; verifies via regression tests — zero human intervention. | **P0** |
| US-04 | Security | *"I want every generated artifact scanned for vulnerabilities before it is committed."* | Bandit + Semgrep run on all code; High/Critical findings block the commit; remediation suggestions are provided. | **P0** |
| US-05 | Developer | *"I want a transparent Thought Log explaining why the agent chose specific libraries."* | Thought Log is visible in the dashboard; each decision links back to a PRD requirement. | **P1** |
| US-06 | Manager | *"I want to assign a backlog of tickets for off-hours execution."* | Tickets are queued and executed asynchronously; results are ready for review the next morning. | **P1** |
| US-07 | Architect | *"I want the agent to generate Dockerfiles, docker-compose, and K8s manifests from my architecture."* | Files follow best practices (multi-stage builds, non-root users); services pass health checks. | **P0** |

---

## 4. Functional Requirements

### 4.1 Requirement Analysis & Task Decomposition

| ID | Requirement | Rationale |
|---|---|---|
| FR-01 | The system **shall** accept input as raw text, Markdown, or Jira ticket URLs. | Supports the three primary input channels used by the target personas. |
| FR-02 | The Planner Agent **shall** decompose each request into atomic tasks with an estimated duration ≤ 1 hour of agent time. | Keeps individual tasks within the effective reasoning window of the 7B model. |
| FR-03 | The system **shall** identify implicit requirements (e.g., "User Login" → Password Hashing, Session Management, Secure Cookie Storage). | Prevents requirement gaps that lead to incomplete implementations. |
| FR-04 | The decomposed plan **shall** be represented as a Directed Acyclic Graph (DAG) with explicit dependency edges. | Enables parallel execution of independent tasks and prevents circular deadlocks. |

### 4.2 Autonomous Code Generation

| ID | Requirement | Rationale |
|---|---|---|
| FR-05 | The system **shall** generate code compatible with **Python 3.11.7** and **Node.js 20.x**. | These represent the majority of modern web service stacks. |
| FR-06 | Dependency management **shall** be autonomous — the agent detects missing imports and updates `requirements.txt` / `package.json`. | Eliminates manual dependency resolution, a common source of developer friction. |
| FR-07 | Generated code **shall** adhere to SOLID principles, PEP 8 (Python), and ESLint standards (JS/TS). | Ensures maintainability and reduces technical debt from day one. |
| FR-08 | The agent **shall not** emit placeholder comments (e.g., `# TODO: implement`). All output must be fully functional. | Placeholder output has no production value and inflates apparent progress. |

### 4.3 Self-Correction via RLEF

| ID | Requirement | Rationale |
|---|---|---|
| FR-09 | Upon test failure, the full stack trace and error message **shall** be injected into the Implementation Agent's context window. | Provides the agent with the same diagnostic information a human debugger would use. |
| FR-10 | Before attempting a fix, the agent **shall** emit a structured **Diagnosis** section explaining the root cause hypothesis. | Enables human auditors to evaluate reasoning quality and catch flawed logic early. |
| FR-11 | The system **shall** support a configurable `MAX_RETRIES` (default: **5**). After exhaustion, the task is marked `FAILED` and escalated. | Circuit-breaker prevents infinite loops and runaway token consumption. |
| FR-12 | Successful fixes **shall** be persisted to Episodic Memory with the error signature, diagnosis, and resolution strategy. | Builds a project-specific knowledge base that prevents repetition of solved problems. |

### 4.4 Test-Driven Verification

| ID | Requirement | Rationale |
|---|---|---|
| FR-13 | The Test Agent **shall** generate Pytest suites covering happy paths, negative inputs, and edge cases. | Comprehensive coverage catches regressions that a human might overlook under time pressure. |
| FR-14 | Tests **shall** execute inside the Docker sandbox; results are structured (pass/fail/coverage %). | Sandbox execution prevents side-effects on the host; structured output enables automated decision routing. |
| FR-15 | A failing test **shall** produce a structured Bug Report (input, expected, actual, stack trace) fed back to the Implementation Agent. | Standardized reports reduce ambiguity and accelerate the fix cycle. |

### 4.5 Infrastructure as Code & Deployment

| ID | Requirement | Rationale |
|---|---|---|
| FR-16 | The system **shall** generate `Dockerfile`, `docker-compose.yml`, and Kubernetes manifests (Deployment, Service, Ingress). | Full IaC ownership eliminates the DevOps handoff bottleneck. |
| FR-17 | Docker Compose **shall** be used to provision dependent services (e.g., PostgreSQL) for integration testing. | Realistic integration tests require realistic infrastructure. |
| FR-18 | Deployed containers **shall** be verified via `docker ps` status checks and HTTP health probes (`/health`). | Automated health verification closes the deploy → validate loop without human SSH sessions. |

### 4.6 Security & Code Review

| ID | Requirement | Rationale |
|---|---|---|
| FR-19 | The Reviewer Agent **shall** execute Bandit (Python SAST) and Semgrep (policy enforcement) on every code artifact. | Deterministic scanning compensates for the probabilistic nature of LLM output. |
| FR-20 | Any finding with severity ≥ **Medium** **shall** block the commit. | "Deny-by-default" policy prevents vulnerable code from reaching the repository. |
| FR-21 | The system **shall** enforce environment-variable–based secret management; hardcoded secrets trigger an automatic rejection. | Prevents credential leakage — a top OWASP risk. |

---

## 5. Non-Functional Requirements

### 5.1 Performance

| ID | Requirement | Target | Rationale |
|---|---|---|---|
| NFR-01 | Local inference throughput (Ollama + Qwen 7B) | ≥ 30 tokens/sec on 24 GB VRAM GPU | Keeps the feedback loop tight; slower throughput degrades the RLEF cycle. |
| NFR-02 | End-to-end Mean Time to Resolution (MTTR) | < 10 min for standard features | Matches the goal of radical SDLC compression. |
| NFR-03 | Parallel task execution | Orchestrator must run independent DAG branches concurrently | Maximizes throughput without linear human-attention constraint. |

### 5.2 Scalability

| ID | Requirement | Target |
|---|---|---|
| NFR-04 | Context compaction | Older conversation turns summarized to keep active window ≤ 32 K tokens. |
| NFR-05 | Memory growth | Episodic + Semantic memory must support ≥ 10,000 events and ≥ 50,000 code chunks without degradation. |

### 5.3 Security

| ID | Requirement | Target |
|---|---|---|
| NFR-06 | **Sandbox isolation** | All generated code runs in ephemeral Docker containers with no host or public-internet egress (except allow-listed registries). |
| NFR-07 | **Semantic Firewall** | A lightweight classifier inspects all agent outputs before execution, blocking jailbreak attempts, system-prompt exfiltration, and dangerous shell commands. |
| NFR-08 | **Least-privilege execution** | Agent processes run as non-root inside containers. |
| NFR-09 | **Ephemeral credentials** | Any API keys or DB credentials used by agents are short-lived and scoped to the current task. |

### 5.4 Observability & Auditability

| ID | Requirement | Target |
|---|---|---|
| NFR-10 | **Thought Log (Glass Box)** | Real-time visualization of agent reasoning on the Web Dashboard. |
| NFR-11 | **Immutable Audit Trail** | Every file edit, shell command, and tool invocation logged to SQLite with timestamp, agent ID, and triggering prompt. |
| NFR-12 | **Tracing** | Integration with LangSmith or Arize Phoenix for chain-of-thought replay and latency profiling. |

### 5.5 Reliability

| ID | Requirement | Target |
|---|---|---|
| NFR-13 | Circuit breaker on retry loops | Hard limit of `MAX_RETRIES` (default 5); exceeded tasks escalate to human. |
| NFR-14 | Graceful degradation | If inference latency exceeds 2× baseline, the orchestrator pauses new task dispatch and alerts the operator. |

### 5.6 Usability

| ID | Requirement | Target |
|---|---|---|
| NFR-15 | CLI interaction | Developers can submit tasks, check status, and review output from the terminal. |
| NFR-16 | Web Dashboard | Managers and Architects can view task graphs, agent activity, cost metrics, and Thought Logs. |

---

## 6. Success Metrics (KPIs)

| Metric | Definition | Target |
|---|---|---|
| **Autonomous Resolution Rate (ARR)** | % of tasks completed with zero human intervention | > 80 % (routine tasks) |
| **Self-Correction Rate (SCR)** | % of self-introduced bugs the agent repairs autonomously | > 60 % |
| **SWE-bench Lite Score** | Pass rate on the industry standard benchmark | > 25 % |
| **Cost per Resolution** | Average compute cost to resolve one feature | < $0.50 |
| **Mean Time to Resolution (MTTR)** | Elapsed time from prompt to deployed, passing service | < 10 minutes |
| **Test Coverage** | Branch coverage of agent-generated test suites | ≥ 80 % |

---

## 7. Interface Requirements

### 7.1 User Interfaces

| Interface | Description |
|---|---|
| **CLI** | Primary developer interface; accepts PRDs, displays progress, and streams Thought Logs. |
| **Web Dashboard** | Visual management console showing task DAGs, agent status, cost metrics, and audit logs. |

### 7.2 System Interfaces

| Interface | Protocol | Purpose |
|---|---|---|
| Ollama API | HTTP (OpenAI-compatible) | Local LLM inference |
| Docker Engine API | Unix socket / REST | Container lifecycle management |
| ChromaDB | HTTP REST | Semantic memory read/write |
| SQLite | File I/O (SQLModel ORM) | Episodic memory read/write |
| Bandit / Semgrep | CLI subprocess | SAST scanning |
| Pytest | CLI subprocess | Test execution and coverage |
| Kubernetes API | HTTPS | Deployment orchestration (Phase 2+) |

### 7.3 Data Interfaces

| Data Flow | Format | Direction |
|---|---|---|
| PRD Ingestion | Text / Markdown / JSON | User → System |
| Task Graph | JSON (DAG) | System → User (for approval) |
| Code Artifacts | Python / JS / TS source files | System → Repository |
| Test Reports | Structured JSON | Test Agent → Orchestrator |
| Audit Logs | SQLite rows | System → Dashboard |

---

## 8. Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | **Hallucinated code** — agent invents non-existent APIs or libraries | High | High | Strict RAG retrieval before API usage; immediate RLEF compiler/test feedback |
| R-02 | **Infinite retry loops** — agent repeats the same failed fix | Medium | Medium | Circuit breaker (`MAX_RETRIES`); diversity sampling forces a new approach after 2 consecutive failures |
| R-03 | **Sandbox escape / data exfiltration** | Low | Critical | Network isolation; Semantic Firewall; least-privilege non-root execution |
| R-04 | **Context window exhaustion** — long sessions degrade reasoning | High | Medium | Context compaction; offload storage to vector DB; retrieve only relevant chunks |
| R-05 | **Model capacity** — 7B parameters insufficient for complex architectural reasoning | Medium | High | Hierarchical planning decomposes tasks into atomic units manageable by the 7B model |
| R-06 | **Cost overrun** — runaway token consumption in multi-agent debates | Medium | Medium | Per-task budget caps; tiered model routing; token velocity monitoring |
| R-07 | **Prompt injection** — adversarial input manipulates agent behavior | Low | High | Semantic Firewall; input sanitization; output policy enforcement |

---

## 9. Out-of-Scope (Phase 1)

To maintain focus and manage risk, the following are **explicitly excluded** from the initial release:

- **Legacy / Brownfield Codebases** — navigating large undocumented monoliths requires context-window research beyond current scope.
- **Creative UI/UX Design** — the agent uses component libraries (Material UI, Tailwind) but does not perform subjective visual design.
- **Production Deployment** — all deployments target a sandboxed cluster; production release requires additional governance.
- **Voice / Video / Multimodal Input** — text and code are the sole input modalities.
- **Hardware & Embedded Systems** — scope is limited to cloud-native software.
- **Production Data Access** — the agent operates on synthetic data only; no real PII or customer databases.

---

## 10. Traceability Matrix

| User Story | Functional Reqs | Non-Functional Reqs | KPI |
|---|---|---|---|
| US-01 (PRD Ingestion) | FR-01, FR-02, FR-03, FR-04 | NFR-15, NFR-16 | ARR |
| US-02 (Test Generation) | FR-13, FR-14, FR-15 | NFR-01 | Test Coverage, SCR |
| US-03 (Autonomous Bug Fix) | FR-09, FR-10, FR-11, FR-12 | NFR-13, NFR-14 | ARR, SCR, MTTR |
| US-04 (Vuln Scan) | FR-19, FR-20, FR-21 | NFR-06, NFR-07, NFR-08 | — |
| US-05 (Thought Log) | FR-10 | NFR-10, NFR-11 | — |
| US-06 (Off-Hours Execution) | FR-01, FR-02 | NFR-03, NFR-14 | ARR, Cost |
| US-07 (IaC Generation) | FR-16, FR-17, FR-18 | NFR-06 | MTTR |

---

## 11. Document Approval

| Role | Name | Date | Signature |
|---|---|---|---|
| Product Owner |Shubhranshu Das | 2026-02-10 |Shubhranshu Das |
| Engineering Lead |Shubhranshu Das | 2026-02-11 |Shubhranshu Das |
| Security Lead |Chandra Prakash Ojha| 2026-02-11 |Chandra Prakash Ojha|
| QA Lead |Chandra Prakash Ojha| 2026-02-12 |Chandra Prakash Ojha|

---

*This document is maintained under version control. All modifications require a formal Change Request approved by the Engineering Lead and Product Owner.*
