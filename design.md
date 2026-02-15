# Eden — System Design Document (SDD)

> **Project:** Autonomous Self-Evolving Software Engineer (AI SWE) — codename **Eden**
> **Version:** 1.4 | **Status:** Draft
> **Date:** 2026-02-15 | **Classification:** Internal — Confidential
> **Companion Document:** [`requirements.md`](file:///c:/Users/Lenovo/Eden/requirements.md)

---

## 1. Design Goals and Principles

| # | Principle | Rationale |
|---|---|---|
| P-01 | **Agent-Centric, Human-Supervised** | The system owns the inner loop (code → test → fix); humans own intent and review. |
| P-02 | **Closed-Loop Autonomy** | Every output is verified by execution feedback — no "fire-and-forget" generation. |
| P-03 | **Defense in Depth** | Security is layered: sandboxing → semantic firewall → SAST → audit trail. |
| P-04 | **Modular Multi-Agent** | Each agent is a replaceable, independently testable unit with a single responsibility. |
| P-05 | **Local-First Privacy** | All inference runs on-premises; zero source code leaves the host. |
| P-06 | **Fail-Safe over Fail-Open** | Unresolved failures escalate to humans; the system never silently deploys broken code. |

---

## 2. High-Level Architecture

The system is organized into **five horizontal layers**, each with well-defined responsibilities and interfaces.

```
┌──────────────────────────────────────────────────────────────┐
│                    INTERACTION LAYER                         │
│              CLI  ·  Web Dashboard  ·  API                   │
├──────────────────────────────────────────────────────────────┤
│                 ORCHESTRATION LAYER                          │
│          LangGraph StateGraph (Control Plane)                │
│     ┌──────────┐    ┌─────────┐    ┌──────────────┐         │
│     │  Router   │───▶│ Scheduler│───▶│ Circuit      │        │
│     │  (Task    │    │ (DAG    │    │ Breaker      │         │
│     │  Dispatch)│    │ Walker) │    │ (Max Retries)│         │
│     └──────────┘    └─────────┘    └──────────────┘         │
├──────────────────────────────────────────────────────────────┤
│                      AGENT LAYER                            │
│  ┌─────────┐ ┌──────┐ ┌──────┐ ┌──────────┐ ┌─────────┐   │
│  │ Planner │ │Coder │ │Tester│ │ Reviewer │ │ Runtime │    │
│  │ Agent   │ │Agent │ │Agent │ │ Agent    │ │ Agent   │    │
│  └─────────┘ └──────┘ └──────┘ └──────────┘ └─────────┘   │
├──────────────────────────────────────────────────────────────┤
│                     MEMORY LAYER                            │
│      ┌────────────────┐      ┌────────────────┐            │
│      │ Semantic Memory │      │ Episodic Memory │           │
│      │ (ChromaDB)      │      │ (SQLite)        │           │
│      └────────────────┘      └────────────────┘            │
├──────────────────────────────────────────────────────────────┤
│                    EXECUTION LAYER                          │
│     Docker Sandbox  ·  Pytest Runner  ·  K8s Cluster        │
└──────────────────────────────────────────────────────────────┘
```

### 2.1 Layer Responsibilities

| Layer | Responsibility | Key Constraint |
|---|---|---|
| **Interaction** | Receives user intent; renders progress and results | Stateless — all state lives in the Orchestration layer |
| **Orchestration** | Maintains global project state; routes tasks; enforces retry limits | Single source of truth for task graph and agent state |
| **Agent** | Executes bounded, specialized sub-tasks using LLM reasoning + tools | Each agent is stateless per invocation; context is injected from Memory |
| **Memory** | Provides persistent context across sessions and agent turns | Dual-store: vector (semantic) + relational (episodic) |
| **Execution** | Runs generated code in isolated containers; returns deterministic feedback | Ephemeral containers; no host access; network-restricted |

---

## 3. Technology Stack

| Component | Technology | Version | Justification |
|---|---|---|---|
| **Foundation Model** | Qwen2.5-Coder 7B | — | SOTA coding benchmarks (HumanEval, MBPP) at 7B scale; 128 K context window; local inference eliminates IP leakage risk. |
| **Inference Engine** | Ollama | ≥ 0.1.29 | OpenAI-compatible API; production-grade local serving; zero per-token cost. |
| **Orchestrator** | LangGraph | ≥ 0.0.58 | Cyclic state graphs enable the Test→Fix→Test loop impossible with linear chains. |
| **Semantic Memory** | ChromaDB | ≥ 0.4.22 | Open-source vector DB optimized for AI; supports hybrid search (keyword + semantic). |
| **Episodic Memory** | SQLite + SQLModel | — | Lightweight relational store; Pythonic ORM; SQL-queryable audit trail. |
| **Sandbox** | Docker Engine | ≥ 25.x | Hard process isolation; ephemeral containers; per-task resource limits. |
| **Container Orchestration** | Kubernetes | — | Realistic distributed-systems testing (service discovery, scaling, ingress). |
| **Testing** | Pytest | — | Python standard; rich plugin ecosystem; structured output for parsing. |
| **Security Scanning** | Bandit + Semgrep | — | Deterministic SAST; Bandit for Python vulns, Semgrep for custom policy rules. |
| **Observability** | LangSmith / Arize Phoenix | — | Chain-of-thought tracing, latency profiling, reasoning-failure forensics. |
| **Metrics** | Prometheus + Grafana | — | Runtime monitoring feeds the Runtime Agent's self-healing loop. |
| **GitOps** | ArgoCD (or Git workflow) | — | Ensures version-controlled, reversible deployments; agent never deploys directly. |

---

## 4. Orchestration Engine (LangGraph Control Plane)

### 4.1 State Schema

The global state object flows through every node in the graph. Each agent reads from and writes to this shared structure:

```python
class AgentState(TypedDict):
    project_id: str                # Unique session identifier
    requirements: str              # Original user prompt / PRD
    plan: List[Task]               # DAG of decomposed tasks
    current_task: Task             # Active task being executed
    code_context: Dict[str, str]   # File path → source content
    test_results: TestResult       # Latest test execution outcome
    error_logs: List[str]          # Stack traces from recent failures
    iteration_count: int           # Retry counter (circuit-breaker input)
    memory_retrieval: List[str]    # Context fetched from ChromaDB
```

### 4.2 Workflow State Machine

```
                    ┌─────────┐
          ┌────────▶│ PLANNER │
          │         └────┬────┘
          │              │ plan ready
          │              ▼
          │         ┌─────────┐
          │         │  CODER  │◀──────────────┐
          │         └────┬────┘               │
          │              │ code written        │
          │              ▼                     │
          │         ┌─────────┐               │
          │         │ TESTER  │               │
          │         └────┬────┘               │
          │              │                     │
          │         ┌────▼─────┐              │
          │         │  DECIDE  │              │
          │         └──┬────┬──┘              │
          │    PASS     │    │  FAIL           │
          │            ▼    │  (count < MAX)   │
          │      ┌──────────┐    │             │
          │      │ REVIEWER │    └─────────────┘
          │      └────┬─────┘
          │           │
          │     ┌─────▼──────┐
          │     │  COMMITTED │
          │     └────────────┘
          │
  FAIL (count ≥ MAX)
          │
    ┌─────▼──────────┐
    │ HUMAN ESCALATION│
    └────────────────┘
```

### 4.3 Conditional Edge Logic

```python
def check_test_results(state: AgentState) -> str:
    if state["test_results"].passed:
        return "reviewer"                       # Green path → review gate
    if state["iteration_count"] >= MAX_RETRIES:
        return "human_escalation"               # Circuit breaker
    state["iteration_count"] += 1
    return "coder"                              # Feedback loop → retry
```

### 4.4 Key Orchestration Rules

| Rule | Description |
|---|---|
| **Parallel Dispatch** | Independent DAG branches are scheduled concurrently (NFR-03). |
| **Circuit Breaker** | `MAX_RETRIES` (default 5) hard-stops retry loops (FR-11). |
| **Diversity Sampling** | After 2 consecutive identical failures, the orchestrator forces a different plan variant. |
| **Context Injection** | Before each agent invocation, the orchestrator retrieves relevant chunks from ChromaDB and recent Episodic events from SQLite. |

---

## 5. Agent Specifications

### 5.1 Planner Agent — *The Architect*

| Attribute | Detail |
|---|---|
| **Objective** | Translate ambiguous requirements into a structured, dependency-aware task graph. |
| **System Prompt** | *"You are a Senior Software Architect. Decompose the requirement into atomic, interdependent tasks. Identify circular dependencies. Output a DAG in JSON."* |
| **Tools** | `search_docs(query)` — RAG over ChromaDB; `read_file(path)` — inspect existing code for consistency. |
| **Output** | `plan.json` — array of `Task` objects with `id`, `description`, `dependencies[]`, `estimated_minutes`. |
| **Does NOT** | Write implementation code. It sets constraints for downstream agents. |

### 5.2 Implementation Agent — *The Coder*

| Attribute | Detail |
|---|---|
| **Objective** | Execute a single bounded task: produce fully functional, typed, documented code. |
| **System Prompt** | *"You are an expert Polyglot Developer. Write clean, typed, documented code adhering to SOLID principles. No placeholders. Full implementation only."* |
| **Tools** | `write_file(path, content)`; `list_dir(path)`; `run_syntax_check(path)`. |
| **Loop** | Operates in a Thought → Action → Observation cycle, reasoning before writing. |
| **Statelessness** | Receives all context from the Orchestrator; does not persist its own state. |

### 5.3 Test Agent — *The QA Engineer*

| Attribute | Detail |
|---|---|
| **Objective** | Adversarial verification — break the code written by the Coder. |
| **System Prompt** | *"You are a QA Automation Engineer. Generate comprehensive Pytest suites. Cover happy paths, negative inputs, edge cases, and boundary conditions."* |
| **Tools** | `run_test(path)` — execute Pytest in Docker; `parse_coverage(path)` — extract coverage %. |
| **Output on Failure** | Structured Bug Report: `{ input, expected, actual, stack_trace }` → fed to Implementation Agent. |
| **Adversarial Incentive** | Rewarded for finding bugs, encouraging thoroughness over superficial passes. |

### 5.4 Reviewer Agent — *The Gatekeeper*

| Attribute | Detail |
|---|---|
| **Objective** | Final quality and security gate before code is committed. |
| **System Prompt** | *"You are a Security Auditor and Senior Code Reviewer. Analyze for OWASP Top 10 vulnerabilities, performance bottlenecks, and style violations."* |
| **Tools** | `run_bandit(path)`; `run_semgrep(path)`; `check_style(path)` — Black/Prettier. |
| **Policy** | **Deny by Default** — any finding with severity ≥ Medium blocks the commit. |
| **Hybrid Design** | Combines LLM reasoning (logic errors, hallucinations) with deterministic static analysis (Bandit, Semgrep). |

### 5.5 Runtime Agent — *The SRE*

| Attribute | Detail |
|---|---|
| **Objective** | Post-deployment monitoring and self-healing. |
| **System Prompt** | *"You are an SRE. Monitor logs and metrics. If a crash or latency spike occurs, correlate with recent changes and trigger rollback or fix."* |
| **Tools** | `read_logs(container_id)`; `restart_service(name)`; `query_metrics()`. |
| **Self-Healing** | Detects OOM / crash → correlates with recent deployment → spawns fix task for Planner + Coder. |

---

## 6. Memory Architecture

### 6.1 Dual-Memory Design

```
┌──────────────────────────────────────────────────┐
│                  AGENT LAYER                     │
│                                                  │
│   "What pattern should I use?" ──────────────┐   │
│   "Have I seen this error before?" ──────┐   │   │
│                                          │   │   │
│                                          ▼   ▼   │
│         ┌──────────────┐    ┌──────────────┐     │
│         │   Episodic   │    │   Semantic   │     │
│         │   Memory     │    │   Memory     │     │
│         │  (SQLite)    │    │  (ChromaDB)  │     │
│         └──────────────┘    └──────────────┘     │
│          "What I did"        "What I know"       │
└──────────────────────────────────────────────────┘
```

### 6.2 Episodic Memory — *The Black-Box Recorder*

Stores the chronological history of every agent action, enabling the system to avoid repeating past mistakes.

**Schema:**

```python
class AgentEvent(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    session_id: str
    timestamp: datetime
    agent_role: str           # "planner" | "coder" | "tester" | "reviewer" | "runtime"
    action: str               # "EditFile" | "RunTest" | "RunShell" | ...
    input_context: str        # Prompt provided to the agent
    output_content: str       # Agent's response
    outcome: str              # "Success" | "Failure" | "Error"
    error_signature: str      # Hash of the stack trace (for dedup)
    duration_ms: int
```

**Query Example — Prevent Repetitive Mistakes:**

```sql
SELECT * FROM agentlog
WHERE error_signature = :current_error_hash
  AND outcome = 'Success'
ORDER BY timestamp DESC
LIMIT 1;
```

### 6.3 Semantic Memory — *The Knowledge Base*

A vector store containing embeddings of the codebase, library documentation, and learned solutions.

**Collections:**

| Collection | Content | Use Case |
|---|---|---|
| `codebase_v1` | Chunked embeddings of every project file | "Where is the auth logic defined?" |
| `docs_v1` | Official library docs (FastAPI, React, Pydantic) | Grounding — reduces hallucination of non-existent APIs |
| `solutions_v1` | Summarized successful bug-fix trajectories | RAG retrieval when encountering similar error signatures |

**Metadata Schema:**

```json
{
  "file_path": "src/auth/router.py",
  "language": "python",
  "type": "function",
  "name": "login_user",
  "dependencies": ["users_db", "jwt_handler"],
  "last_modified": "2026-02-15"
}
```

### 6.4 RLEF Reward Signal

The heuristic reward function grounds the agent in execution reality:

| Outcome | Reward | Signal |
|---|---|---|
| Code compiles + all tests pass + security scan clean | **+1.0** | Full success |
| Code compiles + tests pass + lint/style failures | **+0.5** | Functional but needs polish |
| Code compiles + tests fail | **−0.5** | Logic error |
| Code fails to compile (syntax error) | **−1.0** | Fundamental failure |

Successful trajectories are weighted higher during RAG retrieval from Semantic Memory, creating a **self-improvement flywheel** — the system gets smarter the more it is used.

---

## 7. Execution Environment (Sandbox)

### 7.1 Container Security Model

Every code-generation task runs inside an **ephemeral Docker container** with the following constraints:

| Control | Configuration | Purpose |
|---|---|---|
| **Network Policy** | Deny all egress except allow-listed registries (PyPI, npm) | Prevent data exfiltration and supply-chain attacks |
| **Resource Limits** | CPU: 2 cores; RAM: 4 GB; Disk: ephemeral only | Prevent resource exhaustion / DoS |
| **User** | Non-root (`USER 1000`) | Limit blast radius of any container escape |
| **Lifecycle** | Container destroyed immediately after task completion | No persistent malware or compromised state survives between tasks |

### 7.2 Semantic Firewall

A lightweight classifier sits between the Agent Layer and the Execution Layer:

```
Agent Output ──▶ [Semantic Firewall] ──▶ Docker Exec
                      │
                      ├── Scan for shell injection (rm -rf, curl to unknown hosts)
                      ├── Detect system-prompt exfiltration attempts
                      └── Block requests to non-allow-listed APIs
```

Outputs that fail the firewall are rejected and logged to the Audit Trail.

### 7.3 GitOps Deployment Flow

```
Agent commits code ──▶ Git Repository ──▶ ArgoCD sync ──▶ K8s Cluster
                                │
                                └── Full version history; every change reversible
```

The agent **never** deploys directly. ArgoCD (or equivalent) reconciles the desired state from Git, ensuring auditability and rollback capability.

---

## 8. Data Flow — End-to-End Sequence

```
 User                Orchestrator        Planner    Coder     Tester    Reviewer
  │                       │                │          │          │          │
  │── PRD (markdown) ────▶│                │          │          │          │
  │                       │── decompose ──▶│          │          │          │
  │                       │◀── plan.json ──│          │          │          │
  │◀── DAG for approval ──│                │          │          │          │
  │── approve ───────────▶│                │          │          │          │
  │                       │── task[0] ────────────────▶│          │          │
  │                       │◀── code files ────────────│          │          │
  │                       │── run tests ──────────────────────▶│          │
  │                       │◀── FAIL + stack trace ────────────│          │
  │                       │ (iteration_count < MAX)            │          │
  │                       │── error context ──────────▶│          │          │
  │                       │◀── patched code ──────────│          │          │
  │                       │── re-run tests ───────────────────▶│          │
  │                       │◀── PASS ──────────────────────────│          │
  │                       │── security scan ──────────────────────────▶│
  │                       │◀── CLEAN ─────────────────────────────────│
  │                       │── commit to Git ──────────────────────────│
  │◀── PR ready for review│                │          │          │          │
```

---

## 9. Context Management Strategy

Large-context conversations degrade LLM reasoning ("Lost-in-the-Middle"). Eden mitigates this with a three-tier context strategy:

| Tier | Scope | Mechanism | Token Budget |
|---|---|---|---|
| **Active Context** | Current task + recent error logs | Directly in the prompt | ≤ 32 K tokens |
| **Warm Context** | Completed tasks from the current session | Summarized to key takeaways; stored in Episodic Memory | Retrieved on demand |
| **Cold Context** | Historical sessions, codebase, documentation | Vector-indexed in ChromaDB; retrieved via RAG | Top-K relevant chunks |

**Compaction Rule:** When `active_context_tokens > 28K`, the orchestrator triggers automatic summarization of the oldest conversation turns before the next agent invocation.

---

## 10. Observability & Debugging

### 10.1 Thought Log (Glass Box)

Every agent invocation emits a structured reasoning trace visible in the Web Dashboard:

```json
{
  "agent": "coder",
  "task_id": "task-007",
  "thought": "The Planner specified a FastAPI endpoint. I need to check ChromaDB for our existing router pattern to ensure naming consistency.",
  "action": "search_docs('FastAPI router pattern')",
  "observation": "Found: src/api/v1/router.py uses APIRouter with prefix='/api/v1'",
  "decision": "I will follow the same convention and create src/api/v1/users.py"
}
```

### 10.2 Tracing Integration

- **LangSmith / Arize Phoenix** captures the full chain-of-thought for every agent turn.
- Engineers can replay any decision, measure latency per node, and identify where reasoning broke down.

### 10.3 Metrics Pipeline

```
Generated App ──▶ Prometheus (scrape) ──▶ Grafana Dashboard
       │
       └── Runtime Agent monitors for anomalies (latency spikes, OOM, crash loops)
```

---

## 11. Implementation Roadmap

| Phase | Duration | Objective | Key Deliverables |
|---|---|---|---|
| **1. Foundation & Sandboxing** | Weeks 1–2 | Establish secure runtime; basic tool usage | Ollama + Qwen setup; Docker sandbox; `write_file` / `run_shell` tools; script that generates code, runs it in Docker, returns output |
| **2. Orchestration & State** | Weeks 3–4 | Build the "brain" with LangGraph | `AgentState` schema; Planner + Coder agents; LangGraph nodes/edges; SQLite persistence; CLI accepting requirements |
| **3. Testing & RLEF Loop** | Weeks 5–6 | Enable self-correction | Test Agent + Pytest integration; conditional edge logic (Pass → Review, Fail → Retry); stack-trace parsing; reward signal logging |
| **4. Memory & RAG** | Weeks 7–8 | Long-term context | ChromaDB deployment; codebase indexing pipeline; RAG integration into Planner + Coder; solution retrieval for recurring errors |
| **5. Security, UI & Benchmark** | Weeks 9–10 | Polish and validation | Bandit + Semgrep integration (Reviewer Agent); React Web Dashboard; SWE-bench Lite evaluation; final PoC demo |

---

## 12. Design Decisions and Rationale

### 12.1 Why Qwen2.5-Coder 7B over GPT-4 / Claude?

| Factor | GPT-4 / Claude (Cloud) | Qwen2.5-Coder 7B (Local) |
|---|---|---|
| **Privacy** | Code sent to third-party servers | All inference on-premises; zero IP leakage |
| **Marginal Cost** | $0.01–$0.06 per 1K tokens | Electricity only (~$0.00) |
| **High-Volume Reasoning** | Cost-prohibitive for 100+ reasoning turns | Near-zero cost enables "brute-force creativity" |
| **Coding Benchmarks** | Wider general capability | Competitive on HumanEval/MBPP at fraction of size |
| **Latency** | Network-dependent | ≥ 30 tok/s on consumer GPU |

> **Decision:** The PoC prioritizes privacy and cost-efficiency. Qwen 7B handles atomic coding tasks effectively when paired with hierarchical planning that keeps each sub-task simple.

### 12.2 Why LangGraph over CrewAI / AutoGen?

LangGraph provides **graph-level control** with explicit cyclic edges — essential for implementing the RLEF feedback loop. CrewAI and AutoGen offer higher-level abstractions that obscure the retry/branching logic critical to self-correction. LangGraph's `add_conditional_edges` maps directly to the Test→Fix→Test pattern.

### 12.3 Why Dual Memory (SQLite + ChromaDB)?

| Role | Episodic (SQLite) | Semantic (ChromaDB) |
|---|---|---|
| Data Type | Structured event logs | Unstructured text embeddings |
| Query Pattern | SQL — exact match, time-range, aggregation | Vector similarity — "find code similar to X" |
| Purpose | Audit trail, prevent repeated mistakes | RAG context, reduce hallucinations |

A single store cannot efficiently serve both structured audit queries and high-dimensional similarity search. The dual-store architecture optimizes for each access pattern independently.

### 12.4 Why "Agent as Untrusted Insider"?

LLMs are **probabilistic** — there is always a non-zero probability of generating dangerous output (e.g., `rm -rf /`, exfiltration via `requests.get`). Rather than trying to prompt-engineer safety (unreliable), Eden treats the agent as an **untrusted insider** by default:

1. **Sandbox** — hard container isolation.
2. **Semantic Firewall** — intent-aware output scanning.
3. **SAST Gate** — deterministic vulnerability detection.
4. **Audit Trail** — forensic evidence for every action.

This "Defense in Depth" architecture ensures that no single failure can compromise the system.

---

## 13. Future Considerations (Post-MVP)

| Area | Direction |
|---|---|
| **Brownfield Support** | Extend context management to navigate large legacy codebases via hierarchical summarization and file-level RAG. |
| **Model Upgrade Path** | Support hot-swapping foundation models (e.g., upgrade to Qwen 14B or 32B) without architectural changes. |
| **Multi-Repo Orchestration** | Enable the agent to coordinate changes across multiple repositories (microservices). |
| **Production Deployment** | Graduate from sandbox-only to staged production rollouts with canary analysis. |
| **Fine-Tuning Pipeline** | Use accumulated Episodic Memory as training data to fine-tune the foundation model on organization-specific patterns. |
| **"Living Software"** | Background agents autonomously detect slow queries, deprecated libraries, and unused endpoints — generating fix PRs proactively. |

---

## 14. Glossary

| Term | Definition |
|---|---|
| **Control Plane** | The LangGraph orchestrator managing global state and agent routing |
| **DAG** | Directed Acyclic Graph — the dependency-ordered task plan |
| **Episodic Memory** | SQLite-backed chronological log of agent actions and outcomes |
| **Semantic Memory** | ChromaDB vector store of code embeddings and documentation |
| **RLEF** | Reinforcement Learning from Execution Feedback — learning from compiler/test results |
| **Semantic Firewall** | Classifier that inspects agent outputs for dangerous intent before execution |
| **Circuit Breaker** | Hard retry limit that escalates unresolved tasks to human supervision |
| **Context Compaction** | Summarization of old conversation turns to keep the active prompt within token limits |

---

## 15. Document Approval

| Role | Name | Date | Signature |
|---|---|---|---|
| Solution Architect | | | |
| Engineering Lead | | | |
| DevOps / SRE Lead | | | |
| Security Lead | | | |

---

*This document is maintained under version control alongside [`requirements.md`](file:///c:/Users/Lenovo/Eden/requirements.md). All modifications require a formal Change Request approved by the Solution Architect.*
