# docker-images

Personal Docker images. Each subdirectory is a self-contained image.

## Layout

```
<image-name>/
  Dockerfile
  README.md   # image-specific notes (optional)
```

## Build

```sh
cd <image-name>
docker build -t yousiki/<image-name> .
```
