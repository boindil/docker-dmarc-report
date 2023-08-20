ARG UPSTREAM_IMAGE=trafex/php-nginx:3.2.0

FROM $UPSTREAM_IMAGE

LABEL maintainer="Robert Schumann <rs@n-os.org>"

ENV REPORT_PARSER_SOURCE="https://github.com/boindil/dmarcts-report-parser/archive/master.zip" \
  REPORT_VIEWER_SOURCE="https://github.com/techsneeze/dmarcts-report-viewer/archive/master.zip"

USER root

WORKDIR /

# split this into multiple commands because of directory permissions
COPY ./manifest/ /manifest
RUN (find /manifest -type d -print0 | xargs -0 chmod 755) \
  && (find /manifest -type f -print0 | xargs -0 chmod 644) \
  && cp -a /manifest/* / \
  && rm -rf /manifest

RUN chown -R nobody /etc/cron.d/

RUN apk add --no-cache dcron libcap && \
    chown nobody:nobody /usr/sbin/crond && \
    setcap cap_setgid=ep /usr/sbin/crond

RUN set -x \
  && apk add -U \
  bash \
  expat-dev \
  g++ \
  gzip \
  libpq \
  libpq-dev \
  make \
  mariadb-client \
  mariadb-connector-c \
  mariadb-dev \
  musl-obstack \
  musl-obstack-dev \
  openssl \
  openssl-dev \
  perl-dev \
  perl-utils \
  php82-pdo \
  php82-pdo_mysql \
  php82-pdo_pgsql \
  tzdata \
  wget \
  && wget -4 -q --no-check-certificate -O parser.zip $REPORT_PARSER_SOURCE \
  && wget -4 -q --no-check-certificate -O viewer.zip $REPORT_VIEWER_SOURCE \
  && unzip parser.zip && cp -av dmarcts-report-parser-master/* /usr/bin/ && rm -vf parser.zip && rm -rvf dmarcts-report-parser-master \
  && unzip viewer.zip && cp -av dmarcts-report-viewer-master/* /var/www/viewer/ && rm -vf viewer.zip && rm -rvf dmarcts-report-viewer-master \
  && sed -i "1s/^/body { font-family: Sans-Serif; }\n/" /var/www/viewer/default.css \
  && sed -i 's%.*root /var/www/html;%        root /var/www/viewer;%g' /etc/nginx/conf.d/default.conf \
  && sed -i 's/.*index index.php index.html;/        index dmarcts-report-viewer.php;/g' /etc/nginx/conf.d/default.conf \
  && sed -i 's%files = /etc/supervisor.d/\*.ini%files = /etc/supervisor/conf.d/*.conf%g' /etc/supervisord.conf \
  && chown nobody /etc/supervisord.conf \
  && (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan \
  && for i in \
  IO::Socket::SSL \
  CPAN \
  CPAN::DistnameInfo \
  File::MimeInfo \
  File::Slurper \
  File::stat \
  Getopt::Long \
  IO::Compress::Gzip \
  JSON \
  LWP::UserAgent \
  LWP::Protocol::https \
  Mail::IMAPClient \
  Mail::Mbox::MessageParser \
  MIME::Base64 \
  MIME::Words \
  MIME::Parser \
  MIME::Parser::Filer \
  XML::Parser \
  XML::Simple \
  DBI \
  DBD::mysql \
  DBD::Pg \
  Socket \
  Socket6 \
  Switch \
  PerlIO::gzip \
  ; do cpan install $i; done \
  && apk del mariadb-dev expat-dev openssl-dev perl-dev g++ make musl-obstack-dev libpq-dev

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R nobody.nobody /var/www /var/lib/nginx /var/log/nginx \
  && chmod 755 /var/lib/nginx

HEALTHCHECK --interval=1m --timeout=3s CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping

EXPOSE 8080

CMD ["/bin/bash", "/entrypoint.sh"]
