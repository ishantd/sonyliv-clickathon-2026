#!/bin/bash
#
# Renew the Let's Encrypt certificate for fastandfurious.live.
#
# Install once, by hand, as root:
#
#   sudo install -m 0755 deploy/tls-renew.sh /usr/local/sbin/sonyliv-tls-renew
#   sudo cp deploy/sonyliv-tls-renew.service deploy/sonyliv-tls-renew.timer /etc/systemd/system/
#   sudo systemctl daemon-reload
#   sudo systemctl enable --now sonyliv-tls-renew.timer
#
# WHY THIS SCRIPT EXISTS AT ALL, instead of a timer that just runs `lego renew`.
#
# The cert is validated with TLS-ALPN-01, because the security group opens 443 and
# nothing else, so HTTP-01 challenges cannot reach the box -- see the long note in
# deploy/nginx/sonyliv.conf. TLS-ALPN-01 means the ACME solver has to be the thing
# listening on 443, which means nginx has to let go of it for about thirty seconds.
#
# `lego renew --days N` is already a no-op when the cert is young, so a naive daily
# timer would renew correctly. The problem is the ordering: nginx must be stopped
# BEFORE lego can bind 443, so a naive script stops nginx every single day to run a
# command that then decides it has nothing to do. That trades one 30-second outage a
# quarter for one every morning.
#
# So the expiry check happens here, first, with openssl and with nginx still serving.
# Only if the cert is genuinely inside the renewal window do we take the port away.
# In steady state this script touches nothing and exits in milliseconds.
set -uo pipefail

DOMAIN=fastandfurious.live
ALT=www.fastandfurious.live
EMAIL=siddhartha.mishra@gobblecube.ai
LEGO_PATH=/etc/lego
CRT="$LEGO_PATH/certificates/$DOMAIN.crt"

# 30 days of slack. Let's Encrypt certs live 90 days, so this leaves two months of
# failed attempts, alerts and human holidays before anything actually expires.
#
# Overridable from the environment for one specific reason: it is the only way to
# exercise the renewal path on demand. A fresh cert makes this script a no-op for
# sixty days, so `RENEW_WITHIN_DAYS=95 sonyliv-tls-renew` is how you prove the
# stop-solve-start sequence still works without waiting for the calendar. It does a
# real issuance, so keep an eye on the duplicate-certificate rate limit (5/week).
RENEW_WITHIN_DAYS=${RENEW_WITHIN_DAYS:-30}

if [ ! -f "$CRT" ]; then
    echo "no certificate at $CRT -- run the initial issuance by hand, see sonyliv.conf" >&2
    exit 1
fi

# -checkend takes seconds and exits 0 when the cert is STILL valid that far out,
# which is the "nothing to do" case.
if openssl x509 -in "$CRT" -noout -checkend $((RENEW_WITHIN_DAYS * 86400)); then
    echo "$DOMAIN valid beyond $RENEW_WITHIN_DAYS days ($(openssl x509 -in "$CRT" -noout -enddate)) -- nothing to do"
    exit 0
fi

echo "$DOMAIN inside the $RENEW_WITHIN_DAYS-day window -- renewing over TLS-ALPN-01"

# From here on nginx is down, so every exit path has to bring it back. A trap rather
# than a careful sequence of ifs: it also covers lego segfaulting, the box being
# rebooted mid-run, and systemd timing the unit out.
restore_nginx() {
    systemctl start nginx
    echo "nginx: $(systemctl is-active nginx)"
}
trap restore_nginx EXIT

systemctl stop nginx

lego --accept-tos --email "$EMAIL" \
    --domains "$DOMAIN" --domains "$ALT" \
    --tls \
    --path "$LEGO_PATH" \
    renew --days "$RENEW_WITHIN_DAYS"
rc=$?

if [ "$rc" -ne 0 ]; then
    echo "lego renew failed with $rc -- the old cert is untouched and still being served" >&2
    exit "$rc"
fi

echo "renewed: $(openssl x509 -in "$CRT" -noout -enddate)"

# No explicit reload: the trap starts nginx from stopped, and a starting nginx reads
# the cert off disk. A reload here would be a second, redundant read.
exit 0
