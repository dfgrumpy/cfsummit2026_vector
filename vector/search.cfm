<!--- search.cfm - Semantic search with optional RAG answer generation. --->
<cfinclude template="config.cfm">

<!--- ── Verify store is available ─────────────────────────────────────────── --->
<cfif NOT isDefined( "application.#STORE_KEY#" )>
    <!DOCTYPE html>
    <html lang="en" data-bs-theme="dark">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Search</title>
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

    results         = [];
    filteredResults = [];
    queryText       = "";
    aiAnswer        = "";
    aiError         = "";
    searched        = false;
    searchTime      = 0;
    aiTime          = 0;
    uniqueSources   = [];
    useRAG          = false;
    sourceFilter    = "all";

    if ( isDefined( "form.query" ) AND len( trim( form.query ) ) ) {

        queryText    = trim( form.query );
        searched     = true;
        topK         = val( form.topK     ?: TOP_K );
        minScore     = val( form.minScore ?: SIM_THRESHOLD );
        useRAG       = isDefined( "form.useRAG" ) AND form.useRAG EQ "1";
        sourceFilter = ( isDefined( "form.sourceFilter" ) AND len( trim( form.sourceFilter ) ) )
                       ? trim( form.sourceFilter ) : "all";

        // Fetch extra results when filtering so we have enough after the filter
        fetchK = ( sourceFilter NEQ "all" ) ? topK * 3 : topK;

        // Step 1: Vector search
        try {
            startTick = getTickCount();
            results   = application[ STORE_KEY ].search({
                text     : queryText,
                topK     : fetchK,
                minScore : minScore
            });
            searchTime = getTickCount() - startTick;
        } catch ( any e ) {
            aiError = "Search error: " & e.message;
        }

        // Step 2: Apply source type filter and trim to topK
        if ( sourceFilter EQ "all" ) {
            filteredResults = results;
        } else {
            for ( r in results ) {
                rType = structKeyExists( r.metadata, "type" ) ? lCase( trim( r.metadata.type ) ) : "";
                if ( rType EQ sourceFilter ) {
                    arrayAppend( filteredResults, r );
                    if ( arrayLen( filteredResults ) GTE topK ) break;
                }
            }
        }

        // Step 3: RAG — build context and call LLM
        if ( useRAG AND arrayLen( filteredResults ) GT 0 AND NOT len( aiError ) ) {
            try {
                contextParts = [];
                for ( result in filteredResults ) {
                    arrayAppend( contextParts, "[Source: " & result.metadata.source & "]" & chr(10) & result.text );
                    if ( NOT arrayContains( uniqueSources, result.metadata.source ) )
                        arrayAppend( uniqueSources, result.metadata.source );
                }

                prompt = "You are a helpful assistant for ColdFusion developers. " &
                         "Answer the question below using ONLY the context provided. " &
                         "If the context does not contain enough information to answer, " &
                         "say so clearly rather than guessing. " &
                         "Be concise and practical. " &
                         "Do not repeat the question back." &
                         chr(10) & chr(10) &
                         "CONTEXT:" & chr(10) &
                         arrayToList( contextParts, chr(10) & chr(10) ) &
                         chr(10) & chr(10) &
                         "QUESTION: " & queryText;

                aiStartTick = getTickCount();
                chatModel   = ChatModel( chatModelConfig );
                response    = chatModel.chat( prompt );
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
    <title>Search<cfif useRAG> w/ RAG</cfif></title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <style>
        .score-badge  { font-size: .7rem; }
        .excerpt      { font-size: .85rem; white-space: pre-wrap; }
        .rag-answer   { white-space: pre-wrap; font-size: .95rem; line-height: 1.7; }
    </style>
</head>
<body class="bg-dark text-light">
<div class="container-xl py-4">

<cfset PAGE_TITLE = "Search">
<cfinclude template="_profile_bar.cfm">

<h2 class="mb-1">&#128269; Semantic Search</h2>
<p class="text-secondary small mb-4">
    Ask a question. Toggle RAG to get an AI-generated answer on top of the retrieved chunks.
</p>

<!--- ── Search form ─────────────────────────────────────────────────────── --->
<form method="post" id="searchForm">
    <input type="hidden" name="profile"      value="<cfoutput>#encodeForHTMLAttribute( ACTIVE_PROFILE )#</cfoutput>">
    <input type="hidden" name="useRAG"       id="useRAGField"       value="<cfoutput>#useRAG ? 1 : 0#</cfoutput>">
    <input type="hidden" name="sourceFilter" id="sourceFilterField" value="<cfoutput>#encodeForHTMLAttribute( sourceFilter )#</cfoutput>">

    <p class="text-secondary small">
        &#128161; Ask naturally — e.g. <em>"How do I configure a vector store?"</em>
    </p>

    <div class="input-group mb-3">
        <input type="text"
               name="query"
               id="queryField"
               class="form-control form-control-lg bg-dark text-light border-secondary"
               value="<cfoutput>#encodeForHTML( queryText )#</cfoutput>"
               placeholder="Ask a question about your documents..."
               autofocus>
        <button class="btn btn-primary btn-lg px-4" type="submit">Ask</button>
    </div>

    <div class="d-flex flex-wrap align-items-center gap-3 mb-3">

        <!--- Top K --->
        <div class="d-flex align-items-center gap-2">
            <label class="form-label text-secondary small mb-0">Sources (topK)</label>
            <select name="topK" id="topKField"
                    class="form-select form-select-sm bg-dark text-light border-secondary"
                    style="width:auto;">
                <cfoutput>
                <cfloop list="1,2,3,5,7,10,15,20" index="n">
                    <option value="#n#" <cfif val( form.topK ?: TOP_K ) EQ n>selected</cfif>>#n#</option>
                </cfloop>
                </cfoutput>
            </select>
        </div>

        <!--- Min score --->
        <div class="d-flex align-items-center gap-2">
            <label class="form-label text-secondary small mb-0">Min score</label>
            <select name="minScore" id="minScoreField"
                    class="form-select form-select-sm bg-dark text-light border-secondary"
                    style="width:auto;">
                <cfoutput>
                <cfloop list="0.0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9" index="s">
                    <option value="#s#" <cfif val( form.minScore ?: SIM_THRESHOLD ) EQ val(s)>selected</cfif>>#s#</option>
                </cfloop>
                </cfoutput>
            </select>
        </div>

        <!--- Source filter --->
        <div class="btn-group btn-group-sm" role="group">
            <cfoutput>
            <button type="button"
                    class="btn <cfif sourceFilter EQ 'all'>btn-primary<cfelse>btn-outline-secondary</cfif>"
                    onclick="setFilter('all')">All</button>
            <button type="button"
                    class="btn <cfif sourceFilter EQ 'pdf'>btn-warning text-dark<cfelse>btn-outline-secondary</cfif>"
                    onclick="setFilter('pdf')">PDFs only</button>
            <button type="button"
                    class="btn <cfif sourceFilter EQ 'json'>btn-info text-dark<cfelse>btn-outline-secondary</cfif>"
                    onclick="setFilter('json')">JSON only</button>
            </cfoutput>
        </div>

        <!--- RAG toggle --->
        <cfoutput>
        <button type="button"
                id="ragToggleBtn"
                class="btn btn-sm <cfif useRAG>btn-success<cfelse>btn-outline-secondary</cfif>"
                onclick="toggleRAG()">
            &##129302; RAG <span id="ragState"><cfif useRAG>On<cfelse>Off</cfif></span>
        </button>
        </cfoutput>

    </div>
</form>

<!--- Debug redirect form (hidden, submitted by JS) --->
<form method="post" action="debug_rag.cfm" id="debugForm">
    <input type="hidden" name="profile"   value="<cfoutput>#encodeForHTMLAttribute( ACTIVE_PROFILE )#</cfoutput>">
    <input type="hidden" name="query"     id="debugQuery">
    <input type="hidden" name="topK"      id="debugTopK">
    <input type="hidden" name="minScore"  id="debugMinScore">
</form>

<!--- ── Error ────────────────────────────────────────────────────────────── --->
<cfif len( aiError )>
    <div class="alert alert-danger mt-3">
        &#10007; <cfoutput>#encodeForHTML( aiError )#</cfoutput>
    </div>
</cfif>

<!--- ── Results ─────────────────────────────────────────────────────────── --->
<cfif searched>
    <cfoutput>
    <div class="d-flex flex-wrap gap-2 align-items-center mb-3 small text-secondary">
        <span>Query: <strong class="text-light">#encodeForHTML( queryText )#</strong></span>
        <span class="vr"></span>
        <span>Mode: <strong class="text-light"><cfif useRAG>RAG On<cfelse>RAG Off</cfif></strong></span>
        <span class="vr"></span>
        <span>Source: <strong class="text-light">
            <cfif sourceFilter EQ "all">All<cfelseif sourceFilter EQ "pdf">PDFs<cfelse>JSON</cfif>
        </strong></span>
        <span class="vr"></span>
        <span>Chunks: <strong class="text-light">#arrayLen( filteredResults )#</strong></span>
        <span class="vr"></span>
        <span>Search: <strong class="text-light">#searchTime#ms</strong></span>
        <cfif useRAG AND aiTime GT 0>
            <span class="vr"></span>
            <span>AI: <strong class="text-light">#aiTime#ms</strong></span>
        </cfif>
    </div>
    </cfoutput>

    <cfif arrayLen( filteredResults ) EQ 0>
        <div class="alert alert-secondary">
            No results above the minimum score threshold.
            Try lowering Min score or rephrasing.
        </div>
    <cfelse>

        <!--- RAG answer --->
        <cfif useRAG AND NOT len( aiError ) AND len( trim( aiAnswer ) )>
            <div class="card bg-dark border-success mb-4">
                <div class="card-header border-success text-success fw-bold">&#129302; Answer</div>
                <div class="card-body">
                    <div class="rag-answer"><cfoutput>#encodeForHTML( aiAnswer )#</cfoutput></div>
                    <cfif arrayLen( uniqueSources )>
                        <hr class="border-secondary">
                        <p class="small text-secondary mb-1">&#128196; Sources used:</p>
                        <ul class="small text-secondary mb-0">
                            <cfloop array="#uniqueSources#" index="src">
                                <li><cfoutput>#encodeForHTML( src )#</cfoutput></li>
                            </cfloop>
                        </ul>
                    </cfif>
                    <div class="small text-secondary mt-2">
                        <cfoutput>Generated by #LLM_MODEL# via Ollama in #aiTime#ms</cfoutput>
                    </div>
                </div>
            </div>
        </cfif>

        <!--- Chunk list header --->
        <div class="d-flex justify-content-between align-items-center mb-2">
            <span class="text-secondary small">
                &#128218; Retrieved chunks
                (<cfoutput>#arrayLen( filteredResults )#</cfoutput>)<cfif useRAG> — used as context</cfif>
            </span>
            <button class="btn btn-sm btn-outline-warning" onclick="submitDebug()">
                &#128300; Debug Search
            </button>
        </div>

        <!--- Individual chunks --->
        <cfloop array="#filteredResults#" index="result">
            <cfoutput>
            <cfset scoreVal   = result.score>
            <cfset scoreClass = ( scoreVal GTE 0.7 ) ? "bg-success" : ( ( scoreVal GTE 0.5 ) ? "bg-warning text-dark" : "bg-secondary" )>
            <cfset rType      = structKeyExists( result.metadata, "type" ) ? lCase( result.metadata.type ) : "">
            <div class="card bg-dark border-secondary mb-2">
                <div class="card-body py-2 px-3">
                    <div class="d-flex justify-content-between align-items-center mb-1">
                        <span class="fw-bold small">
                            <cfif rType EQ "pdf">&##128196;<cfelseif rType EQ "json">&##128288;<cfelse>&##128206;</cfif>
                            #encodeForHTML( result.metadata.source )#
                            <span class="badge <cfif rType EQ 'pdf'>bg-warning text-dark<cfelse>bg-info text-dark</cfif> ms-1 score-badge">
                                #rType#
                            </span>
                        </span>
                        <span class="badge #scoreClass# score-badge">#numberFormat( result.score, "0.000" )#</span>
                    </div>
                    <div class="excerpt text-secondary">
                        #encodeForHTML( left( result.text, 400 ) )#<cfif len( result.text ) GT 400>&hellip;</cfif>
                    </div>
                </div>
            </div>
            </cfoutput>
        </cfloop>

    </cfif>
</cfif>

</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
    function toggleRAG() {
        const field = document.getElementById('useRAGField');
        const btn   = document.getElementById('ragToggleBtn');
        const state = document.getElementById('ragState');
        if ( field.value === '1' ) {
            field.value   = '0';
            btn.className = btn.className.replace('btn-success', 'btn-outline-secondary');
            state.textContent = 'Off';
        } else {
            field.value   = '1';
            btn.className = btn.className.replace('btn-outline-secondary', 'btn-success');
            state.textContent = 'On';
        }
    }

    function setFilter(val) {
        document.getElementById('sourceFilterField').value = val;
        document.getElementById('searchForm').submit();
    }

    function submitDebug() {
        document.getElementById('debugQuery').value    = document.getElementById('queryField').value;
        document.getElementById('debugTopK').value     = document.getElementById('topKField').value;
        document.getElementById('debugMinScore').value = document.getElementById('minScoreField').value;
        document.getElementById('debugForm').submit();
    }
</script>
</body>
</html>
