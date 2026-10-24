# AGENTS.md — Development Directives for AI Agents

> **Project:** Ashen Vanguard (3D Horde Survival / Bullet Heaven in Godot 4.7)  
> **Target Audience for this document:** Any AI agent, LLM, or automated assistant working on this codebase.  
> **Authority:** This document defines non-negotiable architectural and decision-making rules. Every task execution must adhere strictly to these directives.

---

## 1. Anti-Overengineering & Concrete Implementations (YAGNI)

* **Rule 1.1 — Ban on Speculative Abstractions:** Do NOT create generic wrappers, abstract base classes, complex factory patterns, dependency-injection layers, or over-decoupled event buses unless the immediate feature literally cannot function without them.
* **Rule 1.2 — Flat and Direct Godot Structure:** Prefer direct, idiomatic Godot composition over deep object-oriented hierarchies. Nodes should call methods directly on children and emit signals upwards. Keep script sizes small, focused, and readable.
* **Rule 1.3 — Solve Today's Problem Only:** Write the minimal concrete code required to achieve the current task. Do not prepare architectures for hypothetical features that have not been requested.

---

## 2. The Future Phase Gate for Complexity

* **Rule 2.1 — Complexity Requires Explicit Roadmap Mapping:** A more complex, decoupled, or generalized system is **STRICTLY PROHIBITED** unless that exact requirement is explicitly documented and mapped to a designated future development phase in `GDD.md`.
* **Rule 2.2 — Default to Simple and Refactor Later:** If a feature is only required for the current milestone (e.g., MVP), implement the simplest working solution. If a future phase documented in `GDD.md` later demands scalability or polymorphism, refactor at that time, never beforehand.

---

## 3. Experience-First Request Interpretation

* **Rule 3.1 — Target the Intended Player Feeling:** When the user describes a feature or mechanic, interpret their request through the **player experience and gameplay sensation** they are aiming to produce, rather than getting blinded by literal phrasing.
* **Rule 3.2 — Validate Mechanical Output Against Game Feel:** Ask: *"Does this implementation deliver the intended pacing, impact, urgency, or satisfaction the user asked for?"* If a technically correct script feels sluggish, disconnected, or dull, the request was not successfully fulfilled.

---

## 4. No Subjective Bias on Mechanics (Precedents Over Opinions)

* **Rule 4.1 — Eliminate Personal Value Judgments:** Never declare a mechanic "good" or "bad" based on personal taste, theoretical dogmas, or general game design clichés.
* **Rule 4.2 — Ground Design Decisions in Proven Precedents:** Whenever ambiguity or uncertainty arises regarding a mechanical choice (e.g., XP vacuum speed, enemy spawn cadence, hit-stop duration, damage curves, upgrade rerolls), **search for and cite established commercial precedents** that have already proven the concept in production.

---

## 5. Prioritize Mechanical Genre Precedents (Not Visual/Narrative Themes)

* **Rule 5.1 — Match Mechanics to Mechanical Peers:** When researching references and benchmarks, **ALWAYS prioritize games sharing the exact mechanical DNA** of this project (Horde Survival / Bullet Heaven / Auto-Shooter), regardless of their visual or narrative setting.
  * **Primary Mechanical Benchmarks:**
    * *Vampire Survivors* (Pacing, drop curves, magnet radius, passive scaling, weapon evolutions)
    * *Brotato* (Stat density, wave timing, weapon synergy)
    * *Death Must Die* / *Halls of Torment* (3D / 2.5D perspective translation, isometric hitbox handling)
    * *20 Minutes Till Dawn* (Active dodge patterns, screen boundary pressure)
* **Rule 5.2 — Disregard Narrative Distractions in Mechanical Research:** Do NOT borrow gameplay systems, combat timings, or math formulas from traditional medieval/fantasy games (such as *Dark Souls*, *The Witcher*, or *Skyrim*) merely because this game features a Knight. The game's soul is mechanically an auto-shooter; all numbers, loops, and behaviors must reflect the auto-shooter genre.

---

## 6. Godot 4.7 Implementation Standards

1. **Static Typing:** Always use explicit type annotations in GDScript (`var speed: float = 5.0`, `func take_damage(amount: int) -> void:`).
2. **Expose Tunables:** Use `@export` for balancing parameters so values are easily adjusted in the Inspector without editing code.
3. **Physics Discipline:** Movement and velocity calculations belong in `_physics_process(delta)`. Rendering and visual rotations belong in `_process(delta)`.
4. **Collision Filtering:** Always configure explicit Collision Layers and Masks for Players, Enemies, Projectiles, and Pickups to avoid wasteful physics checks.
5. **Deterministic Spawning:** Use simple timers and distance checks around the player camera to spawn enemies, recycling or freeing nodes cleanly to maintain high frame rates.
