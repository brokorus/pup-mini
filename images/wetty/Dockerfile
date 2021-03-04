FROM node:current-alpine as builder
RUN apk add -U build-base python
WORKDIR /usr/src/app
COPY . /usr/src/app
RUN yarn && \
    yarn build && \
    yarn install --production --ignore-scripts --prefer-offline

FROM node:current-alpine
WORKDIR /usr/src/app
ENV NODE_ENV=production
EXPOSE 3000
COPY --from=builder /usr/src/app/build /usr/src/app/build
COPY --from=builder /usr/src/app/node_modules /usr/src/app/node_modules
COPY package.json /usr/src/app
RUN apk add -U openssl git sudo curl bash openssh-client sshpass && \
    adduser demo -D && \
    adduser demo wheel && \
    passwd demo -d demo && \
    echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel && \
    mkdir ~/.ssh

RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" -o /bin/kubectl && \
    chmod 700 /bin/kubectl && \
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

COPY motd /etc/motd

ENTRYPOINT [ "yarn" , "docker-entrypoint"]
