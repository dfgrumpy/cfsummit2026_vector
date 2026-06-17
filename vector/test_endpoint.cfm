<!--- test_endpoint.cfm - Health check: Ollama reachability, embedding model, vector store status --->
<cfinclude template="config.cfm">
<cfcontent type="application/json; charset=utf-8">
<cfscript>

    result = {
        "profile"  : ACTIVE_PROFILE,
        "label"    : PROFILE_LABEL,
        "ollama"   : { "ok": false, "message": "", "models": [] },
        "store"    : { "ok": false, "message": "", "vectorCount": -1 },
        "ok"       : false
    };

    // ── 1. Ping Ollama ────────────────────────────────────────────────────────
    try {
        cfhttp(
            url     = OLLAMA_BASE & "/api/tags",
            method  = "GET",
            timeout = 5,
            result  = "ollamaResp"
        );
        if ( ollamaResp.statusCode CONTAINS "200" ) {
            parsed = deserializeJSON( ollamaResp.fileContent );
            modelNames = [];
            if ( structKeyExists( parsed, "models" ) ) {
                for ( m in parsed.models ) {
                    arrayAppend( modelNames, m.name );
                }
            }
            result.ollama.models = modelNames;

            // Check embedding model is present (flexible: match by prefix before ":")
            embedBase = listFirst( EMBEDDING_MODEL, ":" );
            hasEmbed  = false;
            for ( mName in modelNames ) {
                if ( mName CONTAINS embedBase ) { hasEmbed = true; break; }
            }
            if ( hasEmbed ) {
                result.ollama.ok      = true;
                result.ollama.message = "Reachable. Model '#EMBEDDING_MODEL#' found.";
            } else {
                result.ollama.ok      = false;
                result.ollama.message = "Reachable, but embedding model '#EMBEDDING_MODEL#' not found in model list.";
            }
        } else {
            result.ollama.message = "HTTP #ollamaResp.statusCode# from Ollama.";
        }
    } catch ( any e ) {
        result.ollama.message = "Cannot reach Ollama at #OLLAMA_BASE#: #e.message#";
    }

    // ── 2. Vector store check ────────────────────────────────────────────────
    if ( STORE_MODE EQ "qdrant" ) {

        try {
            cfhttp(
                url     = QDRANT_REST_URL & "/collections/" & QDRANT_COLLECTION,
                method  = "GET",
                timeout = 5,
                result  = "qdrantResp"
            );
            if ( qdrantResp.statusCode CONTAINS "200" ) {
                qParsed = deserializeJSON( qdrantResp.fileContent );
                qResult = structKeyExists( qParsed, "result" ) ? qParsed.result : {};
                // Try both field names — 1.16.x uses points_count; older builds used vectors_count
                if ( structKeyExists( qResult, "points_count" ) ) {
                    cnt = qResult.points_count;
                } else if ( structKeyExists( qResult, "vectors_count" ) ) {
                    cnt = qResult.vectors_count;
                } else {
                    cnt = -1;
                }
                if ( cnt GTE 0 ) {
                    result.store.vectorCount = cnt;
                    result.store.ok          = ( cnt GT 0 );
                    result.store.message     = cnt & " vector(s) in collection '#QDRANT_COLLECTION#'." & ( cnt EQ 0 ? " Nothing ingested yet." : "" );
                } else {
                    result.store.ok      = true;
                    result.store.message = "Collection '#QDRANT_COLLECTION#' found (count unavailable).";
                }
            } else if ( qdrantResp.statusCode CONTAINS "404" ) {
                result.store.message = "Collection '#QDRANT_COLLECTION#' does not exist. Run Ingest first.";
            } else {
                result.store.message = "Qdrant HTTP #qdrantResp.statusCode#.";
            }
        } catch ( any e ) {
            result.store.message = "Cannot reach Qdrant at #QDRANT_REST_URL#: #e.message#";
        }

    } else {
        // In-memory store
        storeExists = isDefined( "application.#STORE_KEY#" );
        if ( storeExists ) {
            vs = application[ STORE_KEY ];
            try {
                // Probe with a generic search — InMemory has no count() method
                probe = vs.search({ text: "ColdFusion", topK: 1, minScore: 0.0 });
                if ( arrayLen( probe ) GT 0 ) {
                    result.store.ok      = true;
                    result.store.message = "In-memory store is initialised and searchable.";
                } else {
                    result.store.ok      = false;
                    result.store.message = "In-memory store exists but returned no results. Run Ingest first.";
                }
            } catch ( any e ) {
                result.store.ok      = false;
                result.store.message = "In-memory store probe failed: " & e.message;
            }
        } else {
            result.store.ok      = false;
            result.store.message = "In-memory store not initialised. Run Ingest first.";
        }
    }

    result.ok = ( result.ollama.ok AND result.store.ok );

    writeOutput( serializeJSON( result ) );

</cfscript>
