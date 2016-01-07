
all: .
	docker build -t iameli/kubernetes-letsencrypt .

push:
	docker push iameli/kubernetes-letsencrypt
