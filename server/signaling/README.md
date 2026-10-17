# GrimTable signaling service

Node.js 22+ with pinned `ws` 8.22.0; no database or simulation. Versioned WebSocket
protocol, two-person expiring rooms, SDP/ICE forwarding, short-lived coturn REST
credentials, payload limits, schema validation and rate limits.

Service version 1.1.0 adds private match capabilities for authenticated ICE
credential refresh/signaling reattachment, fixed match expiry, health version and
optional aggregate metrics. This is not gameplay reconnect. See
[RECONNECT.md](../../docs/RECONNECT.md) for the native live-renewal limitation.

```sh
npm ci --ignore-scripts
npm test
npm start
```

Default bind: `127.0.0.1:8080`. Health: `GET /health`. For local tests without TURN,
no environment variables are needed. Production WSS is terminated by a trusted
reverse proxy; never expose cleartext WS as a production player endpoint.

See [network architecture/protocol](../../docs/NETWORKING.md) and
[self-hosting, environment, TLS and firewall](../../docs/SELF_HOSTING.md).
`Dockerfile` builds the service with `npm ci` and runs as a non-root user.
