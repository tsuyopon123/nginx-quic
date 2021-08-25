FROM ubuntu:20.04 AS build

WORKDIR /src

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y git mercurial cmake make golang libunwind-dev libpcre3-dev zlib1g-dev gcc g++;

RUN git clone https://boringssl.googlesource.com/boringssl && \
    cd boringssl && \
    mkdir build && \
    cd build && \
    cmake ..&& \
    make && \
    cd .. && \
    go run util/all_tests.go && \
    cd ssl/test/runner && \
    go test;

RUN hg clone -b quic https://hg.nginx.org/nginx-quic && \
    cd nginx-quic && \
    ./auto/configure  \
    --with-debug \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-http_quic_module \
    --with-stream \
    --with-stream_quic_module \
    --with-http_ssl_module \
    --with-cc-opt="-I../boringssl/include"   \
    --with-ld-opt="-L../boringssl/build/ssl  \
                   -L../boringssl/build/crypto" \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx && \
    make && \
    make install;

FROM ubuntu:20.04

COPY --from=build /usr/sbin/nginx /usr/sbin/
COPY --from=build /etc/nginx/ /etc/nginx/


RUN groupadd -g 1000 nginx \
  && useradd -m -u 1000 -d /var/cache/nginx -s /sbin/nologin -g nginx nginx \
  && mkdir -p /var/log/nginx \
  && touch /var/log/nginx/access.log /var/log/nginx/error.log \
  && chown nginx: /var/log/nginx/access.log /var/log/nginx/error.log \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]