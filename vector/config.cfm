<!--- config.cfm - Profile-based configuration --->
<!--- Included at the top of every page. Sets all runtime variables from the active profile. --->
<!---
    SETUP INSTRUCTIONS
    ──────────────────
    Replace the placeholder values below with your own hostnames or IP addresses:

      YOUR_OLLAMA_HOST   — IP or hostname of the machine running Ollama
                           e.g. 192.168.1.100  or  ollama.local
      YOUR_QDRANT_HOST   — IP or hostname of the machine running Qdrant
                           e.g. 192.168.1.100  or  qdrant.local  (can be the same machine)

    Both services use their default ports (Ollama: 11434, Qdrant: 6334).

    pdfDir must point to a directory inside your ColdFusion web root that contains PDF files
    to ingest.  The path shown is relative to a Docker-based CommandBox install; adjust as needed.
--->

<cfscript>

    // ── Profile definitions ────────────────────────────────────────────────────
    profiles = {

        "desktop_memory": {
            "label"            : "Desktop — InMemory",
            "endpoint"         : "Desktop",
            "ollamaBase"       : "http://YOUR_OLLAMA_HOST:11434",
            "embeddingModel"   : "nomic-embed-text",
            "embeddingDim"     : 768,
            "llmModel"         : "llama3",
            "chunkSize"        : 500,
            "chunkOverlap"     : 75,
            "topK"             : 5,
            "simThreshold"     : 0.4,
            "pdfDir"           : "/app/wwwroot/cfai/cf_ai_docs",
            "storeMode"        : "memory",
            "storeKey"         : "vectorStore_desktop_memory",
            "qdrantUrl"        : "",
            "qdrantCollection" : ""
        },

        "desktop_qdrant": {
            "label"            : "Desktop — Qdrant",
            "endpoint"         : "Desktop",
            "ollamaBase"       : "http://YOUR_OLLAMA_HOST:11434",
            "embeddingModel"   : "nomic-embed-text",
            "embeddingDim"     : 768,
            "llmModel"         : "llama3",
            "chunkSize"        : 500,
            "chunkOverlap"     : 75,
            "topK"             : 5,
            "simThreshold"     : 0.4,
            "pdfDir"           : "/app/wwwroot/cfai/cf_ai_docs",
            "storeMode"        : "qdrant",
            "storeKey"         : "vectorStore_desktop_qdrant",
            "qdrantUrl"        : "http://YOUR_QDRANT_HOST:6334",
            "qdrantCollection" : "cfai_desktop"
        },

        "nas_memory": {
            "label"            : "NAS — InMemory",
            "endpoint"         : "NAS",
            "ollamaBase"       : "http://YOUR_OLLAMA_HOST:11434",
            "embeddingModel"   : "all-minilm",
            "embeddingDim"     : 384,
            "llmModel"         : "phi3:mini",
            "chunkSize"        : 500,
            "chunkOverlap"     : 75,
            "topK"             : 5,
            "simThreshold"     : 0.4,
            "pdfDir"           : "/app/wwwroot/cfai/cf_ai_docs",
            "storeMode"        : "memory",
            "storeKey"         : "vectorStore_nas_memory",
            "qdrantUrl"        : "",
            "qdrantCollection" : ""
        },

        "nas_qdrant": {
            "label"            : "NAS — Qdrant",
            "endpoint"         : "NAS",
            "ollamaBase"       : "http://YOUR_OLLAMA_HOST:11434",
            "embeddingModel"   : "all-minilm",
            "embeddingDim"     : 384,
            "llmModel"         : "phi3:mini",
            "chunkSize"        : 500,
            "chunkOverlap"     : 75,
            "topK"             : 5,
            "simThreshold"     : 0.4,
            "pdfDir"           : "/app/wwwroot/cfai/cf_ai_docs",
            "storeMode"        : "qdrant",
            "storeKey"         : "vectorStore_nas_qdrant",
            "qdrantUrl"        : "http://YOUR_QDRANT_HOST:6334",
            "qdrantCollection" : "cfai_nas"
        }

    };

    // ── Resolve active profile from URL or form, defaulting to desktop_memory ──
    DEFAULT_PROFILE = "desktop_memory";

    if ( structKeyExists( url, "profile" ) AND structKeyExists( profiles, url.profile ) ) {
        ACTIVE_PROFILE = url.profile;
    } else if ( structKeyExists( form, "profile" ) AND structKeyExists( profiles, form.profile ) ) {
        ACTIVE_PROFILE = form.profile;
    } else {
        ACTIVE_PROFILE = DEFAULT_PROFILE;
    }

    // ── Unpack active profile into top-level variables ─────────────────────────
    cfg = profiles[ ACTIVE_PROFILE ];

    PROFILE_LABEL      = cfg.label;
    ENDPOINT_NAME      = cfg.endpoint;
    OLLAMA_BASE        = cfg.ollamaBase;
    EMBEDDING_MODEL    = cfg.embeddingModel;
    EMBEDDING_DIM      = cfg.embeddingDim;
    LLM_MODEL          = cfg.llmModel;
    CHUNK_SIZE         = cfg.chunkSize;
    CHUNK_OVERLAP      = cfg.chunkOverlap;
    MIN_CHUNK_SIZE     = 50;
    TOP_K              = cfg.topK;
    SIM_THRESHOLD      = cfg.simThreshold;
    PDF_DIR            = cfg.pdfDir;
    STORE_MODE         = cfg.storeMode;
    STORE_KEY          = cfg.storeKey;
    QDRANT_URL         = cfg.qdrantUrl;
    QDRANT_COLLECTION  = cfg.qdrantCollection;

    // ── Qdrant version compatibility ───────────────────────────────────────────
    // CF2025 is only compatible with Qdrant 1.16.x
    // Versions 1.17+ have breaking API changes that will cause connection failures.
    // Docker image: qdrant/qdrant:v1.16.1 (or any 1.16.* tag)

    // ── Auto-reconnect store on CF restart (Qdrant profiles only) ─────────────
    // InMemory stores are ephemeral — nothing to reconnect after a restart.
    // Qdrant data lives on disk, so we can silently reconnect the client.
    if ( STORE_MODE EQ "qdrant" AND NOT isDefined( "application.#STORE_KEY#" ) ) {
        try {
            application[ STORE_KEY ] = VectorStore({
                provider       : "qdrant",
                url            : QDRANT_URL,
                collectionName : QDRANT_COLLECTION,
                dimension      : EMBEDDING_DIM,
                embeddingModel : {
                    provider   : "ollama",
                    modelName  : EMBEDDING_MODEL,
                    baseUrl    : OLLAMA_BASE,
                    maxRetries : 3
                }
            });
        } catch ( any e ) {
            // Store stays undefined — pages that need it will show a friendly error.
            writeLog(
                text = "config.cfm — failed to reconnect VectorStore [#STORE_KEY#]: #e.message#",
                type = "error",
                file = "cfai"
            );
        }
    }

</cfscript>