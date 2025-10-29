ARG ALPINE_VERSION=3.22.0
ARG NODE_VERSION=22.16.0

FROM node:${NODE_VERSION}-alpine AS node
FROM alpine:${ALPINE_VERSION}

ARG UID
ARG GID
ARG USER
ARG GROUP
ENV UID=${UID}
ENV GID=${GID}
ENV USER=${USER}
ENV GROUP=${GROUP}

# Setup unique user and group - needs bash
RUN apk add --no-cache bash

# Create user and group
RUN addgroup -S --gid ${GID} ${GROUP} \
    && adduser -S --uid ${UID} ${USER} -s /bin/sh -G ${GROUP} ${USER} \
    && apk add --no-cache sudo \
    && chmod u+s /bin/su \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install main packages and remove default server definition
RUN apk add --no-cache \
  openrc \
  curl \
  wget \
  openssl \
  nginx \
  zip \
  nano \
  git \
  #ffmpeg \
  libva-dev \
  supervisor

# Configure NGINX and remove created its default html directory
COPY config/nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/nginx/conf.d /etc/nginx/conf.d/

# Configure Supervisord
COPY config/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY config/supervisor/conf.d/. /etc/supervisor/conf.d/

# Configure NodeJS
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

RUN node -v

RUN npm install -g yarn --force
RUN npm -v
RUN yarn -v

# NPM packages installation into the prefix folder instead of the current working directory
RUN npm config set prefix

# Create project root and set it as work directory
RUN mkdir -p /var/www
WORKDIR /var/www

# Add application from docker-compose.yml -> volumes: source
COPY --chown=${USER}:${GROUP} ../ /var/www

# Remove unused directories
RUN rm -rf /var/www/html /var/www/localhost

# Make sure files/folders needed by the processes are accessable when they run under the nobody user
RUN chown -R ${USER}:${GROUP} /var/www /run /var/lib/nginx /var/log/nginx

# Switch to use a non-root user from here on
USER ${USER}

# Make NPM accessible for current user
RUN mkdir ~/.npm-global
RUN npm config set prefix '~/.npm-global'
RUN export PATH=~/.npm-global/bin:$PATH
RUN touch ~/.profile
RUN source ~/.profile

# Container ports for static, SSL, preview / dev and server-site rendering
EXPOSE 80 443 3000 8080

# Let supervisord start nginx & php-fpm
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
