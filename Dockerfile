ARG RUBY_VERSION
ARG DISTRO_NAME=bullseye

FROM ruby:$RUBY_VERSION-slim-$DISTRO_NAME

ARG DISTRO_NAME
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  rm -f /etc/apt/apt.conf.d/docker-clean; \
  echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache; \
  apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    build-essential \
    gnupg2 \
    curl \
    less \
    git \
    nodejs \
    libpq-dev \
    imagemagick \
    libmagickwand-dev \
    tzdata \
    libsqlite3-dev

WORKDIR /app
COPY . .
RUN gem install bundler -v 2.3.17
RUN bundle install
EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0", "-P", "/tmp/pids/server.pid"]
