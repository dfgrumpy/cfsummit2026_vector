<!--- search_docs.cfm - Consumer-facing document search demo (PDF only, no RAG) --->
<cfinclude template="config.cfm">

<cfif NOT isDefined( "application.#STORE_KEY#" )>
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Knowledge Base — Harbourview Technologies</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    </head>
    <body class="bg-light p-4">
        <div class="alert alert-warning">
            Vector store not available for profile <strong><cfoutput>#PROFILE_LABEL#</cfoutput></strong>.
            Please <a href="ingest.cfm?profile=<cfoutput>#ACTIVE_PROFILE#</cfoutput>">ingest documents</a> first.
        </div>
    </body>
    </html>
    <cfabort>
</cfif>

<cfscript>

    SEARCH_TOP_K     = 5;
    SEARCH_MIN_SCORE = 0.4;

    queryText   = "";
    results     = [];
    searched    = false;
    searchError = "";

    titleMap = {
        "Beta_2025_7_Guardrails for AI ethics and safety.pdf"  : "AI Ethics & Safety Guardrails",
        "Beta_2025_7_Language enhancements.pdf"                : "Language Enhancements — Update 7",
        "Beta_2025_7_UPDATED- MCPs with ColdFusion.pdf"        : "Model Context Protocol (MCP) Integration",
        "Beta_2025_7_VS Code plugin enhancements.pdf"          : "VS Code Plugin — What's New",
        "Bug fixes in 2025.1 Beta.pdf"                         : "Bug Fixes — 2025.1 Beta",
        "CF2025_Update7_AI_Models.pdf"                         : "AI Model Providers in ColdFusion 2025",
        "CF_Beta_RAG.pdf"                                      : "Building RAG Pipelines in ColdFusion",
        "ColdFusion_Argon2_Password_Hashing_Guide.pdf"         : "Password Hashing with Argon2",
        "ColdFusion_Passkey_User_Guide.pdf"                    : "Passkey & Passwordless Authentication",
        "JVM changes.pdf"                                      : "JVM Changes & Performance Updates",
        "Known issues in CF 2025 Update 7 Beta.pdf"            : "Known Issues — Update 7 Beta",
        "MCP Function Reference.pdf"                           : "MCP Function Reference",
        "OEM upgrades.pdf"                                     : "OEM Component Upgrades",
        "Vector Database Function Reference.pdf"               : "Vector Database Function Reference",
        "Vector Database.pdf"                                  : "Vector Database — Overview & Setup",
        "cf-security-analyzer.pdf"                             : "ColdFusion Security Analyzer Guide"
    };

    function docCategory( required string filename ) {
        var f = lCase( filename );
        if ( f CONTAINS "guardrail" OR f CONTAINS "security" OR f CONTAINS "passkey"
             OR f CONTAINS "argon"  OR f CONTAINS "password" OR f CONTAINS "ethics" )
            return { label: "Security",            cls: "cat-security",  icon: "bi-shield-check",  accent: "##dc2626" };
        if ( f CONTAINS "rag" OR f CONTAINS "vector" OR f CONTAINS "ai" OR f CONTAINS "model" OR f CONTAINS "mcp" )
            return { label: "AI & Machine Learning", cls: "cat-ai",       icon: "bi-robot",          accent: "##7c3aed" };
        if ( f CONTAINS "language" OR f CONTAINS "function" OR f CONTAINS "vscode" OR f CONTAINS "plugin" OR f CONTAINS "jvm" )
            return { label: "Developer Tools",     cls: "cat-devtools",  icon: "bi-code-slash",     accent: "##2563eb" };
        if ( f CONTAINS "bug" OR f CONTAINS "known" OR f CONTAINS "beta" OR f CONTAINS "update" OR f CONTAINS "oem" )
            return { label: "Release Notes",       cls: "cat-release",   icon: "bi-journal-text",   accent: "##d97706" };
        return        { label: "Platform",          cls: "cat-platform",  icon: "bi-layers",         accent: "##059669" };
    }

    authors = [
        { name: "Sarah Chen",     initials: "SC", color: "##6366f1" },
        { name: "Marcus Webb",    initials: "MW", color: "##0891b2" },
        { name: "Priya Nair",     initials: "PN", color: "##059669" },
        { name: "James Kowalski", initials: "JK", color: "##d97706" },
        { name: "Aisha Torres",   initials: "AT", color: "##dc2626" }
    ];
    function docAuthor( required string filename ) {
        return authors[ ( len( filename ) MOD 5 ) + 1 ];
    }

    months = [ "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec" ];
    function docDate( required string filename ) {
        var seed = len( filename ) MOD 12;
        var m    = months[ seed + 1 ];
        var d    = ( ( asc( left( filename, 1 ) ) MOD 20 ) + 5 );
        return m & " " & d & ", 2025";
    }

    function readTime( required string text ) {
        var mins = max( 1, int( listLen( trim( text ), " " ) / 200 ) );
        return mins & " min read";
    }

    function helpfulCount( required string filename ) {
        return ( ( len( filename ) * 7 ) MOD 84 ) + 12;
    }

    if ( isDefined( "form.q" ) AND len( trim( form.q ) ) ) {
        queryText = trim( form.q );
        searched  = true;
        try {
            rawResults = application[ STORE_KEY ].search({
                text     : queryText,
                topK     : SEARCH_TOP_K * 15,
                minScore : SEARCH_MIN_SCORE
            });
            seenDocs = {};
            for ( r in rawResults ) {
                rType = structKeyExists( r.metadata, "type" ) ? lCase( trim( r.metadata.type ) ) : "";
                if ( rType NEQ "pdf" ) continue;
                docKey = structKeyExists( r.metadata, "filename" ) ? r.metadata.filename : r.metadata.source;
                if ( structKeyExists( seenDocs, docKey ) ) continue;
                seenDocs[ docKey ] = true;
                arrayAppend( results, r );
                if ( arrayLen( results ) GTE SEARCH_TOP_K ) break;
            }
        } catch ( any e ) {
            searchError = e.message;
        }
    }

</cfscript>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Knowledge Base — Harbourview Technologies</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <style>
        body { background: #f0f4f8; font-family: system-ui, -apple-system, sans-serif; }

        /* ── Top utility bar ── */
        .util-bar { background: #1a3a5c; color: rgba(255,255,255,.7); font-size: .75rem; padding: .3rem 0; }
        .util-bar a { color: rgba(255,255,255,.7); text-decoration: none; }
        .util-bar a:hover { color: #fff; }

        /* ── Primary nav ── */
        .main-nav { background: #fff; border-bottom: 1px solid #e2e8f0; padding: .6rem 0; }
        .hv-logo-mark { background: #e8a020; color: #fff; font-weight: 800;
                        border-radius: 6px; padding: 2px 9px; font-size: 1.1rem; margin-right: 7px; }
        .hv-logo-name { font-weight: 700; font-size: 1.1rem; color: #1a3a5c; letter-spacing: .02em; }
        .main-nav .nav-link { color: #374151; font-size: .9rem; font-weight: 500; padding: .4rem .85rem; }
        .main-nav .nav-link:hover { color: #1a3a5c; }
        .main-nav .nav-link.active { color: #1a3a5c; border-bottom: 2px solid #e8a020; }
        .btn-signin { background: #1a3a5c; color: #fff; border-radius: 6px;
                      font-size: .85rem; padding: .4rem 1rem; border: none; }
        .btn-signin:hover { background: #24507f; color: #fff; }

        /* ── Support sub-nav ── */
        .sub-nav { background: #f8fafc; border-bottom: 1px solid #e2e8f0; font-size: .84rem; }
        .sub-nav a { color: #64748b; text-decoration: none; padding: .55rem 1rem; display: inline-block; }
        .sub-nav a:hover { color: #1a3a5c; }
        .sub-nav a.active { color: #1a3a5c; font-weight: 600; border-bottom: 2px solid #1a3a5c; }

        /* ── KB hero banner ── */
        .kb-hero { background: linear-gradient(135deg, #1a3a5c 0%, #24507f 100%);
                   color: #fff; padding: 2.5rem 0 3.5rem; }
        .kb-hero h1 { font-size: 1.75rem; font-weight: 700; }
        .kb-hero p  { opacity: .8; font-size: .95rem; }
        .kb-search-box .form-control {
            border-radius: 8px 0 0 8px; border: none;
            padding: .75rem 1.25rem; font-size: 1rem; box-shadow: none;
        }
        .kb-search-box .btn-search {
            border-radius: 0 8px 8px 0; background: #e8a020;
            border-color: #e8a020; color: #fff; padding: .75rem 1.4rem; font-size: 1rem;
        }
        .kb-search-box .btn-search:hover { background: #d4901c; border-color: #d4901c; }

        /* ── Breadcrumb ── */
        .breadcrumb { background: none; padding: .9rem 0 0; margin: 0; font-size: .82rem; }
        .breadcrumb-item + .breadcrumb-item::before { color: #94a3b8; }
        .breadcrumb-item a { color: #2563eb; text-decoration: none; }
        .breadcrumb-item a:hover { text-decoration: underline; }
        .breadcrumb-item.active { color: #64748b; }

        /* ── Layout ── */
        .kb-layout { display: flex; gap: 2rem; align-items: flex-start; padding: 1.5rem 0 3rem; }
        .kb-sidebar { width: 240px; flex-shrink: 0; }
        .kb-main    { flex: 1; min-width: 0; }

        /* ── Sidebar widgets ── */
        .sidebar-widget { background: #fff; border: 1px solid #e2e8f0; border-radius: 10px;
                          padding: 1.1rem; margin-bottom: 1.1rem; }
        .sidebar-widget h6 { font-size: .78rem; font-weight: 700; text-transform: uppercase;
                              letter-spacing: .06em; color: #94a3b8; margin-bottom: .75rem; }
        .sidebar-cat { display: flex; align-items: center; justify-content: space-between;
                       padding: .35rem 0; font-size: .84rem; color: #374151;
                       text-decoration: none; border-radius: 4px; }
        .sidebar-cat:hover { color: #1a3a5c; }
        .sidebar-cat .count { background: #f1f5f9; color: #64748b; font-size: .7rem;
                               font-weight: 600; border-radius: 2rem; padding: .1rem .45rem; }
        .sidebar-cat.active { color: #1a3a5c; font-weight: 600; }
        .popular-item { font-size: .83rem; color: #374151; text-decoration: none;
                        display: block; padding: .4rem 0; border-bottom: 1px solid #f1f5f9; line-height: 1.35; }
        .popular-item:last-child { border-bottom: none; }
        .popular-item:hover { color: #1a3a5c; }
        .popular-item .num { color: #cbd5e1; font-weight: 700; font-size: .8rem; margin-right: .4rem; }

        /* ── Result count bar ── */
        .result-bar { font-size: .82rem; color: #64748b; padding: .5rem 0 1rem;
                      border-bottom: 1px solid #e2e8f0; margin-bottom: 1.5rem;
                      display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: .5rem; }
        .sort-links a { font-size: .8rem; color: #64748b; text-decoration: none; margin-left: .75rem; }
        .sort-links a:hover { color: #1a3a5c; }
        .sort-links a.active { color: #1a3a5c; font-weight: 600; }

        /* ── Cards ── */
        .card-featured {
            background: #fff; border: none; border-radius: 12px;
            box-shadow: 0 2px 12px rgba(0,0,0,.07); overflow: hidden;
            transition: box-shadow .18s, transform .18s;
            border-top: 4px solid var(--accent);
        }
        .card-featured:hover { box-shadow: 0 8px 28px rgba(0,0,0,.1); transform: translateY(-2px); }
        .card-grid {
            background: #fff; border: none; border-radius: 10px;
            box-shadow: 0 1px 6px rgba(0,0,0,.06); overflow: hidden; height: 100%;
            transition: box-shadow .18s, transform .18s;
            border-top: 3px solid var(--accent);
            display: flex; flex-direction: column;
        }
        .card-grid:hover { box-shadow: 0 6px 22px rgba(0,0,0,.09); transform: translateY(-2px); }
        .card-grid .card-body { flex: 1; display: flex; flex-direction: column; }
        .card-grid .card-footer-area { margin-top: auto; }
        .card-title-link { font-weight: 700; color: #1a3a5c; text-decoration: none; line-height: 1.3; }
        .card-title-link:hover { color: #24507f; text-decoration: underline; }
        .card-snippet { font-size: .88rem; color: #4b5563; line-height: 1.75; }
        .card-meta    { font-size: .75rem; color: #94a3b8; }

        /* ── Categories ── */
        .cat-security  { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; }
        .cat-ai        { background: #ede9fe; color: #5b21b6; border: 1px solid #c4b5fd; }
        .cat-devtools  { background: #dbeafe; color: #1e40af; border: 1px solid #93c5fd; }
        .cat-release   { background: #fef3c7; color: #92400e; border: 1px solid #fcd34d; }
        .cat-platform  { background: #d1fae5; color: #065f46; border: 1px solid #6ee7b7; }
        .cat-badge     { font-size: .72rem; font-weight: 600; padding: .25rem .65rem;
                         border-radius: 2rem; display: inline-flex; align-items: center; gap: .3rem; }

        /* ── Author avatar ── */
        .author-avatar { width: 24px; height: 24px; border-radius: 50%;
                         display: inline-flex; align-items: center; justify-content: center;
                         font-size: .6rem; font-weight: 700; color: #fff; flex-shrink: 0; }

        /* ── Action buttons ── */
        .action-strip  { border-top: 1px solid #f1f5f9; padding-top: .65rem; margin-top: .75rem;
                         display: flex; gap: .4rem; flex-wrap: wrap; }
        .action-btn    { background: none; border: 1px solid #e2e8f0; border-radius: 6px;
                         color: #64748b; font-size: .75rem; padding: .25rem .6rem; cursor: pointer;
                         display: inline-flex; align-items: center; gap: .3rem; transition: all .15s; }
        .action-btn:hover  { background: #f8fafc; border-color: #cbd5e1; color: #1a3a5c; }
        .action-btn.active { background: #eff6ff; border-color: #93c5fd; color: #1e40af; }

        /* ── No results ── */
        .no-results { text-align: center; padding: 4rem 1rem; color: #94a3b8; }

        /* ── Footer ── */
        .site-footer { background: #1a3a5c; color: rgba(255,255,255,.75); font-size: .85rem; margin-top: 3rem; }
        .site-footer h6 { color: #fff; font-size: .8rem; font-weight: 700; text-transform: uppercase;
                           letter-spacing: .06em; margin-bottom: 1rem; }
        .site-footer a  { color: rgba(255,255,255,.65); text-decoration: none; display: block;
                           margin-bottom: .45rem; }
        .site-footer a:hover { color: #fff; }
        .footer-bottom { background: rgba(0,0,0,.2); padding: .9rem 0; font-size: .78rem;
                          color: rgba(255,255,255,.5); }
        .social-btn { width: 32px; height: 32px; border-radius: 50%; border: 1px solid rgba(255,255,255,.25);
                      display: inline-flex; align-items: center; justify-content: center;
                      color: rgba(255,255,255,.6); text-decoration: none; margin-right: .4rem; transition: all .15s; }
        .social-btn:hover { background: rgba(255,255,255,.1); color: #fff; }

        @media (max-width: 768px) {
            .kb-layout { flex-direction: column; }
            .kb-sidebar { width: 100%; }
            .util-bar .d-none { display: none !important; }
        }
    </style>
</head>
<body>

<!--- ── Top utility bar ────────────────────────────────────────────────── --->
<div class="util-bar">
    <div class="container d-flex justify-content-between align-items-center">
        <span>📍 North America &nbsp;|&nbsp; <a href="##">Select region</a></span>
        <span class="d-none d-md-inline">
            <a href="##" class="me-3">Contact Sales</a>
            <a href="##" class="me-3">Partners</a>
            <a href="##">Careers</a>
        </span>
    </div>
</div>

<!--- ── Primary navigation ────────────────────────────────────────────── --->
<nav class="main-nav">
    <div class="container d-flex align-items-center justify-content-between">
        <div class="d-flex align-items-center">
            <a href="##" class="text-decoration-none d-flex align-items-center me-4">
                <span class="hv-logo-mark">HV</span>
                <span class="hv-logo-name">Harbourview Technologies</span>
            </a>
            <div class="d-none d-lg-flex align-items-center">
                <a href="##" class="nav-link">Products</a>
                <a href="##" class="nav-link">Solutions</a>
                <a href="##" class="nav-link">Customers</a>
                <a href="##" class="nav-link">Resources</a>
                <a href="##" class="nav-link active">Support</a>
            </div>
        </div>
        <div class="d-flex align-items-center gap-3">
            <a href="##" class="text-secondary text-decoration-none d-none d-md-inline" style="font-size:.9rem;">
                <i class="bi bi-search"></i>
            </a>
            <a href="##" class="text-secondary text-decoration-none d-none d-md-inline" style="font-size:.9rem;">
                <i class="bi bi-bell"></i>
            </a>
            <button class="btn-signin">Sign In</button>
        </div>
    </div>
</nav>

<!--- ── Support sub-navigation ──────────────────────────────────────────── --->
<div class="sub-nav">
    <div class="container">
        <a href="##">Support Overview</a>
        <a href="##" class="active">Knowledge Base</a>
        <a href="##">Community Forums</a>
        <a href="##">Submit a Ticket</a>
        <a href="##">System Status</a>
        <a href="##">Training</a>
    </div>
</div>

<!--- ── KB hero banner ───────────────────────────────────────────────────── --->
<div class="kb-hero">
    <div class="container">
        <cfif NOT searched>
            <h1 class="mb-1">How can we help you?</h1>
            <p class="mb-4">Search our documentation, release notes, and technical guides</p>
        <cfelse>
            <h1 class="mb-1">Knowledge Base</h1>
            <p class="mb-4">Technical documentation &amp; guides</p>
        </cfif>
        <form method="post" class="kb-search-box" style="max-width:620px;">
            <input type="hidden" name="profile" value="<cfoutput>#encodeForHTMLAttribute( ACTIVE_PROFILE )#</cfoutput>">
            <div class="input-group shadow">
                <input type="text" name="q" class="form-control"
                       value="<cfoutput>#encodeForHTML( queryText )#</cfoutput>"
                       placeholder="Search articles, guides, release notes…"
                       <cfif NOT searched>autofocus</cfif>>
                <button class="btn btn-search" type="submit">
                    <i class="bi bi-search me-1"></i> Search
                </button>
            </div>
        </form>
        <cfif NOT searched>
            <div class="mt-3" style="font-size:.82rem; opacity:.7;">
                Popular: <a href="##" class="text-white me-2">Vector search</a>
                         <a href="##" class="text-white me-2">Passkey authentication</a>
                         <a href="##" class="text-white me-2">MCP integration</a>
                         <a href="##" class="text-white">Argon2 hashing</a>
            </div>
        </cfif>
    </div>
</div>

<!--- ── Breadcrumb ────────────────────────────────────────────────────────── --->
<div class="container">
    <nav aria-label="breadcrumb">
        <ol class="breadcrumb">
            <li class="breadcrumb-item"><a href="##">Home</a></li>
            <li class="breadcrumb-item"><a href="##">Support</a></li>
            <li class="breadcrumb-item"><a href="##">Knowledge Base</a></li>
            <cfif searched>
                <li class="breadcrumb-item active">Search results</li>
            </cfif>
        </ol>
    </nav>
</div>

<!--- ── Main content area ────────────────────────────────────────────────── --->
<div class="container">
<div class="kb-layout">

    <!--- ── Sidebar ── --->
    <aside class="kb-sidebar">

        <div class="sidebar-widget">
            <h6>Browse by Category</h6>
            <a href="##" class="sidebar-cat <cfif NOT searched>active</cfif>">
                <span><i class="bi bi-grid-3x3-gap me-2 text-secondary"></i>All Articles</span>
                <span class="count">47</span>
            </a>
            <a href="##" class="sidebar-cat">
                <span><i class="bi bi-robot me-2" style="color:##7c3aed;"></i>AI &amp; Machine Learning</span>
                <span class="count">12</span>
            </a>
            <a href="##" class="sidebar-cat">
                <span><i class="bi bi-shield-check me-2" style="color:##dc2626;"></i>Security</span>
                <span class="count">8</span>
            </a>
            <a href="##" class="sidebar-cat">
                <span><i class="bi bi-code-slash me-2" style="color:##2563eb;"></i>Developer Tools</span>
                <span class="count">14</span>
            </a>
            <a href="##" class="sidebar-cat">
                <span><i class="bi bi-journal-text me-2" style="color:##d97706;"></i>Release Notes</span>
                <span class="count">9</span>
            </a>
            <a href="##" class="sidebar-cat">
                <span><i class="bi bi-layers me-2" style="color:##059669;"></i>Platform</span>
                <span class="count">4</span>
            </a>
        </div>

        <div class="sidebar-widget">
            <h6>Popular Articles</h6>
            <a href="##" class="popular-item"><span class="num">1</span>Getting Started with Vector Search</a>
            <a href="##" class="popular-item"><span class="num">2</span>Setting Up Passkey Authentication</a>
            <a href="##" class="popular-item"><span class="num">3</span>Building Your First RAG Pipeline</a>
            <a href="##" class="popular-item"><span class="num">4</span>Argon2 Password Hashing Guide</a>
            <a href="##" class="popular-item"><span class="num">5</span>MCP Integration Overview</a>
        </div>

        <div class="sidebar-widget">
            <h6>Recently Updated</h6>
            <a href="##" class="popular-item">AI Model Providers — Update 7 <span class="badge bg-success ms-1" style="font-size:.6rem;">New</span></a>
            <a href="##" class="popular-item">VS Code Plugin Enhancements</a>
            <a href="##" class="popular-item">Known Issues — Beta 7</a>
        </div>

        <div class="sidebar-widget" style="background:##eff6ff; border-color:##bfdbfe;">
            <h6 style="color:##1e40af;">Need More Help?</h6>
            <p style="font-size:.8rem; color:##374151; margin-bottom:.75rem;">
                Can't find what you're looking for? Our support team is here.
            </p>
            <a href="##" class="btn btn-sm w-100 text-white" style="background:##1a3a5c;">
                <i class="bi bi-headset me-1"></i> Contact Support
            </a>
        </div>

        <!--- Engineering view link --->
        <div class="text-center mt-2">
            <a href="search.cfm?profile=<cfoutput>#ACTIVE_PROFILE#</cfoutput>"
               class="text-muted" style="font-size:.75rem;">
                <i class="bi bi-tools me-1"></i>Engineering view
            </a>
        </div>

    </aside>

    <!--- ── Main content ── --->
    <main class="kb-main">

    <cfif NOT searched>
    <!--- ── Landing: category tiles + featured articles ── --->
        <h5 class="fw-semibold mb-3" style="color:##1a3a5c;">Featured Topics</h5>
        <div class="row g-3 mb-4">
            <cfset tiles = [
                { label: "AI & Machine Learning", icon: "bi-robot",        color: "##7c3aed", bg: "##ede9fe", desc: "Vector stores, RAG pipelines, LLM integration" },
                { label: "Security",              icon: "bi-shield-check", color: "##dc2626", bg: "##fee2e2", desc: "Passkeys, password hashing, security analyzer" },
                { label: "Developer Tools",       icon: "bi-code-slash",   color: "##2563eb", bg: "##dbeafe", desc: "VS Code plugin, JVM tuning, language updates" },
                { label: "Release Notes",         icon: "bi-journal-text", color: "##d97706", bg: "##fef3c7", desc: "What's new, bug fixes, known issues" }
            ]>
            <cfoutput>
            <cfloop array="#tiles#" item="t">
            <div class="col-6 col-lg-3">
                <a href="##" class="text-decoration-none">
                    <div class="p-3 rounded-3 h-100" style="background:#t.bg#; border: 1px solid rgba(0,0,0,.06); transition: transform .15s;"
                         onmouseover="this.style.transform='translateY(-2px)'" onmouseout="this.style.transform=''">
                        <i class="bi #t.icon#" style="font-size:1.5rem; color:#t.color#;"></i>
                        <div class="fw-600 mt-2 mb-1" style="font-size:.9rem; color:##1e293b; font-weight:600;">#t.label#</div>
                        <div style="font-size:.75rem; color:##64748b;">#t.desc#</div>
                    </div>
                </a>
            </div>
            </cfloop>
            </cfoutput>
        </div>

        <h5 class="fw-semibold mb-3" style="color:##1a3a5c;">Recently Published</h5>
        <div class="d-flex flex-column gap-2">
            <cfset recentArticles = [
                { title: "AI Model Providers in ColdFusion 2025",    cat: "AI & Machine Learning", date: "Jun 10, 2025", icon: "bi-robot",        cls: "cat-ai" },
                { title: "VS Code Plugin — What's New in Update 7",  cat: "Developer Tools",       date: "Jun 8, 2025",  icon: "bi-code-slash",   cls: "cat-devtools" },
                { title: "Known Issues — Update 7 Beta",             cat: "Release Notes",         date: "Jun 5, 2025",  icon: "bi-journal-text", cls: "cat-release" },
                { title: "Passkey & Passwordless Authentication",    cat: "Security",              date: "May 28, 2025", icon: "bi-shield-check", cls: "cat-security" }
            ]>
            <cfoutput>
            <cfloop array="#recentArticles#" item="a">
            <a href="##" class="text-decoration-none">
                <div class="bg-white rounded-3 p-3 d-flex align-items-center gap-3"
                     style="border:1px solid ##e2e8f0; transition: box-shadow .15s;"
                     onmouseover="this.style.boxShadow='0 4px 14px rgba(0,0,0,.07)'" onmouseout="this.style.boxShadow=''">
                    <span class="cat-badge #a.cls#" style="flex-shrink:0;"><i class="bi #a.icon#"></i>#a.cat#</span>
                    <span style="font-size:.9rem; font-weight:600; color:##1a3a5c; flex:1;">#a.title#</span>
                    <span style="font-size:.75rem; color:##94a3b8; white-space:nowrap;"><i class="bi bi-calendar3 me-1"></i>#a.date#</span>
                </div>
            </a>
            </cfloop>
            </cfoutput>
        </div>

    <cfelseif len( searchError )>
        <div class="alert alert-danger"><i class="bi bi-exclamation-triangle me-2"></i><cfoutput>#encodeForHTML( searchError )#</cfoutput></div>

    <cfelseif arrayLen( results ) EQ 0>
        <div class="no-results">
            <i class="bi bi-search" style="font-size:2.8rem;"></i>
            <h5 class="mt-3">No articles found</h5>
            <p class="small">Try rephrasing your question or using different keywords.</p>
        </div>

    <cfelse>
        <cfoutput>
        <div class="result-bar">
            <span>Showing <strong>#arrayLen( results )#</strong> article<cfif arrayLen(results) NEQ 1>s</cfif>
            for &ldquo;<em>#encodeForHTML( queryText )#</em>&rdquo;</span>
            <span class="sort-links">
                Sort by: <a href="##" class="active">Relevance</a>
                          <a href="##">Date</a>
                          <a href="##">Most Helpful</a>
            </span>
        </div>
        </cfoutput>

        <cfset rowIdx = 0>
        <cfloop array="#results#" item="r">
        <cfscript>
            fname   = structKeyExists( r.metadata, "filename" ) ? r.metadata.filename : "";
            title   = structKeyExists( titleMap, fname ) ? titleMap[ fname ]
                    : reReplace( reReplace( reReplace( fname, "(?i)\.pdf$", "" ), "[_\-]", " ", "ALL" ), "\s+", " ", "ALL" );
            cat     = docCategory( fname );
            author  = docAuthor( fname );
            updated = docDate( fname );
            rtime   = readTime( r.text );
            helpful = helpfulCount( fname );
            snippetFull  = left( reReplace( r.text, "\s{2,}", " ", "ALL" ), 420 );
            snippetShort = left( reReplace( r.text, "\s{2,}", " ", "ALL" ), 160 );
            if ( len( r.text ) GT 420 ) snippetFull  &= "…";
            if ( len( r.text ) GT 160 ) snippetShort &= "…";
        </cfscript>

        <cfif rowIdx EQ 0>
        <cfoutput>
        <div class="card-featured p-4 mb-4" style="--accent: #cat.accent#;">
            <div class="d-flex align-items-start gap-4">
                <div class="flex-shrink-0 d-none d-md-flex align-items-center justify-content-center rounded-3"
                     style="width:54px;height:54px;background:#cat.accent#18;">
                    <i class="bi #cat.icon#" style="font-size:1.5rem;color:#cat.accent#;"></i>
                </div>
                <div class="flex-grow-1">
                    <div class="d-flex align-items-center gap-2 mb-2 flex-wrap">
                        <span class="cat-badge #cat.cls#"><i class="bi #cat.icon#"></i>#cat.label#</span>
                        <span class="badge bg-warning text-dark" style="font-size:.68rem;">Top Result</span>
                    </div>
                    <a href="##" class="card-title-link d-block mb-2" style="font-size:1.15rem;">#encodeForHTML( title )#</a>
                    <p class="card-snippet mb-3">#encodeForHTML( snippetFull )#</p>
                    <div class="d-flex align-items-center gap-3 card-meta flex-wrap">
                        <span class="d-flex align-items-center gap-1">
                            <span class="author-avatar" style="background:#author.color#;">#author.initials#</span>
                            #author.name#
                        </span>
                        <span><i class="bi bi-calendar3 me-1"></i>Updated #updated#</span>
                        <span><i class="bi bi-clock me-1"></i>#rtime#</span>
                        <span><i class="bi bi-hand-thumbs-up me-1"></i>#helpful# found this helpful</span>
                    </div>
                    <div class="action-strip">
                        <button class="action-btn" onclick="kbAction(this,'view')"><i class="bi bi-eye"></i> View</button>
                        <button class="action-btn" onclick="kbAction(this,'bookmark')"><i class="bi bi-bookmark"></i> Bookmark</button>
                        <button class="action-btn" onclick="kbAction(this,'share')"><i class="bi bi-share"></i> Share</button>
                        <button class="action-btn" onclick="kbAction(this,'email')"><i class="bi bi-envelope"></i> Email</button>
                    </div>
                </div>
            </div>
        </div>
        </cfoutput>
        <cfset rowIdx++>

        <cfelseif rowIdx EQ 1>
        <div class="row g-4">
        <cfoutput>
        <div class="col-md-6">
            <div class="card-grid" style="--accent: #cat.accent#;">
                <div class="card-body p-4">
                    <div class="mb-2"><span class="cat-badge #cat.cls#"><i class="bi #cat.icon#"></i>#cat.label#</span></div>
                    <a href="##" class="card-title-link d-block mb-2" style="font-size:1rem;">#encodeForHTML( title )#</a>
                    <p class="card-snippet mb-3">#encodeForHTML( snippetShort )#</p>
                    <div class="card-footer-area">
                        <div class="d-flex align-items-center gap-2 card-meta flex-wrap mb-1">
                            <span class="d-flex align-items-center gap-1">
                                <span class="author-avatar" style="background:#author.color#;">#author.initials#</span>
                                #author.name#
                            </span>
                            <span><i class="bi bi-calendar3 me-1"></i>#updated#</span>
                            <span><i class="bi bi-clock me-1"></i>#rtime#</span>
                        </div>
                        <div class="action-strip">
                            <button class="action-btn" onclick="kbAction(this,'view')"><i class="bi bi-eye"></i> View</button>
                            <button class="action-btn" onclick="kbAction(this,'bookmark')"><i class="bi bi-bookmark"></i> Bookmark</button>
                            <button class="action-btn" onclick="kbAction(this,'share')"><i class="bi bi-share"></i> Share</button>
                            <button class="action-btn" onclick="kbAction(this,'email')"><i class="bi bi-envelope"></i> Email</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        </cfoutput>
        <cfset rowIdx++>

        <cfelse>
        <cfoutput>
        <div class="col-md-6">
            <div class="card-grid" style="--accent: #cat.accent#;">
                <div class="card-body p-4">
                    <div class="mb-2"><span class="cat-badge #cat.cls#"><i class="bi #cat.icon#"></i>#cat.label#</span></div>
                    <a href="##" class="card-title-link d-block mb-2" style="font-size:1rem;">#encodeForHTML( title )#</a>
                    <p class="card-snippet mb-3">#encodeForHTML( snippetShort )#</p>
                    <div class="card-footer-area">
                        <div class="d-flex align-items-center gap-2 card-meta flex-wrap mb-1">
                            <span class="d-flex align-items-center gap-1">
                                <span class="author-avatar" style="background:#author.color#;">#author.initials#</span>
                                #author.name#
                            </span>
                            <span><i class="bi bi-calendar3 me-1"></i>#updated#</span>
                            <span><i class="bi bi-clock me-1"></i>#rtime#</span>
                        </div>
                        <div class="action-strip">
                            <button class="action-btn" onclick="kbAction(this,'view')"><i class="bi bi-eye"></i> View</button>
                            <button class="action-btn" onclick="kbAction(this,'bookmark')"><i class="bi bi-bookmark"></i> Bookmark</button>
                            <button class="action-btn" onclick="kbAction(this,'share')"><i class="bi bi-share"></i> Share</button>
                            <button class="action-btn" onclick="kbAction(this,'email')"><i class="bi bi-envelope"></i> Email</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        </cfoutput>
        <cfset rowIdx++>
        </cfif>

        </cfloop>
        <cfif arrayLen( results ) GT 1></div></cfif>

    </cfif>
    </main>

</div>
</div>

<!--- ── Footer ────────────────────────────────────────────────────────────── --->
<footer class="site-footer">
    <div class="container py-5">
        <div class="row g-4">
            <div class="col-md-4">
                <div class="d-flex align-items-center mb-3">
                    <span class="hv-logo-mark" style="background:##e8a020;">HV</span>
                    <span style="color:#fff; font-weight:700; font-size:1rem;">Harbourview Technologies</span>
                </div>
                <p style="font-size:.82rem; color:rgba(255,255,255,.6); line-height:1.65; max-width:260px;">
                    Enterprise-grade software solutions for modern development teams.
                </p>
                <div class="mt-3">
                    <a href="##" class="social-btn"><i class="bi bi-twitter-x"></i></a>
                    <a href="##" class="social-btn"><i class="bi bi-linkedin"></i></a>
                    <a href="##" class="social-btn"><i class="bi bi-github"></i></a>
                    <a href="##" class="social-btn"><i class="bi bi-youtube"></i></a>
                </div>
            </div>
            <div class="col-6 col-md-2">
                <h6>Product</h6>
                <a href="##">Features</a>
                <a href="##">Pricing</a>
                <a href="##">Changelog</a>
                <a href="##">Roadmap</a>
                <a href="##">Status</a>
            </div>
            <div class="col-6 col-md-2">
                <h6>Developers</h6>
                <a href="##">Documentation</a>
                <a href="##">API Reference</a>
                <a href="##">SDKs</a>
                <a href="##">Open Source</a>
                <a href="##">Community</a>
            </div>
            <div class="col-6 col-md-2">
                <h6>Company</h6>
                <a href="##">About Us</a>
                <a href="##">Blog</a>
                <a href="##">Careers</a>
                <a href="##">Press</a>
                <a href="##">Partners</a>
            </div>
            <div class="col-6 col-md-2">
                <h6>Support</h6>
                <a href="##">Knowledge Base</a>
                <a href="##">Community</a>
                <a href="##">Submit Ticket</a>
                <a href="##">System Status</a>
                <a href="##">Training</a>
            </div>
        </div>
    </div>
    <div class="footer-bottom">
        <div class="container d-flex justify-content-between flex-wrap gap-2">
            <span>&copy; 2025 Harbourview Technologies, Inc. All rights reserved.</span>
            <span>
                <a href="##" style="color:rgba(255,255,255,.45); text-decoration:none; margin-right:.75rem;">Privacy Policy</a>
                <a href="##" style="color:rgba(255,255,255,.45); text-decoration:none; margin-right:.75rem;">Terms of Service</a>
                <a href="##" style="color:rgba(255,255,255,.45); text-decoration:none;">Cookie Preferences</a>
            </span>
        </div>
    </div>
</footer>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script>
    const toastMsgs = {
        view:     { icon: '👁',  text: 'Opening document…' },
        bookmark: { icon: '🔖', text: 'Bookmarked! Find it under My Saved Articles.' },
        share:    { icon: '🔗', text: 'Link copied to clipboard.' },
        email:    { icon: '📧', text: 'Article link sent to your email.' }
    };
    function kbAction(btn, action) {
        if (action === 'bookmark') btn.classList.toggle('active');
        const m = toastMsgs[action];
        if (!m) return;
        const el = document.createElement('div');
        el.className = 'toast align-items-center text-bg-dark border-0 show';
        el.setAttribute('role', 'alert');
        el.style.cssText = 'position:fixed;bottom:1.5rem;right:1.5rem;z-index:9999;min-width:280px;';
        el.innerHTML = `<div class="d-flex">
            <div class="toast-body">${m.icon} ${m.text}</div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto"
                    onclick="this.closest('.toast').remove()"></button>
        </div>`;
        document.body.appendChild(el);
        setTimeout(() => el.remove(), 3000);
    }
</script>
</body>
</html>
