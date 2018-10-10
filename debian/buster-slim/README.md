# Supported tags and respective `Dockerfile` links

-	[`latest` (*/debian/stretch-slim/Dockerfile*)](https://github.com/wilkesystems/docker-nginx/blob/master/debian/stretch-slim/Dockerfile)

----------------

![Nginx](https://github.com/wilkesystems/docker-nginx/raw/master/docs/logo.png)

# Nginx Extras on Debian Stretch
This nginx image contains almost all nginx nice modules using `nginx-extras` package.

----------------

# Get Image
[Docker hub](https://hub.docker.com/r/wilkesystems/nginx)

```bash
docker pull wilkesystems/nginx
```

----------------

# How to use this image

```bash
$ docker run -d -p 80:80 -p 443:443 wilkesystems/nginx
```

----------------

# Environment

| Variable                            | Function                                                          |
|-------------------------------------|-------------------------------------------------------------------|
| NGINX_DEFAULT_ROOT                  | Sets the default root directory                                   |
| NGINX_GZIP                          | Enables or disables gzipping of responses                         |
| NGINX_GZIP_DISABLE                  | Disables gzipping of responses                                    |
| NGINX_GZIP_VARY                     | Enables or disables inserting the Vary Accept-Encoding response   |
| NGINX_GZIP_PROXIED                  | Enables or disables gzipping of responses for proxied requests    |
| NGINX_GZIP_COMP_LEVEL               | Sets a gzip compression level of a response                       |
| NGINX_GZIP_BUFFERS                  | Sets the number and size of buffers used to compress a response   |
| NGINX_GZIP_HTTP_VERSION             | Sets the minimum HTTP version                                     |
| NGINX_GZIP_TYPES                    | Enables gzipping of responses for the specified MIME types        |
| NGINX_KEEPALIVE_TIMEOUT             | Sets a timeout during which a keep-alive client connection        |
| NGINX_MULTI_ACCEPT                  | Enables or disables multi accept                                  |
| NGINX_PID                           | Defines a file that will store the process ID of the main process |
| NGINX_UID                           | Sets the User ID of the worker processes                          |
| NGINX_GID                           | Sets the Group ID of the worker processes                         |
| NGINX_SENDFILE                      | Enables or disables the use of sendfile                           |
| NGINX_SERVER_NAME_IN_REDIRECT       | Enables or disables the use of the primary server  name           |
| NGINX_SERVER_NAMES_HASH_BUCKET_SIZE | Sets the bucket size for the server                               |
| NGINX_SERVER_NAMES_HASH_MAX_SIZE    | Sets the server names hash max size                               |
| NGINX_SERVER_TOKENS                 | Enables or disables emitting nginx version                        |
| NGINX_SSL_PREFER_SERVER_CIPHERS     | Specifies that server ciphers should be preferred                 |
| NGINX_SSL_PROTOCOLS                 | Enables the specified protocols                                   |
| NGINX_SSL_CERTIFICATE               | Sets the ssl certificate                                          |
| NGINX_SSL_CERTIFICATE_KEY           | Sets the ssl certificate key                                      |
| NGINX_SSL_TRUSTED_CERTIFICATE       | Sets the ssl trusted certificate                                  |
| NGINX_SSL_CIPHERS                   | Sets the ssl ciphers                                              |
| NGINX_SSL_ECDH_CURVE                | Sets the ssl ecdh curve                                           |
| NGINX_SSL_DHPARAM                   | Sets the ssl dhparam                                              |
| NGINX_SSL_SESSION_TIMEOUT           | Sets the ssl session timeout                                      |
| NGINX_SSL_SESSION_CACHE             | Sets the ssl session cache                                        |
| NGINX_SSL_SESSION_TICKETS           | Sets the ssl session tickets                                      |
| NGINX_SSL_STAPLING                  | Sets the ssl stapling                                             |
| NGINX_SSL_STAPLING_VERIFY           | Sets the ssl stapling verify                                      |
| NGINX_RESOLVER                      | Sets the resolver                                                 |
| NGINX_RESOLVER_TIMEOUT              | Sets the resolver timeout                                         |
| NGINX_TCP_NODELAY                   | Enables or disables the use of the tcp no delay socket option     |
| NGINX_TCP_NOPUSH                    | Enables or disables the use of the tcp nopush socket option       |
| NGINX_TYPES_HASH_MAX_SIZE           | Sets the maximum size of the types hash tables                    |
| NGINX_USER                          | Defines user and group credentials used by worker processes       |
| NGINX_WORKER_CONNECTIONS            | Sets the maximum number of simultaneous worker connections        |
| NGINX_WORKER_PROCESSES              | Defines the number of worker processes                            |

----------------

# Auto Builds
New images are automatically built by each new library/debian push.

----------------

# Package: nginx-extras
Package: [nginx-extras](https://packages.debian.org/stretch/nginx-extras)

Nginx ("engine X") is a high-performance web and reverse proxy server created by Igor Sysoev. It can be used both as a standalone web server and as a proxy to reduce the load on back-end HTTP or mail servers.

This package provides a version of nginx with the standard modules, plus extra features and modules such as the Perl module, which allows the addition of Perl in configuration files.

STANDARD HTTP MODULES: Core, Access, Auth Basic, Auto Index, Browser, Empty GIF, FastCGI, Geo, Limit Connections, Limit Requests, Map, Memcached, Proxy, Referer, Rewrite, SCGI, Split Clients, UWSGI.

OPTIONAL HTTP MODULES: Addition, Auth Request, Charset, WebDAV, FLV, GeoIP, Gunzip, Gzip, Gzip Precompression, Headers, HTTP/2, Image Filter, Index, Log, MP4, Embedded Perl, Random Index, Real IP, Slice, Secure Link, SSI, SSL, Stream, Stub Status, Substitution, Thread Pool, Upstream, User ID, XSLT.

MAIL MODULES: Mail Core, Auth HTTP, Proxy, SSL, IMAP, POP3, SMTP.

THIRD PARTY MODULES: Auth PAM, Cache Purge, DAV Ext, Echo, Fancy Index, Headers More, Embedded Lua, HTTP Substitutions, Nchan, Upload Progress, Upstream Fair Queue.
