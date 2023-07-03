USER=$(shell id -u):$(shell id -g)
PWD=$(shell pwd)

pre-commit:
	docker run -e "USERID=$(USER)" -v $(PWD):/lint -w /lint ghcr.io/antonbabenko/pre-commit-terraform:latest run -a

pre-commit-cli:
	docker run -e "USERID=$(USER)" -v $(PWD):/lint -w /lint --entrypoint sh -it ghcr.io/antonbabenko/pre-commit-terraform:latest