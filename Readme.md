# kubernetes-letsencrypt

This project aims to be a painless way to get letsencrypt SSL certificates into your Kubernetes cluster.

## Usage

### Setup

1. Create a letsencrypt ReplicationController and service. You can customize the ones provided in the "example"
   folder. The environment variables in the ReplicationController will determine the user parameters of your SSL
   certificate.

1. Configure your load balancer so that HTTP requests to the directory `/.well-known` go to the `letsencrypt` service.
   This process will vary depending on your cluster's load balancer.

```
server {
  listen 80;
  location /.well-known {
    proxy_pass http://letsencrypt.default.svc.cluster.local;
}
```
1. Customize `example/run.sh` with the list of domains for which you'd like to generate a certificate. Now you're
   ready to start generating certificates.

1. Execute your `run.sh` file. It will run the command to generate the certificates in the appropriate pod, and save
   the certificates into a secret called `letsencrypt-ssl`.

1. Configure your load balancer pod to mount those newly-generated secrets. Your ReplicationController might look
   something like this:

```
apiVersion: v1
kind: ReplicationController
metadata:
  name: load-balancer
spec:
  replicas: 1
  selector:
    app: load-balancer
  template:
    metadata:
      labels:
        app: load-balancer
    spec:
      volumes:
        - name: ssl
          secret:
            secretName: letsencrypt-ssl
      containers:
        - name: "load-balancer"
          image: "your-user/your-nginx"
          imagePullPolicy: Always
          volumeMounts:
            - name: ssl
              mountPath: /keys
              readOnly: true
```

1. You're done!
