FROM golang:1.18.1 as builder

ENV PORT 8080
ENV MESSAGE Hello World

WORKDIR /go/src/app

COPY . .

RUN go mod init

RUN uname -a
RUN echo "Bulding binary for $TARGETOS on $TARGETARCH"
RUN go build -o envspitter .

FROM ubuntu:22.10 

COPY --from=builder /go/src/app/envspitter /app/

ENTRYPOINT ["/app/envspitter"]
