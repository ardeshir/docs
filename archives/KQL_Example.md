### KQL Explained 

What the Original KQL Query is Trying to Accomplish:
-----------------------------------------------------------

The query, in its current uncommented state, aims to:

1.  **Define a GUID Regex:**
    *   `let rx = '[({]?[a-fA-F0-9]{8}[-]?([a-fA-F0-9]{4}[-]?){3}[a-fA-F0-9]{12}[})]?';` defines a regular expression to match GUIDs (Globally Unique Identifiers), potentially enclosed in curly braces or parentheses.
    *   `let guidPlaceholder ="xxxxxxxx-xxxx";` defines a placeholder string. *(Note: This placeholder is shorter than a full GUID, which might be an oversight. A full placeholder like `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` would be more accurate if you intend to replace full GUIDs)*

2.  **Filter and Parse Logs:**
    *   `AzureDiagnostics`: Starts by querying the `AzureDiagnostics` table, which contains logs from various Azure services.
    *   `| extend ParsedUrl = parse_url(replace(rx, guidPlaceholder, tostring(requestUri_s)))`:
        *   It takes the `requestUri_s` (the requested URI).
        *   It replaces any GUIDs found in the URI with the `guidPlaceholder`. This is often done to group similar requests where only a GUID differs (e.g., `/api/users/{guid}/profile`).
        *   Then, it parses this modified URI into components (Host, Path, Query, etc.) and stores it in `ParsedUrl`.
    *   `|where ParsedUrl.Host contains 'www.cargillnutritioncloud.com'`: Filters logs to only include requests targeting this specific host.
    *   `|where httpMethod_s == "POST"`: Filters for HTTP POST requests only. This is a significant filter and will exclude GET, PUT, DELETE, etc., based attacks.

3.  **Extract URL Path Components:**
    *   `| extend UrlParts = split( replace(rx, guidPlaceholder, tostring(ParsedUrl.Path)) ,'/')`:
        *   Takes the *path* component from the (GUID-replaced) `ParsedUrl`.
        *   Replaces GUIDs in the path *again* (this might be redundant if `requestUri_s` already had them replaced, but ensures it if GUIDs were only in the path and not hostname/query).
        *   Splits the path by `/` into an array of strings called `UrlParts`. For a path like `/api/tenant1/data`, `UrlParts` would be `["", "api", "tenant1", "data"]`.
    *   `| extend UrlDetailsArray =array_slice(UrlParts, 3,99)`: Creates a new array `UrlDetailsArray` by taking a slice of `UrlParts` starting from the 4th element (index 3) up to 99 more elements. This suggests an expected URL structure where the "details" start after the third segment.
    *   `|extend tenant = tostring(UrlParts[2])`: Extracts the 3rd element (index 2) from `UrlParts` and calls it `tenant`. This implies a URL structure like `/segment1/segment2/tenant_name/...`. Given the slice above starts at index 3, `UrlParts[2]` is the segment *before* `UrlDetailsArray` begins.

4.  **Filter by Log Source and Exclude Specific Tenants:**
    *   `| where ResourceProvider == "MICROSOFT.CDN" and Category == "FrontDoorAccessLog"`: Ensures it's processing only Azure Front Door access logs.
    *   `|where tenant != "api" and tenant != "notifications"`: Excludes requests where the extracted `tenant` is "api" or "notifications".
    *   `|where tenant != "cargill"`: Excludes requests where the extracted `tenant` is "cargill".

5.  **Commented Out Sections (Potential Original Goals):**
    *   The commented-out `summarize` lines suggest the original intent was to count requests grouped by various dimensions like `Host`, `tenant`, `detailPath` (reconstructed from `UrlDetailsArray`), and `TimeGenerated` (binned into 10-minute intervals).
    *   Commented-out `project` and `order by` lines indicate a desire to select specific columns and sort the results.
    *   `summarize count() by clientIp_s` was commented out but is **key** for bad actor detection.

**In its current, uncommented state, the query returns raw log entries (with the extended `ParsedUrl`, `UrlParts`, `UrlDetailsArray`, `tenant` columns) for POST requests to `www.cargillnutritioncloud.com`, excluding certain tenants, and where GUIDs in URIs have been replaced.**

Making it More Useful to See Bad Actors:
------------------------------------------

To detect bad actors and patterns, we need to look for anomalies and known malicious indicators. Here's how we can evolve your query:

**Key Bad Actor Indicators:**

1.  **High Request Volume from a Single IP:** Bots, scanners, DDoS.
2.  **High Error Rates (4xx/5xx) from a Single IP:** Scanning for vulnerabilities, forceful browsing.
3.  **Suspicious User-Agents:** Known malicious tools, or blank/uncommon user agents.
4.  **Requests to Non-Existent Paths (404s):** Directory/file enumeration.
5.  **Probing for Common Vulnerabilities:** SQL injection patterns, XSS, path traversal in URIs.
6.  **Traffic from Unexpected Geo-locations.**
7.  **WAF (Web Application Firewall) Triggers:** If you have Azure WAF enabled on Front Door, its logs are invaluable.

**Improved KQL Queries for Bad Actor Detection:**

First, let's refine the GUID placeholder and make the time range explicit and configurable:

```kql
let TimeRange = 1h; // Define your analysis window (e.g., 1h, 24h, 7d)
let TargetHost = "www.cargillnutritioncloud.com";
let rxGuid = '[({]?[a-fA-F0-9]{8}[-]?([a-fA-F0-9]{4}[-]?){3}[a-fA-F0-9]{12}[})]?';
let guidPlaceholder ="guid-placeholder"; // A more descriptive placeholder

// Base query for Front Door Access Logs
let BaseLogs = AzureDiagnostics
    | where TimeGenerated > ago(TimeRange)
    | where ResourceProvider == "MICROSOFT.CDN" and Category == "FrontDoorAccessLog"
    | extend ParsedUrl = parse_url(requestUri_s)
    | where isnotempty(ParsedUrl.Host) and ParsedUrl.Host has TargetHost // Ensure Host is not empty and matches
    | extend NormalizedPath = replace(rxGuid, guidPlaceholder, tostring(ParsedUrl.Path));
```

Now, let's build specific queries on top of this `BaseLogs`.

**Query 1: Top Talkers (High Request Volume by IP)**

```kql
// Query 1: Top Talkers by IP
BaseLogs
| summarize
    RequestCount = count(),
    DistinctPathsRequested = dcount(NormalizedPath),
    UserAgents = make_set(userAgent_s, 5), // Sample of User Agents
    HttpStatusCodes = make_set(httpStatusCode_s, 10) // Sample of Status Codes
    by clientIp_s, ClientCountry = geo_info_from_ip_address(clientIp_s).country
| where RequestCount > 100 // Adjust threshold based on your normal traffic
| order by RequestCount desc
| project clientIp_s, ClientCountry, RequestCount, DistinctPathsRequested, UserAgents, HttpStatusCodes
```
*   **Purpose:** Identifies IPs sending a large number of requests. High `DistinctPathsRequested` might indicate scanning.
*   **Actionable:** Investigate these IPs. Are they legitimate bots (e.g., search engines) or suspicious?

**Query 2: IPs Generating High Client/Server Errors (4xx/5xx)**

```kql
// Query 2: IPs Generating High Errors
BaseLogs
| where httpStatusCode_s >= 400 // 400-499 (Client Errors), 500-599 (Server Errors)
| summarize
    ErrorCount = count(),
    DistinctErrorCodes = make_set(httpStatusCode_s),
    SampleErrorPaths = make_set(NormalizedPath, 5), // See what paths are erroring
    UserAgents = make_set(userAgent_s, 3)
    by clientIp_s, ClientCountry = geo_info_from_ip_address(clientIp_s).country
| where ErrorCount > 20 // Adjust threshold
| order by ErrorCount desc
| project clientIp_s, ClientCountry, ErrorCount, DistinctErrorCodes, SampleErrorPaths, UserAgents
```
*   **Purpose:** Finds IPs that are frequently hitting pages that don't exist (404), causing forbidden errors (403), or server errors (5xx). This is a strong indicator of probing or attack attempts.
*   **Actionable:** These IPs are highly suspect.

**Query 3: Suspicious User Agents**

```kql
// Query 3: Suspicious User Agents
BaseLogs
| where userAgent_s matches regex "(?i)(sqlmap|nmap|nikto|curl|wget|python-requests|hydra|masscan|dirb|gobuster)" // Add known bad UAs or tools not expected
    or isempty(userAgent_s) // Blank User Agents can be suspicious
| summarize
    RequestCount = count(),
    DistinctPaths = dcount(NormalizedPath),
    SamplePaths = make_set(NormalizedPath, 5),
    HttpStatusCodes = make_set(httpStatusCode_s)
    by clientIp_s, userAgent_s, ClientCountry = geo_info_from_ip_address(clientIp_s).country
| order by RequestCount desc
| project clientIp_s, ClientCountry, userAgent_s, RequestCount, DistinctPaths, SamplePaths, HttpStatusCodes
```
*   **Purpose:** Identifies requests from tools commonly used for scanning and attacks, or from clients with no user agent.
*   **Actionable:** IPs using these UAs without legitimate reason are candidates for blocking. `curl`, `wget`, `python-requests` can be legitimate, so correlate with other findings.

**Query 4: Scanning for Common Malicious URL Patterns**

```kql
// Query 4: Malicious URL Patterns (SQLi, XSS, Path Traversal, LFI/RFI)
let MaliciousPatterns = pack_array(
    "(?i)(\\%27|\\'|--|\\%23|#)", // Basic SQLi
    "(?i)(<script>|%3Cscript%3E)", // Basic XSS
    "(?i)(\\.\\./|\\.\\.\\\\)", // Path Traversal
    "(?i)(/etc/passwd|win.ini|boot.ini)", // LFI
    "(?i)(cmd.exe|/bin/bash)", // Command Injection
    "(?i)(SELECT.*FROM|UNION.*SELECT|INSERT.*INTO|DROP.*TABLE|UPDATE.*SET)" // More SQLi
);
BaseLogs
| extend MatchedPattern = case(
    requestUri_s matches regex MaliciousPatterns[0], "SQLi-Like",
    requestUri_s matches regex MaliciousPatterns[1], "XSS-Like",
    requestUri_s matches regex MaliciousPatterns[2], "PathTraversal-Like",
    requestUri_s matches regex MaliciousPatterns[3], "LFI-Like",
    requestUri_s matches regex MaliciousPatterns[4], "CommandInjection-Like",
    requestUri_s matches regex MaliciousPatterns[5], "AdvancedSQLi-Like",
    "Other")
| where MatchedPattern != "Other"
| summarize
    AttemptCount = count(),
    DistinctURIs = dcount(requestUri_s),
    SampleURIs = make_set(requestUri_s, 5),
    UserAgents = make_set(userAgent_s, 3)
    by clientIp_s, MatchedPattern, ClientCountry = geo_info_from_ip_address(clientIp_s).country
| order by AttemptCount desc
| project clientIp_s, ClientCountry, MatchedPattern, AttemptCount, DistinctURIs, SampleURIs, UserAgents
```
*   **Purpose:** Searches for common attack strings in the `requestUri_s`. This is a very basic check; a WAF is much better at this.
*   **Actionable:** IPs triggering these patterns are highly suspicious.

**Query 5: Analyzing WAF Logs (MOST IMPORTANT for security)**
If you have Azure WAF enabled on your Front Door, its logs are critical.

```kql
// Query 5: Azure WAF Triggered Rules
let TimeRangeWAF = 1h;
AzureDiagnostics
| where TimeGenerated > ago(TimeRangeWAF)
| where Category == "FrontDoorWebApplicationFirewallLog"
| where policyMode_s == "Prevention" or action_s == "Block" // Focus on blocked/prevented actions
// Use 'Detection' mode or 'Log' action if you're just monitoring
| summarize
    BlockedRequests = count(),
    DistinctRulesTriggered = dcount(ruleName_s),
    RuleDetails = make_set(pack("Rule", ruleName_s, "Action", action_s, "Details", details_message_s, "Data", details_data_s), 5), // See which rules and data triggered them
    MatchingUserAgents = make_set(userAgent_s, 3)
    by clientIp_s, Hostname = host_s, Policy = policy_s, ClientCountry = geo_info_from_ip_address(clientIp_s).country
| order by BlockedRequests desc
| project clientIp_s, ClientCountry, Hostname, Policy, BlockedRequests, DistinctRulesTriggered, RuleDetails, MatchingUserAgents
```
*   **Purpose:** Shows which IPs are being blocked by your WAF and for what reasons. This is direct evidence of malicious attempts.
*   **Actionable:** Confirms WAF effectiveness. If IPs are repeatedly blocked, they are confirmed bad actors. You might add them to a more permanent blocklist or use WAF custom rules for stricter geo-blocking if a pattern emerges.

How to Block and Protect Your Site:
----------------------------------

1.  **Azure Web Application Firewall (WAF) on Front Door:**
    *   **Enable Managed Rule Sets:** OWASP Core Rule Set (CRS) provides protection against common web attacks (SQLi, XSS, LFI, RFI, etc.). Keep it in `Prevention` mode.
    *   **Custom Rules:**
        *   **IP Restriction:** Create rules to `Block` traffic from IPs identified as malicious by your KQL queries.
        *   **Geo-Blocking:** If your site only serves specific regions, block traffic from other countries.
        *   **Rate Limiting:** Configure rules to block IPs that exceed a certain request threshold in a short time period (e.g., 100 requests in 1 minute).
        *   **User-Agent/Header Blocking:** Block requests with specific malicious user agents or header patterns.
        *   **URI Path/Query String Blocking:** Block requests to known vulnerable paths or containing malicious query strings (though managed rules often cover this).
    *   **Regularly Review WAF Logs:** Use Query 5 above to understand what WAF is blocking and tune its rules. Start in `Detection` mode to avoid blocking legitimate traffic, then switch to `Prevention`.

2.  **Azure Front Door Rules Engine (Standard/Premium):**
    *   While not primarily for security blocking (WAF is better), you can use it for:
        *   Redirecting suspicious traffic.
        *   Adding/modifying headers for backend processing.

3.  **Origin Server Hardening:**
    *   Ensure your backend application servers are patched and securely configured.
    *   Implement application-level security measures (input validation, parameterized queries, output encoding).
    *   Restrict direct access to origin servers; all traffic should go through Front Door. Use `X-Azure-FDID` header validation at origin or Private Link.

4.  **Monitoring and Alerting:**
    *   Set up Azure Monitor Alerts based on your KQL queries. For example, alert if:
        *   An IP generates > N errors in M minutes.
        *   WAF blocks > X requests from a single IP.
        *   A high-severity WAF rule is triggered.
    *   Use Azure Sentinel for more advanced threat detection and SIEM capabilities, which can ingest Front Door and WAF logs.

5.  **Iterative Process:**
    *   Bad actors constantly change tactics. Regularly review your logs and KQL queries.
    *   Adjust thresholds in your queries based on your site's normal traffic patterns.
    *   Update WAF rules as new threats emerge or as you identify new malicious patterns.

**Example of using one of the KQL queries to make a WAF custom rule:**

If Query 2 shows `clientIp_s = '1.2.3.4'` is generating hundreds of 404 errors, you can create a WAF custom rule:

*   **Name:** BlockSuspiciousScannerIP
*   **Priority:** A low number (e.g., 10) to execute early.
*   **Rule Type:** Match
*   **Match Condition 1:**
    *   **Match Variable:** `RemoteAddr` (Client IP)
    *   **Operator:** `IPMatch`
    *   **Match Value:** `1.2.3.4/32` (or a list of IPs)
*   **Action:** `Block`

**Resources:**

*   **Azure Front Door WAF Overview:** [https://docs.microsoft.com/en-us/azure/web-application-firewall/afds/afds-overview](https://docs.microsoft.com/en-us/azure/web-application-firewall/afds/afds-overview)
*   **KQL `geo_info_from_ip_address`:** [https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/geo-info-from-ip-address-function](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/geo-info-from-ip-address-function)
*   **KQL `parse_url`:** [https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/parseurlfunction](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/parseurlfunction)
*   **Azure WAF Custom Rules:** [https://docs.microsoft.com/en-us/azure/web-application-firewall/afds/custom-rules](https://docs.microsoft.com/en-us/azure/web-application-firewall/afds/custom-rules)
*   **Azure WAF Rate Limiting:** [https://docs.microsoft.com/en-us/azure/web-application-firewall/afds/waf-front-door-rate-limit](https://docs.microsoft.com/en-us/azure/web-application-firewall/afds/waf-front-door-rate-limit)
*   **OWASP Top 10:** [https://owasp.org/www-project-top-ten/](https://owasp.org/www-project-top-ten/) (Understand the types of attacks you're trying to prevent)

By using these enhanced KQL queries and leveraging Azure WAF, you can significantly improve your ability to detect and block bad actors targeting your site. Remember to adjust thresholds and patterns based on your specific application's behavior and observed threats.
