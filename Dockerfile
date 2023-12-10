# build front-end
FROM node AS web_image

RUN npm install pnpm -g

WORKDIR /build

COPY ./package.json /build

COPY ./pnpm-lock.yaml /build

RUN pnpm install

COPY . /build

RUN pnpm run build

# build backend
FROM golang:1.21-alpine as server_image

WORKDIR /build

COPY ./service .

RUN apk add --no-cache bash curl gcc git go musl-dev

RUN echo "Building backend..." \
    && go env -w GO111MODULE=on \
    # && go env -w GOPROXY=https://goproxy.cn,direct \
    && export PATH=$PATH:/go/bin \
    && echo "Building backend1" \
    && go install -a -v github.com/go-bindata/go-bindata/...@latest \
    && echo "Building backend3" \
    && go install -a -v github.com/elazarl/go-bindata-assetfs/...@latest \
    && echo "Building backend4" \
    && go-bindata-assetfs -o=assets/bindata.go -pkg=assets assets/... \
    && echo "Building backend5" \
    && go build -o sun-panel --ldflags="-X sun-panel/global.RUNCODE=release -X sun-panel/global.ISDOCKER=docker" main.go


# run_image
FROM alpine

WORKDIR /app

COPY --from=web_image /build/dist /app/web

COPY --from=server_image /build/sun-panel /app/sun-panel

RUN apk add --no-cache bash ca-certificates su-exec tzdata \
    && chmod +x ./sun-panel \
    && ./sun-panel -config

CMD ./sun-panel
