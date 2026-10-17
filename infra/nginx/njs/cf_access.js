// Cloudflare Access JWT check at the origin (#393), run as the auth_request
// subrequest of snippets/cf-access.conf. Runbook: docs/access-jwt.md.
//
// Mode per host comes from $cf_access_mode (conf.d/cf-access.conf):
//   off     - allow, nothing checked (no config read, no fetch)
//   log     - check, allow, log failures at warn
//   enforce - check, deny failures (401 no token, 403 anything else)
// Config is the cf_access secret (never committed):
//   {"team_domain": "<team>.cloudflareaccess.com", "aud": {"<subdomain>": "<aud tag>", ...}}

import fs from 'fs';

const CONFIG_FILE = '/run/secrets/cf_access';
const SKEW = 60;             // seconds tolerated on exp/nbf
const REFETCH_MS = 60000;    // at most one JWKS refetch per minute on an unknown kid

// r is the auth subrequest: it carries the client's headers and shares the
// main request's variables ($cf_access_skip/$cf_access_path are pinned in
// snippets/cf-access.conf, since its own $uri is /_cf_access).
async function verify(r) {
    const v = r.variables;
    const mode = v.cf_access_mode;
    if ((mode !== 'log' && mode !== 'enforce') || v.cf_access_skip === '1') {
        return r.return(204);
    }

    let result;
    try {
        result = await check(r);
    } catch (e) {
        result = 'error: ' + e.message;
    }
    if (result === 'ok') {
        return r.return(204);
    }

    ngx.log(ngx.WARN, `cf_access ${mode}: ${result} (host=${v.host} `
        + `path=${v.cf_access_path} client=${r.remoteAddress})`);
    if (mode === 'log') {
        return r.return(204);
    }
    r.return(result === 'missing token' ? 401 : 403);
}

async function check(req) {
    const token = req.headersIn['Cf-Access-Jwt-Assertion'];
    if (!token) {
        return 'missing token';
    }
    const parts = token.split('.');
    if (parts.length !== 3) {
        return 'malformed token';
    }
    const header = decode(parts[0]);
    const claims = decode(parts[1]);

    const config = JSON.parse(fs.readFileSync(CONFIG_FILE));
    const want = config.aud[req.variables.host.split('.')[0]];
    if (!want) {
        return 'no aud configured for host';
    }
    const auds = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    if (!auds.includes(want)) {
        return 'wrong aud';
    }
    if (claims.iss !== 'https://' + config.team_domain) {
        return 'wrong iss';
    }
    const now = Date.now() / 1000;
    if (!(claims.exp > now - SKEW)) {
        return 'expired';
    }
    if (claims.nbf && claims.nbf > now + SKEW) {
        return 'not yet valid';
    }
    if (header.alg !== 'RS256') {
        return 'unexpected alg';
    }

    const key = await signingKey(config.team_domain, header.kid);
    if (!key) {
        return 'unknown kid';
    }
    const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key,
        Buffer.from(parts[2], 'base64url'), Buffer.from(parts[0] + '.' + parts[1]));
    return valid ? 'ok' : 'bad signature';
}

function decode(part) {
    return JSON.parse(Buffer.from(part, 'base64url').toString());
}

// JWKS cached in the cf_access shared dict (zone timeout 1h); Cloudflare
// rotates keys every 6 weeks and keeps the previous one valid for 7 days.
async function signingKey(teamDomain, kid) {
    const cache = ngx.shared.cf_access;
    let jwks = cache.get('jwks');
    let jwk = findKey(jwks, kid);
    if (!jwk && (!jwks || cache.add('refetch', '1', REFETCH_MS))) {
        const res = await ngx.fetch(`https://${teamDomain}/cdn-cgi/access/certs`);
        if (!res.ok) {
            throw Error('certs fetch HTTP ' + res.status);
        }
        jwks = await res.text();
        cache.set('jwks', jwks);
        jwk = findKey(jwks, kid);
    }
    if (!jwk) {
        return null;
    }
    return crypto.subtle.importKey('jwk', { kty: jwk.kty, n: jwk.n, e: jwk.e },
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
}

function findKey(jwks, kid) {
    if (!jwks) {
        return null;
    }
    return JSON.parse(jwks).keys.find((k) => k.kid === kid) || null;
}

export default { verify };
