FROM alpine:latest

RUN apk --no-cache add dhcp-helper && \
    rm -rf /var/cache/apk/*

ENV IP=""

EXPOSE 67/udp

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD [ "nc", "-uzvw3", "localhost", "67" ] || exit 1

ENTRYPOINT ["dhcp-helper", "-n", "-s", "${IP:-NODATA}"]
