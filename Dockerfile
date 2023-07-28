FROM golang:1.20.2-alpine3.16 as build

WORKDIR /app

# Copy dependencies list
COPY go.mod go.sum ./

RUN go mod download

# Build
COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o main .

# Copy artifacts to a clean image
FROM alpine:3.16
COPY --from=build /app/main /main
ENTRYPOINT [ "/main" ]