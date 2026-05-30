<!--- index.cfm - Home page. Choose a profile then go to Ingest / Search / Debug. --->
<cfinclude template="config.cfm">
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>CF AI &mdash; Vector RAG</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <style>
        body { min-height: 100vh; display: flex; flex-direction: column; justify-content: center; }

        .profile-card {
            cursor: pointer;
            border: 2px solid var(--bs-border-color);
            transition: border-color .15s, box-shadow .15s;
        }
        .profile-card:hover {
            border-color: var(--bs-info);
            box-shadow: 0 0 0 .15rem rgba(13,202,240,.15);
        }
        .profile-card.selected {
            border-color: var(--bs-success);
            box-shadow: 0 0 0 .2rem rgba(25,135,84,.25);
        }
    </style>
</head>
<body class="bg-dark text-light">

<div class="container py-5">

    <div class="text-center mb-5">
        <h1 class="display-5 fw-bold text-info">CF AI &mdash; Vector Semantic Search</h1>
        <p class="text-secondary">ColdFusion 2025 &nbsp;&middot;&nbsp; Ollama &nbsp;&middot;&nbsp; RAG Pipeline</p>
    </div>

    <cfoutput>

    <!--- Profile cards --->
    <div class="row g-4 justify-content-center mb-5">
        <cfloop collection="#profiles#" item="profileKey">
            <cfset p = profiles[ profileKey ]>
            <div class="col-12 col-sm-6 col-xl-3">
                <div class="card profile-card h-100 bg-dark <cfif ACTIVE_PROFILE EQ profileKey>selected</cfif>"
                     onclick="selectProfile('#profileKey#')">
                    <div class="card-body">
                        <h5 class="card-title text-info mb-3">#p.label#</h5>
                        <ul class="list-unstyled small text-secondary mb-0">
                            <li class="mb-1">
                                <span class="text-light">Endpoint</span>
                                <span class="float-end">#p.endpoint#</span>
                            </li>
                            <li class="mb-1">
                                <span class="text-light">Embedding</span>
                                <span class="float-end font-monospace">#p.embeddingModel#</span>
                            </li>
                            <li class="mb-1">
                                <span class="text-light">LLM</span>
                                <span class="float-end font-monospace">#p.llmModel#</span>
                            </li>
                            <li class="mb-1">
                                <span class="text-light">Chunk</span>
                                <span class="float-end">#p.chunkSize# / #p.chunkOverlap#</span>
                            </li>
                            <li class="mt-2">
                                <cfif p.storeMode EQ "qdrant">
                                    <span class="badge bg-primary w-100">Qdrant &mdash; persistent</span>
                                <cfelse>
                                    <span class="badge bg-secondary w-100">InMemory &mdash; ephemeral</span>
                                </cfif>
                            </li>
                        </ul>
                    </div>
                </div>
            </div>
        </cfloop>
    </div>

    <!--- Active profile summary --->
    <div class="text-center mb-4">
        <span class="text-secondary small">Selected:&nbsp;</span>
        <span class="badge bg-success fs-6" id="activeLabel">#profiles[ ACTIVE_PROFILE ].label#</span>
    </div>

    <!--- Action buttons --->
    <div class="d-flex gap-3 justify-content-center flex-wrap">
        <a id="btn-ingest" href="ingest.cfm?profile=#ACTIVE_PROFILE#"    class="btn btn-primary btn-lg px-4">&##128196; Ingest</a>
        <a id="btn-search" href="search.cfm?profile=#ACTIVE_PROFILE#"    class="btn btn-success btn-lg px-4">&##128269; Search</a>
        <a id="btn-debug"  href="debug_rag.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-warning btn-lg px-4 text-dark">&##128300; Debug</a>
    </div>

    </cfoutput>

</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
    const profileLabels = <cfoutput>#serializeJSON( profiles.reduce( function(acc,k,v){ acc[k]=v.label; return acc; }, {} ) )#</cfoutput>;

    function selectProfile(name) {
        document.querySelectorAll('.profile-card').forEach(c => c.classList.remove('selected'));
        event.currentTarget.classList.add('selected');
        document.getElementById('btn-ingest').href = 'ingest.cfm?profile='    + name;
        document.getElementById('btn-search').href = 'search.cfm?profile='    + name;
        document.getElementById('btn-debug').href  = 'debug_rag.cfm?profile=' + name;
        document.getElementById('activeLabel').textContent = profileLabels[name] || name;
    }
</script>

</body>
</html>
