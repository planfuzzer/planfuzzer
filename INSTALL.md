# Get Docker Images

## Download Pre-built Docker Image
TODO


## Build Docker Locally
- Docker for testing PostgreSQL (may take 1 hour or longer)
``` shell
cd srcipts
docker build -t planfuzzer .
docker run -it planfuzzer
```

## Troubleshooting (Build process fails or gets stuck)
- clean the Docker environment via `sudo docker system prune --all` and rebuild the image
- Comment out the failed later parts of the `Dockerfile` and try building manually
