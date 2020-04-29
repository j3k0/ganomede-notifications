FROM node:12-slim

EXPOSE 8000
MAINTAINER Jean-Christophe Hoelt <hoelt@fovea.cc>

# Install redis-cli and netcat
# (those are used by push-worker.sh to monitor the queue of messages)
RUN apt-get update && apt-get install -y \
    redis-tools \
    netcat-traditional \
 && rm -rf /var/lib/apt/lists/*

# Create 'app' user
RUN useradd app -d /home/app

# Install NPM packages
COPY package.json /home/app/code/package.json
WORKDIR /home/app/code
RUN npm install

# Copy app source files
COPY config.js index.js newrelic.js coffeelint.json .eslintignore .eslintrc push-worker.sh /home/app/code/
COPY index.js /home/app/code/index.js
COPY index.fix.js /home/app/code/index.fix.js
COPY tests /home/app/code/tests
COPY src /home/app/code/src
RUN chown -R app /home/app

USER app
CMD node index.js

ENV NODE_ENV=production
