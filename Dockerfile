# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3.6

# ─── Base ──────────────────────────────────────────────────────────────────────
FROM ruby:${RUBY_VERSION}-slim AS base

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential curl git libpq-dev libyaml-dev libvips postgresql-client tzdata nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /rails

# ─── Development ───────────────────────────────────────────────────────────────
FROM base AS development

ENV RAILS_ENV=development

COPY Gemfile Gemfile.lock ./
RUN bundle install

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]

# ─── Builder (produção) ────────────────────────────────────────────────────────
FROM base AS builder

COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment true && \
    bundle config set --local without "development test" && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

RUN bundle exec bootsnap precompile --gemfile app/ lib/
RUN SECRET_KEY_BASE=dummy RAILS_ENV=production bin/rails assets:precompile
RUN rm -rf tmp/cache spec

# ─── Production ────────────────────────────────────────────────────────────────
FROM base AS production

ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

RUN groupadd --gid 1000 rails && \
    useradd --uid 1000 --gid rails --shell /bin/bash --create-home rails

COPY --from=builder --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=rails:rails /rails /rails

USER rails

EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
