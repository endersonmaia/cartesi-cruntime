# syntax=docker.io/docker/dockerfile:1
# build stage: includes resources necessary for installing dependencies

# Here the image's platform does not necessarily have to be riscv64.
# If any needed dependencies rely on native binaries, you must use
# a riscv64 image such as cartesi/node:20-jammy for the build stage,
# to ensure that the appropriate binaries will be generated.
FROM alpine:3.22 AS build-stage

WORKDIR /opt/cartesi/dapp
RUN apk add --no-cache nodejs npm yarn
COPY jsdapp .
RUN yarn install && yarn build

# runtime stage: produces final image that will be executed

# Here the image's platform MUST be linux/riscv64.
# Give preference to small base images, which lead to better start-up
# performance when loading the Cartesi Machine.
FROM alpine:3.22
ENV PATH="/opt/cartesi/bin:${PATH}"

RUN apk add --no-cache ca-certificates nodejs
WORKDIR /opt/cartesi/dapp
COPY --from=build-stage /opt/cartesi/dapp/dist .
CMD ["node", "index.js"]
