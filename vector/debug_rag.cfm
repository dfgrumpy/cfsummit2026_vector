<!--- debug_rag.cfm - Full RAG pipeline debugger: query -> vector search -> prompt -> LLM -> answer --->
<cfinclude template="config.cfm">

<!--- ── Verify store is available ─────────────────────────────────────────── --->
<cfif NOT isDefined( "application.#STORE_KEY#" )>
    <!DOCTYPE html>
    <html lang="en" data-bs-theme="dark">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Debug</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    </head>
    <body class="bg-dark text-light p-4">
        <div class="alert alert-danger">
            <strong>Vector store not available</strong> for profile
            <em><cfoutput>#PROFILE_LABEL#</cfoutput></em>.<br>
            <cfif STORE_MODE EQ "memory">
                InMemory stores do not survive a CF restart. Please
                <a href="ingest.cfm?profile=<cfoutput>#ACTIVE_PROFILE#</cfoutput>">re-ingest</a> first.
            <cfelse>
                Could not reconnect to Qdrant at
                <code><cfoutput>#QDRANT_URL#</cfoutput></code>.
                Confirm Qdrant is running then
                <a href="ingest.cfm?profile=<cfoutput>#ACTIVE_PROFILE#</cfoutput>">go to Ingest</a>.
            </cfif>
        </div>
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    </body>
    </html>
    <cfabort>
</cfif>

<cfscript>

    chatModelConfig = {
        provider    : "ollama",
        modelName   : LLM_MODEL,
        baseUrl     : OLLAMA_BASE,
        temperature : 0.2,
        maxRetries  : 3
    };

    queryText    = "";
    results      = [];
    contextBlock = "";
    fullPrompt   = "";
    aiAnswer     = "";
    aiError      = "";
    searched     = false;
    searchTime   = 0;
    aiTime       = 0;

    if ( isDefined( "form.query" ) AND len( trim( form.query ) ) ) {

        queryText = trim( form.query );
        searched  = true;
        topK      = val( form.topK     ?: TOP_K );
        minScore  = val( form.minScore ?: SIM_THRESHOLD );

        // Step 1: Vector search
        try {
            startTick = getTickCount();
            results   = application[ STORE_KEY ].search({
                text     : queryText,
                topK     : topK,
                minScore : minScore
            });
            searchTime = getTickCount() - startTick;
        } catch ( any e ) {
            aiError = "Search error: " & e.message;
        }

        // Step 2: Build context block and full prompt
        if ( arrayLen( results ) GT 0 AND NOT len( aiError ) ) {
            contextParts = [];
            for ( result in results )
                arrayAppend( contextParts, "[Source: " & result.metadata.source & "]" & chr(10) & result.text );
            contextBlock = arrayToList( contextParts, chr(10) & chr(10) & "---" & chr(10) & chr(10) );

            fullPrompt = "You are a helpful assistant for ColdFusion developers. " &
                         "Answer the question below using ONLY the context provided. " &
                         "If the context does not contain enough information to answer, " &
                         "say so clearly rather than guessing. " &
                         "Be concise and practical. " &
                         "Do not repeat the question back." &
                         chr(10) & chr(10) &
                         "CONTEXT:" & chr(10) &
                         contextBlock &
                         chr(10) & chr(10) &
                         "QUESTION: " & queryText;

            // Step 3: Call LLM
            try {
                aiStartTick = getTickCount();
                chatModel   = ChatModel( chatModelConfig );
                response    = chatModel.chat( fullPrompt );
                aiTime      = getTickCount() - aiStartTick;
                aiAnswer    = response.message ?: response.content ?: serializeJSON( response );
            } catch ( any e ) {
                aiError = "AI generation error: " & e.message;
            }
        }
    }

</cfscript>

<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>RAG Debugger</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <style>
        pre.prompt-box {
            max-height: 360px;
            overflow-y: auto;
            font-size: .75rem;
            white-space: pre-wrap;
            word-break: break-word;
        }
        .excerpt { font-size: .8rem; white-space: pre-wrap; }
    </style>
</head>
<body class="bg-dark text-light">
<div class="container-xl py-4">

<cfset PAGE_TITLE = "Debug">
<cfinclude template="_profile_bar.cfm">

<h2 class="mb-1">&#128300; RAG Pipeline Debugger</h2>
<p class="text-secondary small mb-4">
    Shows every step: query &rarr; vector search &rarr; prompt &rarr; LLM &rarr; answer.
</p>

<!--- ── Query form ──────────────────────────────────────────────────────── --->
<form method="post">
    <input type="hidden" name="profile" value="<cfoutput>#encodeForHTMLAttribute( ACTIVE_PROFILE )#</cfoutput>">

    <div class="input-group mb-2">
        <input type="text"
               name="query"
               class="form-control form-control-lg bg-dark text-light border-secondary"
               value="<cfoutput>#encodeForHTML( queryText )#</cfoutput>"
               placeholder="e.g. How do I configure a vector store provider?"
               autofocus>
        <button class="btn btn-warning text-dark btn-lg px-4" type="submit">Run Pipeline</button>
    </div>

    <div class="d-flex gap-3 align-items-center mb-4 small">
        <div class="d-flex align-items-center gap-2">
            <label class="text-secondary mb-0">Sources (topK)</label>
            <select name="topK"
                    class="form-select form-select-sm bg-dark text-light border-secondary"
                    style="width:auto;">
                <cfoutput>
                <cfloop list="1,2,3,5,7,10,15,20" index="n">
                    <option value="#n#" <cfif val( form.topK ?: TOP_K ) EQ n>selected</cfif>>#n#</option>
                </cfloop>
                </cfoutput>
            </select>
        </div>
        <div class="d-flex align-items-center gap-2">
            <label class="text-secondary mb-0">Min score</label>
            <select name="minScore"
                    class="form-select form-select-sm bg-dark text-light border-secondary"
                    style="width:auto;">
                <cfoutput>
                <cfloop list="0.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9" index="s">
                    <option value="#s#" <cfif val( form.minScore ?: SIM_THRESHOLD ) EQ val(s)>selected</cfif>>#s#</option>
                </cfloop>
                </cfoutput>
            </select>
        </div>
    </div>
</form>

<!--- ── Error ────────────────────────────────────────────────────────────── --->
<cfif len( aiError )>
    <div class="alert alert-danger">
        &#10007; <cfoutput>#encodeForHTML( aiError )#</cfoutput>
    </div>
</cfif>

<!--- ── Pipeline results ─────────────────────────────────────────────────── --->
<cfif searched AND NOT len( aiError )>
    <cfoutput>

    <!--- Timing strip --->
    <div class="d-flex flex-wrap gap-2 mb-4">
        <span class="badge bg-secondary">Query: #encodeForHTML( queryText )#</span>
        <span class="badge bg-dark border border-secondary">Chunks: #arrayLen( results )#</span>
        <span class="badge bg-dark border border-secondary">Search: #searchTime#ms</span>
        <span class="badge bg-dark border border-secondary">AI: #aiTime#ms</span>
        <span class="badge bg-dark border border-secondary">Total: #searchTime + aiTime#ms</span>
    </div>

    <cfif arrayLen( results ) EQ 0>
        <div class="alert alert-secondary">
            No results above minScore threshold. Try lowering it or rephrasing.
        </div>
    <cfelse>

        <!--- Two-column layout: chunks | prompt --->
        <div class="row g-4 mb-4">

            <!--- Step 1: Vector search results --->
            <div class="col-12 col-lg-6">
                <div class="card bg-dark border-secondary h-100">
                    <div class="card-header border-secondary d-flex justify-content-between align-items-center">
                        <span class="text-info fw-bold">&##128230; Step 1 — Vector Search</span>
                        <span class="badge bg-secondary">#searchTime#ms &middot; #arrayLen( results )# chunks</span>
                    </div>
                    <div class="card-body overflow-auto" style="max-height:500px;">
                        <cfloop array="#results#" index="result">
                            <cfset scoreVal   = result.score>
                            <cfset scoreClass = ( scoreVal GTE 0.7 ) ? "bg-success" : ( ( scoreVal GTE 0.5 ) ? "bg-warning text-dark" : "bg-secondary" )>
                            <div class="card bg-dark border-secondary mb-2">
                                <div class="card-body py-2 px-3">
                                    <div class="d-flex justify-content-between align-items-start mb-1">
                                        <span class="small fw-bold text-info">
                                            #encodeForHTML( result.metadata.source )#
                                        </span>
                                        <span class="badge #scoreClass# ms-2 flex-shrink-0">
                                            #numberFormat( result.score, "0.000" )#
                                        </span>
                                    </div>
                                    <div class="excerpt text-secondary">
                                        #encodeForHTML( left( result.text, 300 ) )#<cfif len( result.text ) GT 300>&hellip;</cfif>
                                    </div>
                                </div>
                            </div>
                        </cfloop>
                    </div>
                </div>
            </div>

            <!--- Step 2: Full prompt --->
            <div class="col-12 col-lg-6">
                <div class="card bg-dark border-secondary h-100">
                    <div class="card-header border-secondary d-flex justify-content-between align-items-center">
                        <span class="text-info fw-bold">&##128221; Step 2 — Prompt sent to #LLM_MODEL#</span>
                        <span class="badge bg-secondary">#len( fullPrompt )# chars</span>
                    </div>
                    <div class="card-body">
                        <pre class="prompt-box text-secondary bg-black rounded p-3">#encodeForHTML( fullPrompt )#</pre>
                    </div>
                </div>
            </div>

        </div>

        <!--- Step 3: LLM answer (full width) --->
        <div class="card bg-dark border-success mb-4">
            <div class="card-header border-success d-flex justify-content-between align-items-center">
                <span class="text-success fw-bold">&##129302; Step 3 — #LLM_MODEL# Answer</span>
                <span class="badge bg-secondary">#aiTime#ms via Ollama</span>
            </div>
            <div class="card-body">
                <pre class="text-light mb-0" style="white-space:pre-wrap; font-size:.9rem;">#encodeForHTML( aiAnswer )#</pre>
            </div>
        </div>

    </cfif>
    </cfoutput>
</cfif>

</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
