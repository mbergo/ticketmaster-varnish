vcl 4.1;

# Define two backends pointing to the same origin
backend backend1 {
    .host = "http-me.glitch.me";
    .port = "443";
    .ssl = true;
}

backend backend2 {
    .host = "http-me.glitch.me";
    .port = "443";
    .ssl = true;
}

# Use a round-robin director to load-balance between the two backends
director my_director round-robin {
    { .backend = backend1; }
    { .backend = backend2; }
}

# Initialization subroutine (executes on startup)
sub vcl_init {
    # Initialize the director
    new dir = my_director;
    std.log("VCL Init: Director setup with round-robin load balancing.");
}

# Main request-handling logic
sub vcl_recv {
    # Log incoming request URLs
    std.log("Received request: " + req.url);

    # Serve custom JSON response on /api/custom-page
    if (req.url == "/api/custom-page") {
        std.log("Serving synthetic JSON response for /api/custom-page.");
        return (synth(200, "{\"status\": \"ok\"}"));
    }

    # Block all requests to /blockme, except /blockme/test, with 403 Forbidden
    if (req.url == "/blockme" || req.url ~ "^/blockme/") {
        if (req.url != "/blockme/test") {
            std.log("Blocking request to " + req.url + " with 403.");
            set req.http.reason = "blocked";
            return (synth(403, "Forbidden"));
        }
    }

    # Redirect /redirectme to https://www.ticketmaster.co.uk
    if (req.url == "/redirectme") {
        std.log("Redirecting /redirectme to https://www.ticketmaster.co.uk.");
        return (synth(301, ""));
    }

    # Rewrite the lang=us parameter to lang=us_en and store the original value in a custom header
    if (req.url ~ "lang=us") {
        std.log("Rewriting lang=us to lang=us_en.");
        set req.url = regsub(req.url, "lang=us", "lang=us_en");
        set req.http.X-Lang = "us";
    }
}

# Custom handling for synthetic (generated) responses
sub vcl_synth {
    # Handle 301 redirect for /redirectme
    if (resp.status == 301) {
        set resp.http.Location = "https://www.ticketmaster.co.uk";
        std.log("301 Redirect applied for /redirectme.");
        return (deliver);
    }
}

# Deliver response to client (modify headers before delivery)
sub vcl_deliver {
    # If the lang parameter was rewritten, return the original value in the response header
    if (req.http.X-Lang) {
        std.log("Returning original lang parameter in response header.");
        set resp.http.Lang = req.http.X-Lang;
    }
}

# Custom error handling for backend errors (503) with friendly message and redirect
sub vcl_backend_error {
    if (beresp.status == 503) {
        std.log("Backend returned 503, checking for stale content.");

        # Serve stale content if available
        if (beresp.ttl > 0s) {
            std.log("Serving stale content due to backend 503.");
            return (deliver);
        }

        # No stale content available, return friendly page with auto-redirect to ticketmaster.co.uk
        set beresp.status = 503;
        set beresp.http.Content-Type = "text/html";
        synthetic({"<html><head><meta http-equiv='refresh' content='5;url=https://www.ticketmaster.co.uk'/><title>Service Unavailable</title></head><body><h1>Service Temporarily Unavailable</h1><p>Our service is currently down. You will be redirected to Ticketmaster in 5 seconds.</p></body></html>"});
        std.log("No stale content available, returning friendly page with redirect.");
        return (deliver);
    }
}