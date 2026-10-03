FROM alpine:3.19

# Install ca-certificates, wget, and unzip
RUN apk add --no-cache ca-certificates wget unzip

WORKDIR /pb

# Download and install PocketBase v0.25.9 Linux AMD64
RUN wget https://github.com/pocketbase/pocketbase/releases/download/v0.25.9/pocketbase_0.25.9_linux_amd64.zip \
    && unzip pocketbase_0.25.9_linux_amd64.zip \
    && rm pocketbase_0.25.9_linux_amd64.zip \
    && chmod +x /pb/pocketbase

# Copy existing data, migrations, and public files
COPY pb_data /pb/pb_data
COPY pb_migrations /pb/pb_migrations
COPY pb_public /pb/pb_public

EXPOSE 8090

CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090"]
