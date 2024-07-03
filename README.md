# AWS ECS Service - Terraform Module

This is a Terraform module that creates an ECS (Elastic Container Service) service in AWS (Amazon Web Services). The module takes various inputs, such as the name and environment of the service, the cluster and subnets to use, and the container definitions. The container definitions include details such as the Docker image to use, the port mappings, and the desired count of containers. The module can also mount EFS volumes in the containers. Overall, this module simplifies the process of setting up an ECS service in AWS.

## How to use this module

Check out the [examples](examples/) directory for different ways to use this module.
