#!/bin/bash
# Self-check for oracle_a1_automation-v2.sh helpers
set -u
fail=0

extract_ocid() {
    echo "$1" | grep -oE 'ocid1\.[a-z0-9]+\.[a-z0-9-]+\.[^[:space:]"]+' | head -1
}

tg_escape() {
    local s="$1" amp lt gt
    amp=$(printf '\046')
    lt=$(printf '\074')
    gt=$(printf '\076')
    s=${s//"$amp"/"$amp"amp;}
    s=${s//"$lt"/"$amp"lt;}
    s=${s//"$gt"/"$amp"gt;}
    printf '%s' "$s"
}

main_retry_wait() {
    local retries="$1"
    if [ ${retries} -gt 4 ]; then retries=4; fi
    local wait_time=$((BASE_WAIT * (2 ** retries)))
    local jitter=$((RANDOM % 10))
    if [ ${wait_time} -gt ${MAX_WAIT} ]; then wait_time=${MAX_WAIT}; fi
    echo $((wait_time + jitter))
}
BASE_WAIT=50
MAX_WAIT=600

# 1. extract_ocid: warning-polluted output still yields ocid (issue #3 core bug)
r=$(extract_ocid "/root/lib/oracle-cli/lib/python3.10/site-packages/urllib3/poolmanager.py:329: FutureWarning: The 'strict' parameter is no longer needed on Python 3+.
ocid1.ormjob.oc1.eu-amsterdam-1.censored")
if [ "${r}" = "ocid1.ormjob.oc1.eu-amsterdam-1.censored" ]; then
    echo "PASS extract_ocid warning-polluted"
else
    echo "FAIL extract_ocid: got '${r}'"; fail=1
fi

# 2. extract_ocid: no ocid -> empty
r=$(extract_ocid "ServiceError: something broke")
if [ -z "${r}" ]; then
    echo "PASS extract_ocid empty"
else
    echo "FAIL extract_ocid empty: got '${r}'"; fail=1
fi

# 3. tg_escape escapes HTML specials
# expected built via octal printf so editors cannot rewrite entities
exp="a$(printf '\046')lt;b$(printf '\046')gt;$(printf '\046')amp;c"
r=$(tg_escape "a$(printf '\074')b$(printf '\076')$(printf '\046')c")
if [ "${r}" = "${exp}" ]; then
    echo "PASS tg_escape"
else
    echo "FAIL tg_escape: got '${r}'"; fail=1
fi

# 4. main_retry_wait caps at MAX_WAIT even after huge retry counts (int64 overflow guard)
r=$(main_retry_wait 63)
if [ "${r}" -ge 600 ] && [ "${r}" -le 609 ]; then
    echo "PASS backoff cap at 63 retries"
else
    echo "FAIL backoff cap: got '${r}'"; fail=1
fi

# 5. main_retry_wait normal progression
r=$(main_retry_wait 0)
if [ "${r}" -ge 50 ] && [ "${r}" -le 59 ]; then
    echo "PASS backoff base"
else
    echo "FAIL backoff base: got '${r}'"; fail=1
fi

if [ ${fail} -eq 0 ]; then
    echo "ALL_CHECKS_PASS"
else
    exit 1
fi