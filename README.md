# podrunnersh
podrunner.sh - wrapper around `podman run` for common integration cases

Podrunner.sh makes `podman run` shell aliases for custom containers more
manageable. When running custom container images on
[Silverblue](https://silverblue.fedoraproject.org/) some common cases like
having a transparent home directory, exposing ssh-agent, etc. often return.
This wrapper script provides convenient options to start containers with these
cases.

## Usage

```
Usage: podrunner.sh [OPTION...] -- [PODMAN RUN OPTIONS...]

  --homedir       Make homedir transparent inside the container.
  --libvirtd      Expose libvirtd socket inside the container.
  --map-user      Map host user to user with same uid inside the container.
  --ssh-agent     Expose ssh-agent inside the container.
  --utf8          Enable basic UTF8 support in most containers.
  --x11           Expose X11 socket inside the container.
```

## Examples

Fedora container bash prompt with a transparent homedir and X11:

```sh
podrunner.sh --homedir --x11 -- \
             --rm -it registry.fedoraproject.org/fedora:latest /bin/bash
```

Debian container with image with the local user mapped inside the container:

```sh
cat - > Dockerfile <<"EOF"
FROM registry.hub.docker.com/library/debian:buster
ARG user_name=foo
ENV CONTAINER_USER_NAME=$user_name
ARG user_id=1000
ENV CONTAINER_USER_ID=$user_id
ARG user_home=/home/$user_name
ENV CONTAINER_USER_HOME=$user_home
RUN /usr/sbin/useradd -u "$CONTAINER_USER_ID" \
                      -U -d "$CONTAINER_USER_HOME" \
                      -s /bin/bash "$CONTAINER_USER_NAME"
USER $CONTAINER_USER_NAME
ENTRYPOINT ["/bin/bash"]
EOF

podman build -t localhost/debian-user:latest \
             --build-arg "user_name=${USER}" \
             --build-arg "user_id=$(id -ur)" \
             --build-arg "user_home=${HOME}" .

podrunner.sh --map-user --homedir -- \
             --rm -it localhost/debian-user:latest
```
