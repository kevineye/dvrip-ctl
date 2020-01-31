FROM alpine

RUN apk --no-cache add \
      ffmpeg \
      perl \
      perl-json

RUN ln -s /app/dvrip-ctl.pl /usr/local/bin/dvrip-ctl

COPY . /app

WORKDIR /app
ENTRYPOINT ["dvrip-ctl"]
CMD ["-h"]
