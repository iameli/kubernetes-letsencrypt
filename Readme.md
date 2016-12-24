
# deprecated

I've moved over to [kube-lego](https://github.com/jetstack/kube-lego) for my cert retrieval, so I guess that means this project is unmaintained. They're integrated with a couple ingress controllers and autogenerate certs based on ingresses and other cool stuff like that.

This project is still maybe useful if you're on a quest to string some bash scripts together and get TLS certs for whatever reason.

# kubernetes-letsencrypt

This project aims to be a painless way to get letsencrypt SSL certificates into your Kubernetes cluster.

## Usage

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

1. Configure your load balancer to use those newly-mounted certificates. An nginx config might look something like
   this:

    ```
      ssl_certificate /keys/certchain.pem;
      ssl_certificate_key /keys/key.pem;
    ```

1. You're done! You should probably set up something somewhere to regenerate your certificates monthly or so.

## Secret format

When kubernetes-letsencrypt generates a key and certificate, it saves it in a secret. By default, this secret is named
`letsencrypt-ssl`. This secret contains four files:

  * `key.pem` - Contains the newly generated secret key.
  * `cert.pem` - Contains the newly generated certificate, signed by Let's Encrypt. (This is what Apache uses.)
  * `chain.pem` - Contains the certificate vendor chain necessary to validate the certificate.
  * `certchain.pem` - Concatins a concatenation of cert.pem and chain.pem. (This is what nginx uses.)
