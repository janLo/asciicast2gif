FROM clojure:alpine AS cljs

RUN mkdir /app
WORKDIR /app

COPY project.clj /app/
RUN lein deps

COPY asciinema-player /app/asciinema-player
COPY src /app/src
COPY externs /app/externs
RUN lein cljsbuild once main && lein cljsbuild once page

FROM debian:buster as gifsicle

RUN apt-get update && apt-get install -y wget build-essential automake
RUN wget https://github.com/kohler/gifsicle/archive/refs/tags/v1.92.tar.gz
RUN tar xzf v1.92.tar.gz
RUN cd gifsicle-1.92 && autoreconf -i && ./configure --disable-gifview && make && make install

FROM node:14-buster

ARG DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_CONF=/etc/ssl/

RUN apt-get update && \
    apt-get install -y wget apt-transport-https && \
    apt-get install -y \
      bzip2 \
      imagemagick \      
      fonts-hack-ttf \
      libfontconfig1 \
      ttf-bitstream-vera && \
    rm -rf /var/lib/apt/lists/*

ARG PHANTOMJS_VERSION=2.1.1

RUN wget --quiet -O /opt/phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-$PHANTOMJS_VERSION-linux-x86_64.tar.bz2 && \
    tar xjf /opt/phantomjs.tar.bz2 -C /opt && \
    rm /opt/phantomjs.tar.bz2 && \
    ln -sf /opt/phantomjs-$PHANTOMJS_VERSION-linux-x86_64/bin/phantomjs /usr/local/bin
    
RUN sed -i 's#^\s<policy domain="resource.>$#<!-- \0 -->#' /etc/ImageMagick-6/policy.xml

RUN mkdir /app
WORKDIR /app

COPY package.json /app/
RUN npm install

COPY asciicast2gif /app/
COPY renderer.js /app/
COPY page /app/page
COPY --from=cljs /app/main.js /app/
COPY --from=cljs /app/page/page.js /app/page/
COPY --from=gifsicle /usr/local/bin/gifsicle /usr/local/bin/

WORKDIR /data
VOLUME ["/data"]

ENTRYPOINT ["/app/asciicast2gif"]
