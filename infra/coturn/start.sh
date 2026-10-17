#!/bin/sh
set -eu
fail() { echo "TURN configuration error: $1" >&2; exit 1; }
ipv4() (
  case "$1" in ''|.*|*.|*..*|*[!0-9.]*) exit 1;; esac
  IFS=.; set -- $1
  test "$#" -eq 4 || exit 1
  for octet do
    case "$octet" in ''|*[!0-9]*) exit 1;; esac
    test "$octet" -le 255 || exit 1
  done
)
: "${TURN_SHARED_SECRET:?Set TURN_SHARED_SECRET}"
: "${TURN_EXTERNAL_IP:?Set TURN_EXTERNAL_IP}"
: "${TURN_REALM:?Set TURN_REALM}"
test "${#TURN_SHARED_SECRET}" -ge 32 || fail 'secret must contain at least 32 random characters'
case "$TURN_SHARED_SECRET" in *[!A-Za-z0-9_+=/.-]*) fail 'use a hex or base64 secret without whitespace';; esac
case "$TURN_REALM" in ''|*[!A-Za-z0-9.-]*) fail 'realm must be a DNS-style name';; esac
case "$TURN_EXTERNAL_IP" in */*/*) fail 'external IP must be IPv4 or public/private mapping';; esac
public_ip=${TURN_EXTERNAL_IP%%/*}
mapped_ip=${TURN_EXTERNAL_IP#*/}
ipv4 "$public_ip" && ipv4 "$mapped_ip" || fail 'invalid public/private IPv4 address'
TURN_LISTENING_IP=${TURN_LISTENING_IP:-0.0.0.0}
TURN_RELAY_IP=${TURN_RELAY_IP:-$mapped_ip}
TURN_MIN_PORT=${TURN_MIN_PORT:-49160}
TURN_MAX_PORT=${TURN_MAX_PORT:-49260}
TURN_TLS=${TURN_TLS:-false}
ipv4 "$TURN_LISTENING_IP" && ipv4 "$TURN_RELAY_IP" || fail 'invalid listening/relay IPv4 address'
test "$TURN_RELAY_IP" != 0.0.0.0 || fail 'relay IP must be an actual local interface address'
for port in "$TURN_MIN_PORT" "$TURN_MAX_PORT"; do
  case "$port" in ''|*[!0-9]*) fail 'relay ports must be integers';; esac
  test "$port" -ge 1024 && test "$port" -le 65535 || fail 'relay port outside 1024-65535'
done
test "$TURN_MIN_PORT" -le "$TURN_MAX_PORT" || fail 'relay port range is reversed'
case "$TURN_TLS" in true|false) ;; *) fail 'TURN_TLS must be true or false';; esac
umask 077
# The secret stays in a private tmpfs file, outside the process argument list.
cp /etc/coturn/turnserver.conf /tmp/turnserver.conf
printf '\nstatic-auth-secret=%s\nexternal-ip=%s\nrealm=%s\nlistening-ip=%s\nrelay-ip=%s\nmin-port=%s\nmax-port=%s\n' "$TURN_SHARED_SECRET" "$TURN_EXTERNAL_IP" "$TURN_REALM" "$TURN_LISTENING_IP" "$TURN_RELAY_IP" "$TURN_MIN_PORT" "$TURN_MAX_PORT" >> /tmp/turnserver.conf
if test "$TURN_TLS" = true; then
  test -r /run/turn-certs/fullchain.pem && test -r /run/turn-certs/privkey.pem || fail 'mount readable TURN certificate chain and private key'
  printf 'tls-listening-port=5349\ncert=/run/turn-certs/fullchain.pem\npkey=/run/turn-certs/privkey.pem\n' >> /tmp/turnserver.conf
else
  printf 'no-tls\n' >> /tmp/turnserver.conf
fi
echo "TURN startup: public mapping validated; listener/relay configured; UDP relay $TURN_MIN_PORT-$TURN_MAX_PORT; TLS=$TURN_TLS"
exec turnserver -c /tmp/turnserver.conf
