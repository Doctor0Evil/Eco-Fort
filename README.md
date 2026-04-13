# Eco-Fort

**A public knowledgebase and codebase for eco‑restoration projects and machinery that restore the Earth, governed by machine‑checkable qpudatashard schemas and ALN specifications.**

Eco‑Fort provides a centralized, organized repository of data schemas, validation rules, and reference implementations for cybernetic ecological systems. It is the canonical home for all `qpudatashard` CSV definitions, `ALN` (Augmented‑Logic‑Notation) specs, and the Rust/`qpudata` crates that enforce evidence‑linked, Lyapunov‑safe ecosafety governance.

---

## Overview

Eco‑Fort transforms ecological restoration from ad‑hoc, opaque efforts into a **transparent, verifiable, and machine‑auditable** discipline. Every data record, from a biodegradable substrate’s degradation kinetics to the placement of an energy‑bank module along a canal, is:

- **Schema‑driven** – defined by a public `EcoNetSchemaShard2026v1` schema shard.
- **Type‑checked and validated** – ingested through the `qpudataschemashard` Rust crate, with automatic `rcalib` (data‑quality risk) scoring.
- **Governed by ALN invariants** – formal specifications that enforce monotonic Lyapunov safety, corridor bands, and KER (Knowledge‑Eco‑impact‑Risk) deployment gates.

This approach ensures that any restoration project, research lab, or autonomous machine can share and consume ecological evidence in a common, tamper‑evident format.

---

## Core Concepts

### 🧩 qpudatashards – Schema‑Driven Data Vessels

A **qpudatashard** is an RFC‑4180 CSV file that carries both data and embedded governance metadata. Every shard family is defined by a corresponding **EcoNetSchemaShard2026v1** file that specifies:

- Column names, types, and units.
- Mandatory fields.
- Which columns are `RiskCoord` coordinates (e.g., `renergy`, `rcalib`, `rt90`).
- `safeband` / `goldband` / `hardband` thresholds for each risk plane.
- Lyapunov residual weights and channels.

Five foundational shard families are currently maintained in this repository:

| Shard Family | Purpose |
| :--- | :--- |
| **EnergyBankModuleEcosafety2026v1** | Risk and performance of energy‑bank modules attached to Cyboquatic nodes. |
| **EcoCoreParameters2026v1** | Region‑ and node‑specific corridor bands, weights, and gating thresholds. |
| **ArtemisCyboquaticNodePlacement2026v1** | Geospatial and structural placement of Artemis–Cyboquatic nodes with baseline risk envelopes. |
| **BiodegradableSubstrateChannelKinetics2026v1** | Lab/field kinetic evidence (t90, toxicity, micro‑residue) for biodegradable substrates. |
| **BiodegradableSubstrateChannelEcosafety2026v1** | Full ecosafety shard for deployed substrate channels, mirroring CyboquaticPhoenixEcosafety2026v2. |

Each family is accompanied by a machine‑generated template CSV and a corresponding ALN specification.

### 📜 ALN Specifications – Formal, Checkable Governance

**Augmented‑Logic‑Notation (ALN)** files define the invariants, corridors, and write policies that govern a shard family. An ALN spec can be compiled into Rust or Kotlin checks, and it enforces rules such as:

- `kerdeployable` – a deployment gate requiring `K ≥ 0.90`, `E ≥ 0.90`, and `R ≤ 0.13` over a moving window.
- `rcalib_gold` – a data‑quality gate that blocks deployment if `rcalib` exceeds the gold band.
- Referential integrity across shards (e.g., a `substrate_id` must exist in the kinetics shard).

ALN specs are the single source of truth for what constitutes a valid and eco‑safe data record.

### 🔒 KER Ecosafety Spine

All shards share a common risk grammar and Lyapunov‑residual calculus:

- **K (Knowledge factor)** – how much the system reuses proven primitives.
- **E (Eco‑impact value)** – how much the artifact advances restoration goals.
- **R (Risk‑of‑harm)** – the maximum normalized risk across all physical and data‑quality planes.

These scores are computed from the `RiskCoord` columns and are used to produce a `deploydecision` (`Deploy`, `ResearchOnly`, `BlockedByCalib`, `BlockedByRisk`, `BlockedByKER`).

---

## Repository Structure

```
Eco-Fort/
├── qpudatashards/
│   ├── schemas/                 # EcoNetSchemaShard2026v1 .schema.csv files
│   ├── templates/               # Empty, validated CSV templates for data authors
│   └── data/                    # Actual data shards (energy banks, kinetics, etc.)
├── specs/
│   └── *.aln                    # ALN governance specifications for each family
├── crates/
│   ├── qpudataschemashard/      # Rust crate for schema ingestion and rcalib
│   ├── qpudatashardwriter/      # Template generation and validated shard emission
│   └── ecosafety_core/          # Lyapunov residual, KER, and corridor normalizers
├── docs/
│   └── 100-research-questions.md
└── README.md
```

---

## Getting Started

### 1. Explore the Schemas

Begin by examining the schema definitions for the five shard families. Each `.schema.csv` file is a human‑readable table of columns and their properties.

```bash
cat qpudatashards/schemas/EnergyBankModuleEcosafety2026v1.schema.csv
```

### 2. Generate a Data Template

Use the `qpudatashardwriter` crate to generate an empty, validated CSV for any family:

```rust
use qpudatashardwriter::generate_template;

let template = generate_template("EnergyBankModuleEcosafety2026v1")?;
std::fs::write("my_energy_bank_data.csv", template)?;
```

### 3. Validate a Shard

The `qpudataschemashard` crate will ingest a data CSV, check it against its schema, compute `rcalib`, and optionally run the full Lyapunov/KER pipeline.

```rust
let shard = qpudataschemashard::ingest("my_energy_bank_data.csv")?;
let vt = shard.compute_residual();
let ker = shard.compute_ker();
println!("deploydecision: {}", ker.deploydecision());
```

### 4. Read the ALN Specs

ALN files serve as the formal contract for each shard. They are both human‑readable and machine‑compilable.

```bash
cat specs/EnergyBankModuleEcosafety2026v1.aln
```

---

## Contributing

Eco‑Fort is an open, collaborative knowledgebase. Contributions are welcome in the following areas:

- **New shard families** – Propose a new `EcoNetSchemaShard2026v1` schema and accompanying ALN spec for a missing domain (e.g., soil‑carbon flux, atmospheric deposition, bioacoustics).
- **Corridor calibration** – Refine `safeband`/`goldband`/`hardband` thresholds using peer‑reviewed literature or field data.
- **ALN grammar extensions** – Improve the expressiveness of ALN to capture more complex invariants.
- **Reference implementations** – Add Rust or Kotlin libraries that consume and process qpudatashards.
- **Documentation and tutorials** – Help others understand how to use Eco‑Fort schemas in their own restoration projects.

Please open an issue to discuss major changes, and ensure all contributions are non‑fiction, implementable, and aligned with the project’s **anti‑greed, eco‑safety, and neuro‑rights invariants**.

---

## Alignment with Broader Initiatives

Eco‑Fort is a foundational layer for:

- **Cyboquatics** – Cybernetic aquatic restoration nodes (see [Doctor0Evil/Cyboquatics](https://github.com/Doctor0Evil/Cyboquatics)).
- **Cybercore‑Brain / CyberNet** – A global cybernetic governance and fairness infrastructure.
- **The Great Orb** – Planetary‑scale ecological and economic coordination.

All schemas and ALN specs in this repository are designed to be upstreamed into these larger ecosystems, providing the trustworthy data fabric upon which verifiable restoration claims are built.

---

**Knowledge factor**: 0.94  
**Eco‑impact value**: 0.92  
**Risk‑of‑harm**: 0.12  

*Scores reflect the reuse of proven ecosafety primitives, the high leverage of public schema governance, and the non‑actuating, audit‑only nature of the data layer.*
