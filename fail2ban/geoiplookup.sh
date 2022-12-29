#! /usr/bin/sh

curl https://geolite.info/geoip/v2.1/country/$1 --user $USER:$LICENSE 2>/dev/null | jq -r .country.iso_code
