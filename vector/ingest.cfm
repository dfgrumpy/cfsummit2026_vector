<!--- ingest.cfm - Ingest PDFs and CFDocs JSON into the active profile's vector store. --->
<cfsetting requesttimeout="3600">
<cfinclude template="config.cfm">
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Ingest</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <style>
        .progress { height: 10px; }
        .log-line { font-size: .8rem; font-family: monospace; }
    </style>
</head>
<body class="bg-dark text-light">
<div class="container-xl py-4">

<cfset PAGE_TITLE = "Ingest">
<cfinclude template="_profile_bar.cfm">

<h2 class="mb-1">&#128196; Ingest</h2>
<p class="text-secondary small mb-4">Load PDFs and CFDocs JSON into the vector store for the selected profile.</p>

<!--- ═══════════════════════════════════════════════════════════════
      PRE-FLIGHT: Show file counts and ingest options
═══════════════════════════════════════════════════════════════════ --->
<cfif NOT isDefined("form.startIngest")>

    <cfscript>
        pdfFiles  = directoryList( PDF_DIR, false, "query", "*.pdf" );
        jsonDir   = expandPath( "../cf_ai_docs/language_json/" );
        jsonFiles = directoryList( jsonDir, false, "query", "*.json" );
    </cfscript>

    <cfoutput>

    <!--- Store / connection info card --->
    <div class="card bg-dark border-secondary mb-4">
        <div class="card-body">
            <h6 class="card-title text-secondary text-uppercase small mb-3">Vector Store</h6>
            <div class="row g-2 small">
                <div class="col-auto">
                    <span class="text-secondary">Mode:</span>
                    <cfif STORE_MODE EQ "qdrant">
                        <span class="badge bg-primary ms-1">Qdrant</span>
                    <cfelse>
                        <span class="badge bg-secondary ms-1">InMemory</span>
                    </cfif>
                </div>
                <cfif STORE_MODE EQ "qdrant">
                    <div class="col-auto text-secondary">
                        URL: <span class="text-light font-monospace">#QDRANT_URL#</span>
                    </div>
                    <div class="col-auto text-secondary">
                        Collection: <span class="text-light font-monospace">#QDRANT_COLLECTION#</span>
                    </div>
                </cfif>
                <div class="col-auto text-secondary">
                    Dim: <span class="text-light">#EMBEDDING_DIM#</span>
                </div>
                <div class="col-auto text-secondary">
                    Key: <span class="text-light font-monospace">#STORE_KEY#</span>
                </div>
            </div>
        </div>
    </div>

    <!--- File counts --->
    <div class="row g-3 mb-4">
        <div class="col-6 col-md-3">
            <div class="card bg-dark border-secondary text-center p-3">
                <div class="display-6 fw-bold text-info">#pdfFiles.recordCount#</div>
                <div class="small text-secondary">PDF files</div>
            </div>
        </div>
        <div class="col-6 col-md-3">
            <div class="card bg-dark border-secondary text-center p-3">
                <div class="display-6 fw-bold text-success">#jsonFiles.recordCount#</div>
                <div class="small text-secondary">JSON files</div>
            </div>
        </div>
    </div>

    <!--- PDF file list --->
    <cfif pdfFiles.recordCount GT 0>
        <h6 class="text-secondary text-uppercase small mb-2">
            PDF Files in <code>#PDF_DIR#</code>
        </h6>
        <div class="table-responsive mb-4">
            <table class="table table-dark table-sm table-bordered">
                <thead>
                    <tr><th>##</th><th>File</th><th>Size</th></tr>
                </thead>
                <tbody>
                    <cfset n = 0>
                    <cfloop query="pdfFiles">
                        <cfset n++>
                        <tr>
                            <td class="text-secondary">#n#</td>
                            <td>#pdfFiles.name#</td>
                            <td class="text-secondary">#numberFormat( pdfFiles.size / 1024, "0.0" )# KB</td>
                        </tr>
                    </cfloop>
                </tbody>
            </table>
        </div>
    </cfif>

    <!--- Ingest form --->
    <form method="post">
        <input type="hidden" name="profile" value="#encodeForHTMLAttribute( ACTIVE_PROFILE )#">
        <input type="hidden" name="startIngest" value="1">

        <!--- Source selection --->
        <h6 class="text-secondary text-uppercase small mb-2">Source Selection</h6>
        <div class="d-flex gap-2 mb-4">
            <button type="button" id="togglePdf"
                    class="btn btn-warning text-dark"
                    onclick="toggleSource('pdf')">
                &##128196; PDFs
            </button>
            <button type="button" id="toggleJson"
                    class="btn btn-success"
                    onclick="toggleSource('json')">
                &##128288; JSON
            </button>
        </div>
        <input type="hidden" name="ingestSource" id="ingestSourceField" value="both">

        <cfif STORE_MODE EQ "qdrant">
            <!--- Qdrant: offer wipe or append --->
            <h6 class="text-secondary text-uppercase small mb-2">Ingest Mode</h6>
            <div class="list-group list-group-flush bg-dark mb-3" style="max-width:520px;">
                <label class="list-group-item list-group-item-action bg-dark text-light border-secondary d-flex gap-3">
                    <input class="form-check-input flex-shrink-0 mt-1" type="radio" name="ingestMode" value="wipe" checked>
                    <span>
                        <strong>&##128465; Wipe and rebuild</strong>
                        <span class="d-block small text-secondary">
                            Delete the Qdrant collection, recreate it, then ingest everything fresh.
                        </span>
                    </span>
                </label>
                <label class="list-group-item list-group-item-action bg-dark text-light border-secondary d-flex gap-3">
                    <input class="form-check-input flex-shrink-0 mt-1" type="radio" name="ingestMode" value="append">
                    <span>
                        <strong>&##10133; Append only</strong>
                        <span class="d-block small text-secondary">
                            Add new vectors without touching existing data in Qdrant.
                        </span>
                    </span>
                </label>
            </div>
            <div class="alert alert-danger small py-2" id="wipeWarning">
                &##9888; Wipe mode will permanently delete all vectors in
                <strong>#QDRANT_COLLECTION#</strong>.
            </div>
        <cfelse>
            <!--- InMemory: always a fresh load --->
            <input type="hidden" name="ingestMode" value="wipe">
            <div class="alert alert-secondary small py-2">
                &##8505; InMemory mode always starts fresh.
                Vectors are lost when ColdFusion restarts.
            </div>
        </cfif>

        <button type="submit" class="btn btn-primary btn-lg">&##128640; Start Ingest</button>
    </form>
    </cfoutput>

    <script>
        // ── Wipe warning toggle ──────────────────────────────────────────────
        const radios = document.querySelectorAll('input[name="ingestMode"]');
        const warn   = document.getElementById('wipeWarning');
        if ( radios.length && warn ) {
            radios.forEach( r => r.addEventListener('change', () => {
                warn.style.display = r.value === 'wipe' ? 'block' : 'none';
            }));
        }

        // ── Source selection toggles ─────────────────────────────────────────
        // Both on by default (value = "both"). Each button toggles independently.
        // If both end up off, re-enable both to prevent a no-op ingest.
        let pdfOn  = true;
        let jsonOn = true;

        function updateSourceField() {
            const field = document.getElementById('ingestSourceField');
            if ( pdfOn && jsonOn )  { field.value = 'both'; return; }
            if ( pdfOn )            { field.value = 'pdf';  return; }
            if ( jsonOn )           { field.value = 'json'; return; }
            // Neither selected — re-enable both
            pdfOn  = true;
            jsonOn = true;
            applyButtonStyles();
            field.value = 'both';
        }

        function applyButtonStyles() {
            const btnPdf  = document.getElementById('togglePdf');
            const btnJson = document.getElementById('toggleJson');
            btnPdf.className  = pdfOn  ? 'btn btn-warning text-dark' : 'btn btn-outline-secondary';
            btnJson.className = jsonOn ? 'btn btn-success'            : 'btn btn-outline-secondary';
        }

        function toggleSource(src) {
            if ( src === 'pdf' )  pdfOn  = !pdfOn;
            if ( src === 'json' ) jsonOn = !jsonOn;
            applyButtonStyles();
            updateSourceField();
        }
    </script>

<!--- ═══════════════════════════════════════════════════════════════
      INGEST RUN
═══════════════════════════════════════════════════════════════════ --->
<cfelse>

    <cfscript>

        ingestMode   = ( isDefined( "form.ingestMode" ) AND form.ingestMode EQ "append" ) ? "append" : "wipe";
        ingestSource = ( isDefined( "form.ingestSource" ) AND listFind( "pdf,json,both", form.ingestSource ) )
                       ? form.ingestSource : "both";
        doPDF  = ( ingestSource EQ "both" OR ingestSource EQ "pdf" );
        doJSON = ( ingestSource EQ "both" OR ingestSource EQ "json" );

        // ── Helper functions ────────────────────────────────────────────────

        /**
         * Split text into overlapping chunks.
         */
        function chunkText( required string text, numeric size=500, numeric overlap=75 ) {
            var chunks = [];
            var start  = 1;
            var tLen   = len( text );
            while ( start <= tLen ) {
                var finish = min( start + size - 1, tLen );
                arrayAppend( chunks, mid( text, start, finish - start + 1 ) );
                start = start + size - overlap;
            }
            return chunks;
        }

        /**
         * Normalise whitespace and trim.
         */
        function cleanText( required string text ) {
            var t = reReplace( text, " {2,}", " ", "ALL" );
            t     = reReplace( t, "(\r?\n){3,}", chr(10) & chr(10), "ALL" );
            return trim( t );
        }

        /**
         * Truncate a chunk at a sentence boundary where possible.
         */
        function truncateChunk( required string text, numeric maxLen=1800 ) {
            if ( len( text ) <= maxLen ) return text;
            var truncated  = left( text, maxLen );
            var lastPeriod = len( truncated ) - find( ".", reverse( truncated ) ) + 1;
            var cutPoint   = ( lastPeriod GT ( maxLen * 0.7 ) ) ? lastPeriod : maxLen;
            return left( text, cutPoint ) & " [truncated]";
        }

        /**
         * Build the core description chunk for a CFDocs JSON document.
         */
        function buildCoreChunk( required struct doc ) {
            var parts = [];
            arrayAppend( parts, doc.name & " (" & doc.type & ")" );
            if ( structKeyExists( doc, "syntax"      ) AND len( trim( doc.syntax      ) ) ) arrayAppend( parts, "Syntax: "        & doc.syntax      );
            if ( structKeyExists( doc, "member"      ) AND len( trim( doc.member      ) ) ) arrayAppend( parts, "Member syntax: " & doc.member      );
            if ( structKeyExists( doc, "returns"     ) AND len( trim( doc.returns     ) ) ) arrayAppend( parts, "Returns: "       & doc.returns     );
            if ( structKeyExists( doc, "description" ) AND len( trim( doc.description ) ) ) arrayAppend( parts, "Description: "  & doc.description );
            if ( structKeyExists( doc, "related" ) AND isArray( doc.related ) AND arrayLen( doc.related ) )
                arrayAppend( parts, "Related: " & arrayToList( doc.related, ", " ) );
            return truncateChunk( arrayToList( parts, chr(10) ) );
        }

        /**
         * Build the parameters chunk for a CFDocs JSON document.
         */
        function buildParamsChunk( required struct doc ) {
            if ( NOT structKeyExists( doc, "params" ) OR NOT isArray( doc.params ) OR NOT arrayLen( doc.params ) ) return "";
            var parts = [ doc.name & " — Parameters:" ];
            for ( var param in doc.params ) {
                var line = "  - " & param.name;
                if ( structKeyExists( param, "type"        ) AND len( trim( param.type        ) ) ) line &= " (" & param.type & ")";
                if ( structKeyExists( param, "required"    )                                       ) line &= param.required ? " [required]" : " [optional]";
                if ( structKeyExists( param, "description" ) AND len( trim( param.description ) ) ) line &= ": " & param.description;
                if ( structKeyExists( param, "default"     ) AND len( trim( param.default     ) ) ) line &= " (default: " & param.default & ")";
                if ( structKeyExists( param, "values" ) AND isArray( param.values ) AND arrayLen( param.values ) )
                    line &= " — values: " & arrayToList( param.values, ", " );
                arrayAppend( parts, line );
            }
            return truncateChunk( arrayToList( parts, chr(10) ) );
        }

        /**
         * Build the examples chunk for a CFDocs JSON document.
         */
        function buildExamplesChunk( required struct doc ) {
            if ( NOT structKeyExists( doc, "examples" ) OR NOT isArray( doc.examples ) OR NOT arrayLen( doc.examples ) ) return "";
            var parts = [ doc.name & " — Examples:" ];
            for ( var ex in doc.examples ) {
                if ( structKeyExists( ex, "title"       ) AND len( trim( ex.title       ) ) ) arrayAppend( parts, chr(10) & ex.title );
                if ( structKeyExists( ex, "description" ) AND len( trim( ex.description ) ) ) arrayAppend( parts, ex.description );
                if ( structKeyExists( ex, "code"        ) AND len( trim( ex.code        ) ) ) arrayAppend( parts, "Code: "   & ex.code   );
                if ( structKeyExists( ex, "result"      ) AND len( trim( ex.result      ) ) ) arrayAppend( parts, "Result: " & ex.result );
            }
            return truncateChunk( arrayToList( parts, chr(10) ) );
        }

        /**
         * Extract the Adobe docs URL from a CFDocs JSON document's engine metadata.
         */
        function getDocsUrl( required struct doc ) {
            if ( structKeyExists( doc, "engines" ) AND
                 structKeyExists( doc.engines, "coldfusion" ) AND
                 structKeyExists( doc.engines.coldfusion, "docs" ) ) {
                return doc.engines.coldfusion.docs;
            }
            return "";
        }

        /**
         * Build the VectorStore config struct for the active profile.
         * Centralised so ingest and reconnect always use the same shape.
         */
        function buildStoreConfig(
            required string  storeMode,
            required string  qdrantUrl,
            required string  qdrantCollection,
            required numeric embeddingDim,
            required string  embeddingModel,
            required string  ollamaBase
        ) {
            var embCfg = {
                provider   : "ollama",
                modelName  : embeddingModel,
                baseUrl    : ollamaBase,
                maxRetries : 1,
                timeout    : 300
            };
            if ( storeMode EQ "qdrant" ) {
                return {
                    provider       : "qdrant",
                    url            : qdrantUrl,
                    collectionName : qdrantCollection,
                    dimension      : embeddingDim,
                    embeddingModel : embCfg
                };
            } else {
                return {
                    provider       : "InMemory",
                    embeddingModel : embCfg
                };
            }
        }

        // ── Wipe / init store ────────────────────────────────────────────────

        if ( STORE_MODE EQ "qdrant" AND ingestMode EQ "wipe" ) {
            writeOutput( '<p class="text-warning log-line">&##128465; Wipe mode — deleting collection <strong>' & QDRANT_COLLECTION & '</strong>...</p>' );
            getPageContext().getOut().flush();
            if ( isDefined( "application.#STORE_KEY#" ) ) {
                try {
                    application[ STORE_KEY ].deleteCollection( QDRANT_COLLECTION );
                    writeOutput( '<p class="text-success log-line">&##10003; Collection deleted.</p>' );
                } catch ( any e ) {
                    writeOutput( '<p class="text-info log-line">&##8505; Collection may not exist yet — will be created fresh.</p>' );
                }
            } else {
                writeOutput( '<p class="text-info log-line">&##8505; No existing store in scope — collection will be created fresh.</p>' );
            }
        } else if ( STORE_MODE EQ "memory" ) {
            writeOutput( '<p class="text-info log-line">&##8505; InMemory mode — starting fresh.</p>' );
        } else {
            writeOutput( '<p class="text-info log-line">&##10133; Append mode — existing vectors will be kept.</p>' );
        }

        // Always reinitialise the store for this ingest run
        structDelete( application, STORE_KEY );

        storeConfig = buildStoreConfig(
            STORE_MODE, QDRANT_URL, QDRANT_COLLECTION,
            EMBEDDING_DIM, EMBEDDING_MODEL, OLLAMA_BASE
        );

        try {
            application[ STORE_KEY ] = VectorStore( storeConfig );
            if ( STORE_MODE EQ "qdrant" ) {
                writeOutput( '<p class="text-success log-line">&##10003; Connected to Qdrant — collection: <strong>' & QDRANT_COLLECTION & '</strong></p>' );
            } else {
                writeOutput( '<p class="text-success log-line">&##10003; InMemory vector store initialised.</p>' );
            }
        } catch ( any e ) {
            writeOutput( '<p class="text-danger log-line">&##10007; Failed to initialise vector store: ' & encodeForHTML( e.message ) & '</p>' );
            abort;
        }

        if ( doPDF )
            pdfFiles = directoryList( PDF_DIR, false, "query", "*.pdf" );
        else
            pdfFiles = queryNew( "name,directory,size", "varchar,varchar,integer" );

    </cfscript>

    <cfflush>

    <!--- ── PHASE 1: PDF Ingestion ── --->
    <cfif doPDF>

    <h4 class="mt-4 mb-3 text-info">&##128196; Phase 1 — PDF Ingestion</h4>

    <cfif pdfFiles.recordCount EQ 0>
        <div class="alert alert-warning">
            No PDFs found in <code><cfoutput>#PDF_DIR#</cfoutput></code>
        </div>
    <cfelse>

        <p class="text-secondary small">
            Processing <cfoutput><strong>#pdfFiles.recordCount# PDF file(s)</strong></cfoutput>...
        </p>

        <div class="table-responsive">
        <table class="table table-dark table-sm table-bordered align-middle mb-4">
            <thead class="table-secondary">
                <tr>
                    <th>##</th><th>File</th><th>Pages</th><th>Chunks</th>
                    <th>Stored</th><th>Errors</th><th>Avg ms</th><th>Time</th><th>Progress</th>
                </tr>
            </thead>
            <tbody>

            <cfset fileNum = 0>
            <cfloop query="pdfFiles">
                <cfset fileNum++>
                <cfset filePath    = pdfFiles.directory & "/" & pdfFiles.name>
                <cfset fileName    = pdfFiles.name>
                <cfset fileStart   = getTickCount()>
                <cfset storedCount = 0>
                <cfset errCount    = 0>
                <cfset pageCount   = 0>
                <cfset chunkCount  = 0>
                <cfset lastError   = "">

                <cfscript>
                    fileChunks  = [];
                    fileTotalMs = 0;

                    try {
                        cfpdf( action="extracttext", source=filePath, name="pdfPages" );

                        if ( isQuery( pdfPages ) ) {
                            pageCount = pdfPages.recordCount;
                            for ( page in pdfPages ) {
                                pageText = cleanText( page.pageContent );
                                if ( len( pageText ) < MIN_CHUNK_SIZE ) continue;
                                chunkIndex = 1;
                                for ( chunk in chunkText( pageText, CHUNK_SIZE, CHUNK_OVERLAP ) ) {
                                    cc = trim( chunk );
                                    if ( len( cc ) >= MIN_CHUNK_SIZE ) {
                                        arrayAppend( fileChunks, {
                                            text     : cc,
                                            metadata : {
                                                filename   : fileName,
                                                page       : page.pageNumber,
                                                chunkIndex : chunkIndex,
                                                source     : fileName & " — page " & page.pageNumber,
                                                type       : "pdf"
                                            }
                                        });
                                    }
                                    chunkIndex++;
                                }
                            }
                        } else if ( isSimpleValue( pdfPages ) ) {
                            pageCount  = 1;
                            chunkIndex = 1;
                            for ( chunk in chunkText( cleanText( pdfPages ), CHUNK_SIZE, CHUNK_OVERLAP ) ) {
                                cc = trim( chunk );
                                if ( len( cc ) >= MIN_CHUNK_SIZE ) {
                                    arrayAppend( fileChunks, {
                                        text     : cc,
                                        metadata : {
                                            filename   : fileName,
                                            page       : 0,
                                            chunkIndex : chunkIndex,
                                            source     : fileName,
                                            type       : "pdf"
                                        }
                                    });
                                }
                                chunkIndex++;
                            }
                        }

                        chunkCount = arrayLen( fileChunks );

                        for ( chunk in fileChunks ) {
                            cs = getTickCount();
                            try {
                                application[ STORE_KEY ].addAll( [ chunk ] );
                                storedCount++;
                            } catch ( any e ) {
                                errCount++;
                                lastError = e.message;
                            }
                            fileTotalMs += getTickCount() - cs;
                        }

                    } catch ( any e ) {
                        lastError = e.message;
                        errCount++;
                    }

                    elapsed = int( ( getTickCount() - fileStart ) / 1000 );
                    avgMs   = storedCount > 0 ? int( fileTotalMs / storedCount ) : 0;
                    pct     = chunkCount  > 0 ? int( ( storedCount / chunkCount ) * 100 ) : 0;
                </cfscript>

                <cfoutput>
                <tr>
                    <td class="text-secondary">#fileNum#</td>
                    <td>#fileName#</td>
                    <td>#pageCount#</td>
                    <td>#chunkCount#</td>
                    <td class="text-success">#storedCount#</td>
                    <td <cfif errCount GT 0>class="text-danger"</cfif>>
                        #errCount#
                        <cfif len( lastError )>
                            <div class="small text-secondary">#left( lastError, 80 )#</div>
                        </cfif>
                    </td>
                    <td>#avgMs#</td>
                    <td>#elapsed#s</td>
                    <td style="min-width:120px;">
                        <div class="progress">
                            <div class="progress-bar bg-success" style="width:#pct#%"></div>
                        </div>
                        <span class="small text-secondary">#pct#%</span>
                    </td>
                </tr>
                </cfoutput>
                <cfflush>
            </cfloop>

            </tbody>
        </table>
        </div>
    </cfif>

    </cfif> <!--- doPDF --->

    <cfif NOT doPDF>
        <div class="alert alert-secondary small">&#9197; PDF ingestion skipped.</div>
    </cfif>

    <!--- ── PHASE 2: CFDocs JSON Ingestion ── --->
    <cfif doJSON>

    <h4 class="mt-4 mb-3 text-info">&#128288; Phase 2 — CFDocs JSON Ingestion</h4>
    <cfflush>

    <cfscript>

        jsonFolder  = expandPath( "../cf_ai_docs/language_json/" );
        jsonFiles   = directoryList( jsonFolder, false, "query", "*.json" );
        jsonOk      = 0;
        jsonSkipped = 0;
        jsonFailed  = [];
        jsonChunks  = [];

        writeOutput( '<p class="small text-secondary">Found <strong>' & jsonFiles.recordCount & ' JSON file(s)</strong> in <code>' & jsonFolder & '</code>.</p>' );

        if ( jsonFiles.recordCount EQ 0 ) {
            writeOutput( '<div class="alert alert-warning small">No JSON files found — check that language_json/ exists under cf_ai_docs.</div>' );
        } else {

            for ( jRow in jsonFiles ) {
                filePath = jRow.directory & "/" & jRow.name;
                try {
                    rawJson = fileRead( filePath );
                    if ( NOT len( trim( rawJson ) ) ) { jsonSkipped++; continue; }

                    doc = deserializeJSON( rawJson );

                    if ( NOT structKeyExists( doc, "name" ) OR
                         NOT structKeyExists( doc, "description" ) OR
                         NOT len( trim( doc.description ) ) ) {
                        jsonSkipped++;
                        continue;
                    }

                    baseMeta = {
                        filename : jRow.name,
                        docName  : doc.name,
                        docType  : structKeyExists( doc, "type" ) ? doc.type : "unknown",
                        docsUrl  : getDocsUrl( doc ),
                        source   : "CFDocs: " & doc.name,
                        type     : "json"
                    };

                    coreText = buildCoreChunk( doc );
                    if ( len( trim( coreText ) ) >= MIN_CHUNK_SIZE )
                        arrayAppend( jsonChunks, { text: coreText, metadata: structCopy( baseMeta ) } );

                    paramsText = buildParamsChunk( doc );
                    if ( len( trim( paramsText ) ) >= MIN_CHUNK_SIZE ) {
                        pm    = structCopy( baseMeta );
                        pm.source  = "CFDocs: " & doc.name & " (parameters)";
                        pm.section = "parameters";
                        arrayAppend( jsonChunks, { text: paramsText, metadata: pm } );
                    }

                    exText = buildExamplesChunk( doc );
                    if ( len( trim( exText ) ) >= MIN_CHUNK_SIZE ) {
                        em    = structCopy( baseMeta );
                        em.source  = "CFDocs: " & doc.name & " (examples)";
                        em.section = "examples";
                        arrayAppend( jsonChunks, { text: exText, metadata: em } );
                    }

                    jsonOk++;

                } catch ( any e ) {
                    arrayAppend( jsonFailed, jRow.name & " (" & e.message & ")" );
                }
            }

            writeOutput( '<p class="small">Parsed <strong>' & jsonOk & ' file(s)</strong> &rarr; <strong>' & arrayLen( jsonChunks ) & ' chunks</strong> ready to embed.</p>' );
            if ( jsonSkipped ) writeOutput( '<p class="small text-secondary">&##9197; Skipped ' & jsonSkipped & ' (empty / no description).</p>' );
            if ( arrayLen( jsonFailed ) ) writeOutput( '<div class="alert alert-danger small">Failed: ' & arrayToList( jsonFailed, ", " ) & '</div>' );
        }

    </cfscript>

    <cfflush>

    <cfif arrayLen( jsonChunks ) GT 0>

        <div class="table-responsive">
        <table class="table table-dark table-sm table-bordered align-middle mb-4">
            <thead class="table-secondary">
                <tr>
                    <th>Batch</th><th>In batch</th><th>Total stored</th>
                    <th>Errors</th><th>Time</th><th>Progress</th>
                </tr>
            </thead>
            <tbody>

        <cfscript>
            batchSize   = 50;
            totalChunks = arrayLen( jsonChunks );
            batchNum    = 0;
            jsonStored  = 0;
            jsonErrors  = 0;
            batchStart  = 1;

            while ( batchStart <= totalChunks ) {
                batchEnd      = min( batchStart + batchSize - 1, totalChunks );
                batchChunks   = [];
                batchNum++;
                batchErrCount = 0;
                batchMs       = getTickCount();

                for ( i = batchStart; i <= batchEnd; i++ )
                    arrayAppend( batchChunks, jsonChunks[ i ] );

                try {
                    ids = application[ STORE_KEY ].addAll( batchChunks );
                    jsonStored += arrayLen( ids );
                } catch ( any e ) {
                    batchErrCount++;
                    jsonErrors++;
                }

                batchElapsed = int( ( getTickCount() - batchMs ) / 1000 );
                pct          = int( ( min( batchEnd, totalChunks ) / totalChunks ) * 100 );

                writeOutput( "<tr>
                    <td class='text-secondary'>" & batchNum & "</td>
                    <td>" & arrayLen( batchChunks ) & "</td>
                    <td class='text-success'>" & jsonStored & " / " & totalChunks & "</td>
                    <td " & ( batchErrCount ? "class='text-danger'" : "" ) & ">" & batchErrCount & "</td>
                    <td>" & batchElapsed & "s</td>
                    <td style='min-width:140px;'>
                        <div class='progress'><div class='progress-bar bg-success' style='width:" & pct & "%'></div></div>
                        <span class='small text-secondary'>" & pct & "%</span>
                    </td>
                </tr>" );

                getPageContext().getOut().flush();
                batchStart = batchEnd + 1;
            }
        </cfscript>

            </tbody>
        </table>
        </div>

    </cfif>

    </cfif> <!--- doJSON --->

    <cfif NOT doJSON>
        <div class="alert alert-secondary small">&#9197; JSON ingestion skipped.</div>
    </cfif>

    <cfoutput>
    <hr class="border-secondary">
    <div class="alert alert-success mt-3">
        &##10003; Ingest complete.
        <cfif STORE_MODE EQ "qdrant">
            Collection <strong>#QDRANT_COLLECTION#</strong> on <strong>#QDRANT_URL#</strong>.
            Data is persisted — reconnects automatically after CF restarts.
        <cfelse>
            InMemory store is live for this CF session. Re-ingest after a restart.
        </cfif>
    </div>
    <a href="search.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-success">&##128269; Go to Search</a>
    </cfoutput>

</cfif>

</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>