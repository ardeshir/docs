# Building a Log Analytics Module for Julia 

To set up an Azure App Service running a Julia program in a container to log directly to Azure Log Analytics using the API, you'll need to follow these steps:

1. **Obtain Workspace Information:**
   Get your Log Analytics Workspace ID and Primary Key (shared key).

2. **Set Up Julia for HTTP Requests:**
   You will need a package like `HTTP.jl` to make HTTP requests from Julia.

3. **Format Logs in the Correct Format:**
   Azure Log Analytics expects logs in a specific JSON format.

4. **Sign API Requests:**
   You need to create a signature for each API request to authenticate it.

5. **Send Logs to Log Analytics:**
   Make an HTTP POST request to the Log Analytics API endpoint with the logs and the signature.

Here's an example in Julia of how you might achieve this:

### Step-by-Step Guide

**Step 1: Install Required Julia Packages**
You need the `HTTP.jl` and `JSON.jl` packages. Install them using the following commands if you haven't already:
```julia
using Pkg
Pkg.add("HTTP")
Pkg.add("JSON")
```

**Step 2: Define the Logging Function**
Here is an example function to send logs to Azure Log Analytics:

```julia
using HTTP
using JSON
using Base64
using SHA

function get_signature(workspace_id, shared_key, date, content_length, method, content_type, resource)
    x_headers = "x-ms-date:$date"
    string_to_hash = "$method\n$shared_key\n$content_length\n$content_type\n$x_headers\n$resource"
    decoded_key = Base64.decode(shared_key)
    bytes_to_hash = hmac_sha256(decoded_key, string_to_hash)
    encoded_hash = Base64.encode(bytes_to_hash)
    authorization = "SharedKey $workspace_id:$encoded_hash"
    return authorization
end

function send_log_to_log_analytics(workspace_id, shared_key, log_data, log_type)
    customer_id = workspace_id
    shared_key = shared_key
    body = JSON.json(log_data)
    resource = "/api/logs"
    method = "POST"
    content_type = "application/json"
    content_length = string(length(body))
    rfc1123date = Dates.format(now(), Dates.RFC1123Format())

    signature = get_signature(workspace_id, shared_key, rfc1123date, content_length, method, content_type, resource)
        
    url = "https://$customer_id.ods.opinsights.azure.com$resource?api-version=2016-04-01"

    headers = Dict(
        "Content-Type" => content_type,
        "Authorization" => signature,
        "Log-Type" => log_type,
        "x-ms-date" => rfc1123date,
        "time-generated-field" => "TimeGenerated"
    )

    response = HTTP.post(url, headers, body)
    return response
end

```

**Step 3: Usage Example**
Call the `send_log_to_log_analytics` function with your workspace ID, primary key, log data, and log type.

```julia
workspace_id = "098bf664-2fc6-4205-be31-90280410c423"
shared_key = "your_primary_key_here"
log_data = [{"TimeGenerated" => Dates.format(Dates.now(), Dates.DateTimeFormat("yyyy-MM-ddTHH:MM:SSZ")), "Message" => "Test log from Julia!"}]
log_type = "YourCustomLogType"  # Define your custom log type

response = send_log_to_log_analytics(workspace_id, shared_key, log_data, log_type)

println("Response Status: ", response.status)
println("Response Body: ", String(response.body))
```

### Important Notes:
- Replace `your_primary_key_here` with your actual Log Analytics workspace primary key.
- The custom log type (e.g., `YourCustomLogType`) should follow the naming conventions: only alphanumeric characters and underscore ('_').

The error you're encountering, `InvalidAuthorization` with the message `An invalid date format used in the x-ms-date header` usually points to an issue with the date format being used in the `x-ms-date` header during the authorization process of your request to Azure Log Analytics.

### RFC1123 Date Format Correction

To ensure the date is formatted correctly to RFC1123 standard, you should use the correct formatting string. In Julia, you should use:

```julia
rfc1123date = Dates.format(now(UTC), "e, d u y HH:MM:SS") * " GMT"
```

This format has fields as per the correct specification:

- `e` for the day-of-week short name.
- `d` for the day-of-month as a zero-padded decimal number.
- `u` is not necessary for this since there's no specific directive for year-fullyear, just `y`.
- `y` for the year with century as a decimal number.
- `HH` for hour (00-23).
- `MM` for minute (00-59).
- `SS` for second.

```julia v2
using HTTP  
using JSON  
using Dates  
using Base64  
using SHA  
  
#export send_log  
  
function build_authorization_header(workspace_id, shared_key, date, content_length)  
    method = "POST"  
    content_type = "application/json"  
    resource = "/api/logs"  
  
    x_headers = "x-ms-date:" * date  
    string_to_hash = method * "\n" * string(content_length) * "\n" * content_type * "\n" * x_headers * "\n" * resource  
    decoded_key = base64decode(shared_key)  
    encoded_hash = base64encode(hmac_sha256(decoded_key, string_to_hash))  
    authorization = "SharedKey $workspace_id:$encoded_hash"  
    return authorization  
end  
  
function send_log(workspace_id, shared_key, log_type, log_message)  
    url = "https://$workspace_id.ods.opinsights.azure.com/api/logs?api-version=2016-04-01"  
    timestamp = Dates.format(Dates.now(UTC), Dates.RFC1123Format) * " GMT"  
    payload = Dict(  
        "time" => Dates.format(Dates.now(UTC), "yyyy-mm-ddTHH:MM:SS.sssZ"),  
        "logMessage" => log_message  
    )  
    json_payload = JSON.json(payload)  
    content_length = length(json_payload)  
  
    headers = Dict(  
        "Content-Type" => "application/json",  
        "Log-Type" => log_type,  
        "x-ms-date" => timestamp,  
        "Authorization" => build_authorization_header(workspace_id, shared_key, timestamp, content_length)  
    )  
  
    try  
        response = HTTP.post(url, headers, json_payload)  
        if response.status == 200  
            println("Log sent successfully.")  
        else  
            println("Failed to send log. Status: ", response.status)  
            println("Response body: ", String(response.body))  
        end  
    catch e  
        println("Exception occurred: ", e)  
    end  
end 
# Example usage:  
# send_log("098bf664-2fc6-4205-be31-90280410c423", "pZBEa2xRsTJM+EjKhenKIa234E6Z2JG5zzG5T+w1ciYbSmw8RLubIV7FH3PuTYONYiSabH1TTbGiLB+vfFKbUw==", "JuliaTestLogType", "This is a test log message.")  
 

function main()
    # Replace with your actual workspace ID and key
    workspace_id = "098bf664-2fc6-4205-be31-90280410c423"
    shared_key = "pZBEa2xRsTJM+EjKhenKIa234E6Z2JG5zzG5T+w1ciYbSmw8RLubIV7FH3PuTYONYiSabH1TTbGiLB+vfFKbUw=="
    log_type = "JuliaTestLogType"
    
    # Example log data
    log_data = Dict(
        "TimeGenerated" => Dates.format(now(UTC), "yyyy-MM-ddTHH:MM:ss.fffZ"),
        "Computer" => "Ardeshir Testing LogAnalytics",
        "Level" => "Information",
        "Message" => "This is a JLogs test log message from Julia"
    )
    
    send_log(workspace_id, shared_key, log_type, log_data)  
 
    #println("Log response status: ", response.status)
    #println("Log response body: ", String(response.body))
end

main()
```
### References:
For more details on posting data to the Azure Log Analytics HTTP Data Collector API, you can refer to the official documentation:
[Azure Monitor HTTP Data Collector API](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-collector-api)
