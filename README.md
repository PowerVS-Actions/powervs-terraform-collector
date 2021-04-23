Collects data from PowerVS services running at IBM Cloud


# Build

```
    docker build -t powervs-terraform-collector .
```

# Run

Add the API keys in the file called: api_keys, one per line, using the following pattern:

```
    IBM_CLOUD_NUMBER:IBM_CLOUD_NAME,IBM_CLOUD_API_KEY
```

Then, run using the following command:

```
    docker run --rm -it -v $(pwd)/output:/terraform/output -v $(pwd)/api_keys:/terraform/api_keys powervs-terraform-collector:latest
```
