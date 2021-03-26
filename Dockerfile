FROM node:14-slim

EXPOSE 8000
# MAINTAINER Jean-Christophe Hoelt <hoelt@fovea.cc>

# Install redis-cli and netcat
# (those are used by push-worker.sh to monitor the queue of messages)
RUN apt-get update && apt-get install -y \
    redis-tools \
    netcat-traditional \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Create 'app' user
RUN useradd app -d /home/app

# Install NPM packages
COPY certs/AAACertificateServices.crt /etc/ssl/certs/
COPY tsconfig.json /home/app/code/tsconfig.json
COPY package.json /home/app/code/package.json
# COPY package-lock.json /home/app/code/package-lock.json
WORKDIR /home/app/code
RUN npm install

# Copy app source files
COPY config.ts index.ts push-worker.sh /home/app/code/
COPY index.ts /home/app/code/index.ts
COPY types /home/app/code/types
COPY tests /home/app/code/tests
COPY src /home/app/code/src
RUN npm run build
RUN chown -R app /home/app

USER app
CMD npm start

ENV NODE_ENV=production
