# looker-gcp-auth-service

### GCP Installation Tutorial:



### Local Installation Instructions:

To install locally
```
nvm use 16
yarn install
```

To run locally
```
node index.js
```

To build Docker image locally
```
docker build -t looker-gcp-auth-service .
```

To run Docker image
```
docker run -d -p 3000:3000 --name looker-gcp-auth-service--app looker-gcp-auth-service
```