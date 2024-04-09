# Get Docker Images
You can take two ways to prepare the docker images for `PlanFuzzer`: download the pre-built images from Docker Hub, or build the image from source Dockerfile.

## Download Pre-built Docker Image
``` shell
sudo docker pull planfuzzer/planfuzzer:1.0
sudo docker tag planfuzzer/planfuzzer:1.0 planfuzzer:latest
```

## Build Docker Locally
- Docker for testing PostgreSQL (may take 1 hour or longer)
``` shell
sudo docker build -t planfuzzer -f scripts/Dockerfile .
sudo docker run -it planfuzzer
```
- NOTE: since `COPY` in `Dockerfile` does not support upper-level directory, `docker build` must in `PlanFuzzer` root directory.

## Troubleshooting (Build process fails or gets stuck)
- clean the Docker environment via `sudo docker system prune --all` and rebuild the image
- Modify the environment variable in the `Dockerfile` and try to manually build the failed part
