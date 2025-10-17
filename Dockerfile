# This Dockerfile uses the official Elixir images from erlef/docker-elixir
# which are based on the official Erlang images.
#
# https://hub.docker.com/_/elixir
# https://github.com/erlef/docker-elixir
#
# This file is based on the official Elixir Dockerfile pattern for Phoenix apps.

ARG ELIXIR_VERSION=1.18
ARG DEBIAN_VERSION=bookworm-20250929-slim

FROM elixir:${ELIXIR_VERSION} as builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build directory
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# Copy assets
COPY assets assets

# Compile the release
RUN mix compile

# Build assets - install npm packages and build assets
RUN mix assets.setup
RUN mix assets.deploy

# Compile the release
RUN mix phx.digest

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Build the release
RUN mix release

# Start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM debian:${DEBIAN_VERSION}

RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/cloudflare_dns ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes, it is
# advised to add an init process such as tini via `apt-get install`
# above and adding an entrypoint. See https://github.com/krallin/tini for details
# ENV TINI_VERSION v0.19.0
# ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
# RUN chmod +x /tini
# ENTRYPOINT ["/tini", "--"]

# Set the runtime PORT
ENV PORT="4000"
ENV PHX_SERVER="true"

# Expose the port
EXPOSE 4000

CMD ["/app/bin/server"]
