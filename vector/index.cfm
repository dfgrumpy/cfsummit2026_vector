<!--- index.cfm - Home page. Choose a profile then go to Ingest / Search / Debug. --->
<cfinclude template="config.cfm">
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>CF AI &mdash; Vector</title>
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
        <h1 class="display-5 fw-bold text-info">ColdFusion 2025.8 AI <br>Vector Semantic Search</h1>
        <p class="text-secondary">Choose your profile below</p>
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
                                <span class="text-light">Embed on</span>
                                <span class="float-end">#p.embedLocation#</span>
                            </li>
                            <li class="mb-1">
                                <span class="text-light">Search on</span>
                                <span class="float-end">#p.searchLocation#</span>
                            </li>
                            <li class="mb-1">
                                <span class="text-light">Embedding</span>
                                <span class="float-end font-monospace">#p.embeddingModel#</span>
                            </li>
                            <li class="mb-1">
                                <span class="text-light">Dimensions</span>
                                <span class="float-end">#p.embeddingDim#d</span>
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
        <a id="btn-ingest"      href="ingest.cfm?profile=#ACTIVE_PROFILE#"      class="btn btn-primary btn-lg px-4">&##128196; Ingest</a>
        <a id="btn-ingest-demo" href="ingest_demo.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-outline-primary btn-lg px-4">&##127917; Demo Ingest</a>
        <a id="btn-search" href="search.cfm?profile=#ACTIVE_PROFILE#"    class="btn btn-success btn-lg px-4">&##128269; Search</a>
        <a id="btn-debug"  href="debug_rag.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-warning btn-lg px-4 text-dark">&##128300; Debug</a>
        <button id="btn-test" onclick="testEndpoint()" class="btn btn-secondary btn-lg px-4">&##128268; Test</button>
        <a id="btn-kb" href="search_docs.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-outline-light btn-lg px-4">&##127970; KB Search</a>
    </div>

    <!--- Test result panel --->
    <div id="test-result" class="mt-4" style="display:none; max-width:540px; margin:0 auto;"></div>

    </cfoutput>

</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
    const profileLabels = <cfoutput>#serializeJSON( profiles.reduce( function(acc,k,v){ acc[k]=v.label; return acc; }, {} ) )#</cfoutput>;
    let activeProfile = '<cfoutput>#ACTIVE_PROFILE#</cfoutput>';

    function selectProfile(name) {
        activeProfile = name;
        document.cookie = 'cfai_profile=' + encodeURIComponent(name) + '; path=/; max-age=' + (365*24*60*60) + '; SameSite=Lax';
        document.querySelectorAll('.profile-card').forEach(c => c.classList.remove('selected'));
        event.currentTarget.classList.add('selected');
        document.getElementById('btn-ingest').href      = 'ingest.cfm?profile='      + name;
        document.getElementById('btn-ingest-demo').href = 'ingest_demo.cfm?profile=' + name;
        document.getElementById('btn-search').href = 'search.cfm?profile='      + name;
        document.getElementById('btn-debug').href  = 'debug_rag.cfm?profile='   + name;
        document.getElementById('btn-kb').href     = 'search_docs.cfm?profile=' + name;
        document.getElementById('activeLabel').textContent = profileLabels[name] || name;
        document.getElementById('test-result').style.display = 'none';
    }

    function testEndpoint() {
        const btn    = document.getElementById('btn-test');
        const panel  = document.getElementById('test-result');
        btn.disabled = true;
        btn.textContent = '⏳ Testing…';
        panel.style.display = 'none';

        fetch('test_endpoint.cfm?profile=' + encodeURIComponent(activeProfile))
            .then(r => r.json())
            .then(d => {
                const ollamaIcon = d.ollama.ok ? '✅' : '❌';
                const storeIcon  = d.store.ok  ? '✅' : (d.store.vectorCount === 0 ? '⚠️' : '❌');
                const overallCls = d.ok ? 'border-success' : (d.ollama.ok || d.store.ok ? 'border-warning' : 'border-danger');
                const countBadge = d.store.vectorCount >= 0
                    ? `<span class="badge bg-info text-dark ms-2">${d.store.vectorCount} vectors</span>` : '';

                panel.innerHTML = `
                    <div class="card bg-dark border ${overallCls} mt-3">
                        <div class="card-body small">
                            <h6 class="card-title text-secondary mb-3">Endpoint Test — ${d.label}</h6>
                            <div class="mb-2">${ollamaIcon} <strong class="text-light">Ollama</strong>
                                <span class="text-secondary ms-2">${d.ollama.message}</span></div>
                            <div>${storeIcon} <strong class="text-light">Vector Store</strong>${countBadge}
                                <span class="text-secondary ms-2">${d.store.message}</span></div>
                        </div>
                    </div>`;
                panel.style.display = 'block';
            })
            .catch(err => {
                panel.innerHTML = `<div class="alert alert-danger mt-3 small">Test failed: ${err}</div>`;
                panel.style.display = 'block';
            })
            .finally(() => {
                btn.disabled = false;
                btn.innerHTML = '&#128268; Test';
            });
    }
</script>

</body>
</html>
