# Ticketmaster assessment

## Raw VCL

## Actions

1. **Multiple Origins with Round-Robin Load Balancing**  
We use a director to group two backends, both pointing to the same origin (`https://http-me.glitch.me`). The round-robin director ensures load balancing between these two backends.

2. **Custom Error Handling for 503 Status Code with Stale Content and Auto-Redirect**  
In case the backend returns a `503 Service Unavailable`, Varnish first checks if there is stale content available. If stale content is found, it will be served. Otherwise, a friendly error page is returned with an automatic redirect to `https://www.ticketmaster.co.uk` after 5 seconds.

3. **Serving a Custom JSON Response on `/api/custom-page`**  
When the client requests `/api/custom-page`, Varnish directly serves a custom JSON response (`{"status": "ok"}`) without contacting the backend.

4. **Blocking Requests to `/blockme` Except `/blockme/test`**  
All requests to `/blockme` and its sub-paths are blocked, except for `/blockme/test`. If blocked, the client receives a `403 Forbidden` response with a custom header (`reason: blocked`).

5. **Redirection for `/redirectme`**  
Any request to `/redirectme` is redirected to `https://www.ticketmaster.co.uk` with a `301 Moved Permanently` status.

6. **Query Parameter Rewrite for `lang=us`**  
If the `lang` query parameter equals `us`, it is rewritten to `lang=us_en`. The original value (`us`) is returned in the response header `Lang`.

---

## VCL Subroutine Breakdown

### 1. **vcl_init**  
This subroutine is executed when Varnish starts. It initializes a director (`my_director`) that load balances between two backends (`backend1` and `backend2`).  
_Logs a message indicating that the director is set up._

### 2. **vcl_recv**  
Handles incoming client requests. Key logic includes:
- Serving a custom JSON response on `/api/custom-page`.
- Blocking access to `/blockme` except for `/blockme/test`.
- Redirecting `/redirectme` to `https://www.ticketmaster.co.uk`.
- Rewriting the `lang` query parameter if it equals `us`.  
_Logs each key request handling decision._

### 3. **vcl_synth**  
Manages synthetic (generated) responses. It handles the redirection of `/redirectme`.  
_Logs the redirection event._

### 4. **vcl_deliver**  
This subroutine is executed before sending the response to the client. Here, we set a custom header `Lang` with the value of the original `lang` parameter.  
_Logs that the `Lang` header is being returned._

### 5. **vcl_backend_error**  
Handles errors from the backend. If the backend returns a `503` status, Varnish attempts to serve stale content if available. If no stale content is found, a friendly HTML message is shown to the user with a 5-second automatic redirect to `https://www.ticketmaster.co.uk`.  
_Logs attempts to serve stale content or return a friendly error page with an automatic redirect._

---

## How to Use

1. **Copy the VCL File**  
Copy the VCL code provided in this repository to your Varnish configuration directory (usually `/etc/varnish/default.vcl`).

2. **Configure Your Varnish Instance**  
Make sure your Varnish instance is set up to listen to incoming traffic. You can configure this via your Varnish service or by using the command line.

3. **Load the VCL**  
Use the following commands to load the VCL configuration in Varnish:

```bash
varnishadm vcl.load myconfig /etc/varnish/default.vcl
varnishadm vcl.use myconfig
