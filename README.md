# Eden — Autonomous Self-Evolving Software Engineer

> An agentic AI system that autonomously plans, codes, tests, deploys, and self-corrects — functioning as a closed-loop software engineering workforce.

---

## The Problem

Modern software development faces a **scalability bottleneck**: rising system complexity, human dependency on the inner loop (code → test → debug), and slow iteration cycles. The gap between *defining* a solution and *implementing* it consumes the majority of engineering time.

## The Vision

Eden is not a copilot — it is an **autonomous agent**. Given a natural-language requirement, it independently executes the entire software engineering lifecycle:

1. **Decomposes** requirements into a dependency-aware task graph (DAG)
2. **Generates** production-grade Python / TypeScript code
3. **Tests** its own output adversarially (Pytest, Jest)
4. **Self-corrects** via Reinforcement Learning from Execution Feedback (RLEF)
5. **Deploys** to a sandboxed Kubernetes cluster
6. **Monitors** runtime health and triggers autonomous fixes

---

## Architecture

Eden uses a **Multi-Agent System (MAS)** — five specialized agents orchestrated by a LangGraph state machine:

| Agent | Role | Responsibility |
|-------|------|----------------|
| **Planner** | Architect | Decomposes PRDs into structured task DAGs |
| **Coder** | Developer | Writes clean, typed, documented code (SOLID, PEP 8) |
| **Tester** | QA Engineer | Generates adversarial test suites; parses failures |
| **Reviewer** | Gatekeeper | Runs Bandit + Semgrep; enforces security policy |
| **Runtime** | SRE | Monitors deployments; triggers self-healing |

## Tech Stack

| Component | Technology |
|-----------|------------|
| Foundation Model | Qwen2.5-Coder 7B (local, via Ollama) |
| Orchestrator | LangGraph (cyclic state graphs) |
| Semantic Memory | ChromaDB (RAG) |
| Episodic Memory | SQLite + SQLModel |
| Sandbox | Docker Engine 25.x |
| Security Scanning | Bandit + Semgrep |
| Observability | LangSmith / Prometheus + Grafana |

## Key Differentiators

- **Local-First** — all inference on-premises; zero IP leakage
- **Self-Evolving** — RLEF grounds the agent in compiler/test reality, not just token probability
- **Defense in Depth** — sandbox isolation, semantic firewall, SAST gate, immutable audit trail
- **Near-Zero Marginal Cost** — local 7B model enables high-volume reasoning without API bills

---

## Documentation

| Document | Description |
|----------|-------------|
| [`requirements.md`](requirements.md) | Software Requirements Specification — user stories, functional/non-functional requirements, KPIs, risk register |
| [`design.md`](design.md) | System Design Document — architecture, agent specs, memory model, data flows, implementation roadmap |
| [`Documentation/`](Documentation/) | Original PoC and PRD source documents |

## Target KPIs

| Metric | Target |
|--------|--------|
| Autonomous Resolution Rate | > 80 % |
| Self-Correction Rate | > 60 % |
| SWE-bench Lite Score | > 25 % |
| Cost per Resolution | < $0.50 |
| Mean Time to Resolution | < 10 min |

---

## Roadmap

| Phase | Weeks | Focus |
|-------|-------|-------|
| 1. Foundation & Sandbox | 1–2 | Ollama + Qwen setup, Docker sandbox, basic tooling |
| 2. Orchestration | 3–4 | LangGraph state machine, Planner + Coder agents |
| 3. RLEF Loop | 5–6 | Test Agent, self-correction, stack-trace parsing |
| 4. Memory & RAG | 7–8 | ChromaDB, codebase indexing, solution retrieval |
| 5. Security & Benchmark | 9–10 | Reviewer Agent, Web Dashboard, SWE-bench eval |

---

## License

Internal use only — Confidential.
