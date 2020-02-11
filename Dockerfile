FROM alpine

COPY cpanfile /tmp/cpanfile
RUN apk --no-cache add \
      ffmpeg \
      gcc \
      make \
      musl-dev \
      jq \
      perl-app-cpanminus \
      perl-dev \
      perl-io-socket-ssl \
      perl-json \
      perl-module-build \
      tzdata \
 && cpanm --no-wget --installdeps /tmp \
 && apk --no-cache del \
      gcc \
      make \
      musl-dev \
      perl-dev

RUN ln -s /app/dvrip-ctl.pl /usr/local/bin/dvrip-ctl

COPY . /app

WORKDIR /app

ENTRYPOINT ["dvrip-ctl"]
CMD ["-h"]

#EXPOSE 3000
#CMD [ "morbo", "-w", "app.pl", "-w", "lib", "-w", "/conf/streams.yaml", "app.pl" ]
