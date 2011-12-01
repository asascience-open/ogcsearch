WMS_URL_REGEX=/[a-zA-Z0-9\&=?\.\/:]+request=getcapabilities[a-zA-Z0-9\&=?;]*(?:\.[0-9])*/i
KMX_URL_REGEX=/([a-zA-Z0-9_\-\.\/:]+\.km[lz]{1})[\W]/i

GETCAP_REGEX = /request=getcapabilities/i
WMS_SERVICE_REGEX = /service=wms/i
KMX_LINK_REGEX = /\.km[lz]{1}/