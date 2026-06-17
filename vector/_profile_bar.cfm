<!--- _profile_bar.cfm --->
<!--- Shared Bootstrap navbar strip. Requires config.cfm and PAGE_TITLE to be set first. --->
<cfoutput>
<nav class="navbar navbar-dark bg-dark border-bottom border-secondary mb-4 px-3 py-2">
    <div class="d-flex flex-wrap align-items-center gap-3 w-100">

        <span class="fw-bold text-info fs-6">#PAGE_TITLE#</span>

        <div class="d-flex flex-wrap gap-2 align-items-center small">
            <span class="text-secondary">Profile:</span>
            <span class="badge bg-success">#PROFILE_LABEL#</span>

            <span class="text-secondary ms-1">Embed on:</span>
            <span class="badge bg-warning text-dark">#cfg.embedLocation#</span>

            <span class="text-secondary ms-1">Model:</span>
            <span class="badge bg-info text-dark">#EMBEDDING_MODEL#</span>

            <span class="text-secondary ms-1">Search on:</span>
            <cfif STORE_MODE EQ "qdrant">
                <span class="badge bg-primary">#cfg.searchLocation#</span>
            <cfelse>
                <span class="badge bg-secondary">#cfg.searchLocation#</span>
            </cfif>
        </div>

        <div class="d-flex gap-2 ms-auto">
            <cfif PAGE_TITLE NEQ "Ingest"><a href="ingest.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-sm btn-outline-primary">Ingest</a></cfif>
            <cfif PAGE_TITLE NEQ "Search"><a href="search.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-sm btn-outline-success">Search</a></cfif>
            <cfif PAGE_TITLE NEQ "Debug"><a href="debug_rag.cfm?profile=#ACTIVE_PROFILE#" class="btn btn-sm btn-outline-warning">Debug</a></cfif>
            <a href="index.cfm" class="btn btn-sm btn-outline-secondary">Home</a>
        </div>

    </div>
</nav>
</cfoutput>
