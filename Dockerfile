FROM ruby:2.4.1

LABEL mantainer="michele.sacchetti@aroundthecode.org" \
 app.name="cassandra-web" \
 version="0.4.1"

ADD cassandra-web-*.gem /
ADD entrypoint.sh /

RUN \
  gem install cassandra-web && \
  chmod a+x /entrypoint.sh && \
  rm -f cassandra-web-*.gem

EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]