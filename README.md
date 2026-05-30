# CF AI — Semantic Search / Vector RAG Demo

Companion source code for the CFSummit 2026 session  
**"Semantic Search and Vector Queries in ColdFusion Applications"**  
by Dave Ferguson ([@DFGrumpy](https://x.com/DFGrumpy))

---

## What this is

A working Retrieval-Augmented Generation (RAG) pipeline built entirely in ColdFusion 2025.  
It ingests PDF documents and CFDocs JSON files, converts them to vector embeddings, stores those embeddings locally, and then lets you ask plain-English questions and get semantically relevant answers — no cloud API required.

The session demo showed this running against the ColdFusion documentation, but the pipeline works on any text-based content.

---

## How it works

```
Your documents (PDFs / JSON)
        │
        ▼
   Text extraction & chunking
        │
        ▼
   Ollama embedding model  ──►  vector (768 or 384 floats)
        │
        ▼
   Vector store (InMemory or Qdrant)
        │
    At query time:
        │
   User question  ──►  embed question  ──►  similarity search
        │
        ▼
   Top-K matching chunks  ──►  Ollama LLM  ──►  Answer
```

### The four pages

| File | Purpose |
|------|---------|
| `index.cfm` | Profile selector — choose which Ollama endpoint and store backend to use |
| `ingest.cfm` | Load PDFs and CFDocs JSON into the vector store |
| `search.cfm` | Semantic search with optional RAG answer generation |
| `debug_rag.cfm` | Step-by-step pipeline debugger: query → chunks → prompt → LLM answer |

### Profiles

`config.cfm` defines four named profiles so you can switch between machines and store backends without touching code:

| Profile | Endpoint | Store | Embedding model |
|---------|----------|-------|-----------------|
| `desktop_memory` | Desktop Ollama | InMemory (ephemeral) | nomic-embed-text (768d) |
| `desktop_qdrant` | Desktop Ollama | Qdrant (persistent) | nomic-embed-text (768d) |
| `nas_memory` | NAS Ollama | InMemory (ephemeral) | all-minilm (384d) |
| `nas_qdrant` | NAS Ollama | Qdrant (persistent) | all-minilm (384d) |

InMemory stores are fast to set up but lost on a CF restart.  
Qdrant stores persist to disk and reconnect automatically after a restart.

---

## Prerequisites

### 1. ColdFusion 2025 Update 8

This code uses CF 2025 built-in features:

- `VectorStore()` — native vector store (InMemory and Qdrant providers)
- `ChatModel()` — LLM chat integration
- `cfpdf action="extracttext"` — PDF text extraction

**CF 2025 Update 8 or later is required.**

After applying Update 8, you must also install the **ColdFusion AI package** separately — it is not included in the core update. Install it through the ColdFusion Package Manager in the CF Administrator, or via the `cfpm` command-line tool:

```bash
cfpm install ai
```

### 2. Ollama

Ollama runs the embedding model and the LLM locally — no cloud account needed.

- Download: https://ollama.com
- After installing, pull the models used by the profiles you want:

```bash
# For desktop profiles (768-dimension embeddings)
ollama pull nomic-embed-text
ollama pull llama3

# For NAS / lower-resource profiles (384-dimension embeddings)
ollama pull all-minilm
ollama pull phi3:mini
```

Ollama listens on port `11434` by default.  
If CF and Ollama are on different machines, make sure port 11434 is reachable from the CF server.

### 3. Qdrant (optional — required for persistent profiles only)

Qdrant is a vector database that persists embeddings to disk.  
If you only use InMemory profiles, you can skip this.

- Docs: https://qdrant.tech/documentation/guides/installation/

The easiest way to run it is via Docker:

```bash
docker run -d --name qdrant \
  -p 6333:6333 -p 6334:6334 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant:v1.16.1
```

> **Version note:** ColdFusion 2025 is compatible with Qdrant **1.16.x**.  
> Qdrant 1.17+ introduced breaking API changes that will cause connection failures.  
> Use the `v1.16.1` Docker tag (or any `1.16.*` release).

Qdrant's HTTP API listens on port `6333`, gRPC on `6334`.  
CF 2025's VectorStore uses the gRPC port (`6334`).

---

## Setup

1. **Clone or copy** this directory into your ColdFusion web root.

2. **Edit `config.cfm`** — replace the placeholder host values with your own:

   ```cfscript
   "ollamaBase" : "http://YOUR_OLLAMA_HOST:11434",
   "qdrantUrl"  : "http://YOUR_QDRANT_HOST:6334",
   ```

   Both values can be the same host if everything runs on one machine (e.g. `localhost`).

3. **Set `pdfDir`** to the path where your PDF files live.  
   The path must be readable by the CF server process.  
   The default value (`/app/wwwroot/cfai/cf_ai_docs`) reflects a Docker-based CommandBox install — adjust it to match your environment.

4. **Place your documents** in `pdfDir` (PDFs) and/or a `language_json/` subfolder (CFDocs JSON files).

5. **Browse to `index.cfm`**, pick a profile, and click **Ingest** to build the vector store.

6. Once ingestion completes, use **Search** or **Debug** to query your documents.

---

## Project structure

```
vector/
├── config.cfm          # Profile definitions and active-profile resolver
├── _profile_bar.cfm    # Shared profile/nav header included on every page
├── index.cfm           # Home — profile selector
├── ingest.cfm          # Document ingestion (PDF + CFDocs JSON)
├── search.cfm          # Semantic search + optional RAG answer
└── debug_rag.cfm       # Full pipeline debugger
```

---

## Related resources

- ColdFusion 2025 AI documentation: https://helpx.adobe.com/coldfusion/using/coldfusion-ai-services.html
- Ollama model library: https://ollama.com/library
- CFDocs (ColdFusion language reference): https://cfdocs.org
- Qdrant documentation: https://qdrant.tech/documentation/

---

## License

MIT — use freely, attribution appreciated.
