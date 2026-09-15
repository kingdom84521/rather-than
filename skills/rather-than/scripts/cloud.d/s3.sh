#!/usr/bin/env bash
# cloud.d/s3.sh — any S3-compatible object store: Cloudflare R2, AWS S3,
# Backblaze B2, MinIO, … Requests are signed with SigV4 by hand (bash + curl +
# openssl); no SDK, no CLI to install. Sourced by cloud.sh; contract in README.md.
#
# cloud.conf keys:
#   adapter = s3
#   provider = r2 | aws | minio | other
#   account_id = <cloudflare account id>   r2: the endpoint is derived from it
#   endpoint = https://host[:port]         minio/other: required; aws: derived from region
#   region = auto | us-east-1 | …          r2 defaults to auto, the rest to us-east-1
#   addressing = path | virtual            path: https://host/bucket/key (default)
#                                          virtual: https://bucket.host/key (aws default)
#   bucket = <existing bucket>             never created here — API tokens usually may not
#   prefix = personal                      optional key prefix inside the bucket
#   access_key_id = …                      or the AWS_ACCESS_KEY_ID environment variable
#   secret_access_key = …                  or AWS_SECRET_ACCESS_KEY
# Object keys are the store paths (prefer/<slug>.md …), ASCII like the slugs.

adapter_setup() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --provider)   CFG[provider]="$2"; shift ;;
      --account-id) CFG[account_id]="$2"; shift ;;
      --endpoint)   CFG[endpoint]="$2"; shift ;;
      --region)     CFG[region]="$2"; shift ;;
      --addressing) CFG[addressing]="$2"; shift ;;
      --bucket)     CFG[bucket]="$2"; shift ;;
      --prefix)     CFG[prefix]="$2"; shift ;;
      --access-key) CFG[access_key_id]="$2"; shift ;;
      --secret-key) CFG[secret_access_key]="$2"; shift ;;
      *) die "s3 setup: unknown flag $1 (--provider --account-id --endpoint --region --addressing --bucket --prefix --access-key --secret-key)" ;;
    esac
    shift
  done
  ask provider "provider (r2 = Cloudflare R2, aws = AWS S3, minio = MinIO, other = any S3 endpoint)" r2
  case "${CFG[provider]}" in
    r2)    ask account_id "Cloudflare account id (dashboard → R2 → Overview → Account ID)" ;;
    aws)   ask region "AWS region" us-east-1 ;;
    minio) ask endpoint "MinIO endpoint URL (e.g. http://minio.local:9000)"; ask region "region (MinIO's default is us-east-1)" us-east-1 ;;
    other) ask endpoint "endpoint URL (https://host[:port])"; ask region "region" us-east-1 ;;
    *) die "provider must be r2, aws, minio or other" ;;
  esac
  ask bucket "bucket (must already exist)" rather-than
  ask prefix "key prefix inside the bucket" personal
  ask access_key_id "access key id"
  ask secret_access_key "secret access key" "" secret
}

adapter_init() {
  S3_PROVIDER="$(cfg provider other)"
  S3_BUCKET="$(cfg bucket)"; [ -n "$S3_BUCKET" ] || die "cloud.conf: bucket is required"
  S3_AK="${CFG[access_key_id]:-${AWS_ACCESS_KEY_ID:-}}"
  S3_SK="${CFG[secret_access_key]:-${AWS_SECRET_ACCESS_KEY:-}}"
  { [ -n "$S3_AK" ] && [ -n "$S3_SK" ]; } || die "cloud.conf: access_key_id and secret_access_key are required (or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY in the environment)"
  local ep region addr
  case "$S3_PROVIDER" in
    r2)  [ -n "$(cfg account_id)" ] || die "cloud.conf: account_id is required for provider = r2"
         ep="$(cfg endpoint "https://$(cfg account_id).r2.cloudflarestorage.com")"; region="$(cfg region auto)"; addr="$(cfg addressing path)" ;;
    aws) region="$(cfg region us-east-1)"; ep="$(cfg endpoint "https://s3.$region.amazonaws.com")"; addr="$(cfg addressing virtual)" ;;
    minio|*) ep="$(cfg endpoint)"; [ -n "$ep" ] || die "cloud.conf: endpoint is required for provider = $S3_PROVIDER (minio: http(s)://host:9000)"
         region="$(cfg region us-east-1)"; addr="$(cfg addressing path)" ;;
  esac
  S3_REGION="$region"
  case "$ep" in *://*) S3_SCHEME="${ep%%://*}"; S3_HOST="${ep#*://}" ;; *) S3_SCHEME=https; S3_HOST="$ep" ;; esac
  S3_HOST="${S3_HOST%%/*}"
  if [ "$addr" = virtual ]; then S3_HOST="$S3_BUCKET.$S3_HOST"; S3_BASE=""; else S3_BASE="/$S3_BUCKET"; fi
  S3_PREFIX="$(cfg prefix)"; S3_PREFIX="${S3_PREFIX#/}"; S3_PREFIX="${S3_PREFIX%/}"
  S3_PFX="${S3_PREFIX:+$S3_PREFIX/}"
  S3_EMPTY=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  S3_TMP="$(mktemp -d)"; S3_HDRS="$S3_TMP/hdrs"; S3_BODY="$S3_TMP/body"; S3_NEXTF="$S3_TMP/next"
  CLEANUP+=("$S3_TMP")
}

# --- SigV4 ---------------------------------------------------------------------
s3_hex()    { printf '%s' "$1" | od -An -tx1 | tr -d ' \n'; }
s3_hmac()   { printf '%s' "$2" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$1" | sed 's/^.*= *//'; }
s3_sha256() { printf '%s' "$1" | sha256sum | cut -c1-64; }
s3_uriencode() { # <string> <keep-slash 0|1> — RFC 3986, uppercase hex, byte-wise for non-ASCII
  local s="$1" keep="$2" out="" i c
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [A-Za-z0-9._~-]) out+="$c" ;;
      /) if [ "$keep" = 1 ]; then out+="/"; else out+="%2F"; fi ;;
      *) out+="$(printf '%s' "$c" | od -An -tx1 | tr -d ' \n' | sed 's/../%&/g' | tr 'a-f' 'A-F')" ;;
    esac
  done
  printf '%s' "$out"
}
# sigv4_sign METHOD URI QUERY CANONICAL_HEADERS SIGNED_HEADERS PAYLOAD_HASH AMZDATE REGION SERVICE SECRET → signature
sigv4_sign() {
  local creq sts date="${7:0:8}" k
  creq="$1"$'\n'"$2"$'\n'"$3"$'\n'"$4"$'\n'"$5"$'\n'"$6"
  sts="AWS4-HMAC-SHA256"$'\n'"$7"$'\n'"$date/$8/$9/aws4_request"$'\n'"$(s3_sha256 "$creq")"
  k="$(s3_hmac "$(s3_hex "AWS4${10}")" "$date")"
  k="$(s3_hmac "$k" "$8")"; k="$(s3_hmac "$k" "$9")"; k="$(s3_hmac "$k" aws4_request)"
  s3_hmac "$k" "$sts"
}

# s3_request METHOD KEY CANONICAL_QUERY [BODYFILE] [OUTFILE] → S3_CODE; response headers in $S3_HDRS
s3_request() {
  local method="$1" key="$2" query="$3" body="${4:-}" out="${5:-$S3_BODY}" amz phash uri hdrs signed sig auth url
  amz="${S3_TEST_DATE:-$(date -u +%Y%m%dT%H%M%SZ)}"
  if [ -n "$body" ]; then phash="$(sha256sum "$body" | cut -c1-64)"; else phash="$S3_EMPTY"; fi
  uri="$S3_BASE/$(s3_uriencode "$key" 1)"
  hdrs="host:$S3_HOST"$'\n'"x-amz-content-sha256:$phash"$'\n'"x-amz-date:$amz"$'\n'
  signed="host;x-amz-content-sha256;x-amz-date"
  sig="$(sigv4_sign "$method" "$uri" "$query" "$hdrs" "$signed" "$phash" "$amz" "$S3_REGION" s3 "$S3_SK")"
  auth="AWS4-HMAC-SHA256 Credential=$S3_AK/${amz:0:8}/$S3_REGION/s3/aws4_request, SignedHeaders=$signed, Signature=$sig"
  url="$S3_SCHEME://$S3_HOST$uri${query:+?$query}"
  : > "$S3_HDRS"; : > "$S3_BODY"
  local args=(-sS --max-time 60 --connect-timeout 10 -X "$method" -H "Expect:" -H "x-amz-content-sha256: $phash" -H "x-amz-date: $amz" -H "Authorization: $auth" -D "$S3_HDRS" -o "$out" -w '%{http_code}')
  [ -n "$body" ] && args+=(-T "$body")
  S3_CODE="$(curl "${args[@]}" "$url" 2>"$S3_TMP/curl.err")" || S3_CODE=000
}
s3_errcode() { tr -d '\n' < "$S3_BODY" 2>/dev/null | sed -n 's/.*<Code>\([^<]*\)<\/Code>.*/\1/p'; }
s3_explain() { # human message for a failed request
  case "$S3_CODE" in
    000) warn "cannot reach $S3_SCHEME://$S3_HOST — $(tr -d '\n' < "$S3_TMP/curl.err" | cut -c1-160)" ;;
    403) warn "403 from $S3_HOST ($(s3_errcode)) — check access_key_id / secret_access_key, and that the token may read and write bucket '$S3_BUCKET'" ;;
    404) warn "404 from $S3_HOST ($(s3_errcode)) — bucket '$S3_BUCKET' does not exist here; create it in the provider's dashboard, then rerun" ;;
    301|400) warn "$S3_CODE from $S3_HOST ($(s3_errcode)) — usually a wrong region or endpoint for this bucket$(tr -d '\n' < "$S3_BODY" | sed -n 's/.*<Region>\([^<]*\)<\/Region>.*/; the bucket says its region is \1/p')" ;;
    *)   warn "$S3_CODE from $S3_HOST ($(s3_errcode))" ;;
  esac
}
s3_xmlunesc() { sed 's/&quot;/"/g; s/&lt;/</g; s/&gt;/>/g; s/&#39;/'"'"'/g; s/&apos;/'"'"'/g; s/&amp;/\&/g'; }

s3_list_page() { # <continuation-token|""> → rows on stdout; next token into $S3_NEXTF
  local tok="$1" q="list-type=2&max-keys=1000"
  [ -n "$S3_PFX" ] && q="$q&prefix=$(s3_uriencode "$S3_PFX" 0)"
  [ -n "$tok" ] && q="continuation-token=$(s3_uriencode "$tok" 0)&$q"   # keys already in canonical (sorted) order
  s3_request GET "" "$q"
  [ "$S3_CODE" = 200 ] || { s3_explain; return 1; }
  tr -d '\n\r' < "$S3_BODY" | sed -n 's/.*<NextContinuationToken>\([^<]*\)<\/NextContinuationToken>.*/\1/p' | s3_xmlunesc > "$S3_NEXTF"
  tr -d '\n\r' < "$S3_BODY" | sed 's/<Contents>/\n<Contents>/g' | TZ=UTC awk -v pfx="$S3_PFX" '
    function get(tag,   a, b, s) { a = index($0, "<" tag ">"); if (!a) return ""; s = substr($0, a + length(tag) + 2); b = index(s, "</" tag ">"); return substr(s, 1, b - 1) }
    function unesc(s) { gsub(/&quot;/, "\"", s); gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s); gsub(/&#39;|&apos;/, "\047", s); gsub(/&amp;/, "\\&", s); return s }
    /^<Contents>/ {
      k = unesc(get("Key")); e = get("ETag"); m = get("LastModified")
      gsub(/&quot;|"/, "", e)
      if (pfx != "" && index(k, pfx) != 1) next
      k = substr(k, length(pfx) + 1)
      n = split(m, d, /[-T:.Z]/)
      printf "%s\t%s\t%d\n", k, e, (n >= 6 ? mktime(d[1] " " d[2] " " d[3] " " d[4] " " d[5] " " d[6]) : 0)
    }'
}

adapter_check() {
  s3_request GET "" "list-type=2&max-keys=1${S3_PFX:+&prefix=$(s3_uriencode "$S3_PFX" 0)}"
  [ "$S3_CODE" = 200 ] && return 0
  s3_explain; return 1
}
adapter_list() {
  local tok="" page
  while :; do
    page="$(s3_list_page "$tok")" || return 1
    [ -n "$page" ] && printf '%s\n' "$page"
    tok="$(cat "$S3_NEXTF" 2>/dev/null)"
    [ -n "$tok" ] || break
  done
  return 0
}
adapter_get() { # path localfile
  s3_request GET "$S3_PFX$1" "" "" "$2"
  case "$S3_CODE" in 200) return 0 ;; 404) return 2 ;; *) s3_explain; return 1 ;; esac
}
adapter_put() { # path localfile → token
  s3_request PUT "$S3_PFX$1" "" "$2"
  [ "$S3_CODE" = 200 ] || { s3_explain; return 1; }
  local tok; tok="$(grep -i '^etag:' "$S3_HDRS" | head -n 1 | sed 's/^[^:]*:[[:space:]]*//; s/[[:space:]"]//g')"
  printf '%s' "${tok:-?}"
}
adapter_delete() { # path
  s3_request DELETE "$S3_PFX$1" ""
  case "$S3_CODE" in 200|204|404) return 0 ;; *) s3_explain; return 1 ;; esac
}
