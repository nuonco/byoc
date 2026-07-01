# Gateway Fault Debug

Diagnose a route returning **`fault filter abort`** — or other gateway/route failures — for install `{{ .nuon.install.id }}`.

`fault filter abort` is the response Envoy returns when an HTTP **fault-injection filter is configured to abort** a
request, *before* it ever reaches the backend. A common symptom: after login you land on `app.<domain>` and see only the
text `fault filter abort`. This fault config is **not** part of the `byoc-nuon-gcp` app components — it lives in the
gateway/mesh layer (the sandbox's gateway, an Istio policy, or something applied out-of-band) — so this runbook is about
*locating* it so it can be removed there.

Every step is **read-only**. Run the runbook and read each step's output.

## Steps

### 1. Probe public routes

`curl`s each public route (`app`, `api`, `auth`, `runner`) and the internal `admin` route, reporting status code, the
serving proxy (`server:` header), and whether the body is `fault filter abort`.

- **One route aborts** → the fault is scoped to that route.
- **All routes abort** → the fault is mesh-wide / on the shared gateway.
- **DNS/timeout instead of abort** → it's a routing/LB/backend problem, not fault injection — skip to step 3.

### 2. Locate fault injection

Searches the three places an HTTP fault can be configured: an Istio `VirtualService` `http[].fault` stanza, an
`EnvoyFilter` that inserts a fault filter, or Gateway API `HTTPRoute` filters. It prints any matches with their
namespace/name and the fault stanza. The fix is to remove the `fault` block (or set its `percentage` to 0) on whatever
it finds — applied in the gateway/sandbox layer, not in a byoc-nuon-gcp component.

### 3. Route + backend health

Lists the `Gateway`, the `HTTPRoute`s (hostnames, parent gateway, backends), and the `dashboard-ui` (the `app` route) and
`ctl-api` (api/auth/runner/admin) backend pods. Use this when a route **times out or 5xxs** rather than returning
`fault filter abort` — a missing/incorrect backend or zero healthy pods explains those, whereas a healthy backend that
still aborts points back to fault injection (step 2).

## Reading the output

| Symptom | Likely cause | Next |
| --- | --- | --- |
| `fault filter abort` on one route | fault scoped to that route | step 2 → remove the fault |
| `fault filter abort` on all routes | mesh-wide / shared-gateway fault | step 2 → remove the fault |
| `curl exit 6` (DNS) / `exit 28` (timeout) | route not built or backend down | step 3 → check route + pods |
| 5xx with a healthy backend | backend erroring | step 3 → then check pod logs |

> [!NOTE]
> The fixes for fault injection and gateway config live in the install's sandbox / gateway layer, not in the
> byoc-nuon-gcp app components. This runbook only locates the cause.
