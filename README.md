
- [About](#about)
  - [Stack overview](#stack-overview)
  - [Demo services](#demo-services)
    - [Traefik](#traefik)
    - [Services](#services)
- [Deployment](#deployment)
  - [Part 1 - Terraform](#part-1---terraform)
    - [AWS Docker Host Template (Terraform)](#aws-docker-host-template-terraform)
    - [Prereqs](#prereqs)
    - [Quickstart](#quickstart)
    - [Notes](#notes)
    - [Cleanup](#cleanup)
    - [Security](#security)
  - [Part 2 - Prepare server](#part-2---prepare-server)
      - [Configure backups via Restic](#configure-backups-via-restic)
      - [Start services](#start-services)
- [Maintenance](#maintenance)
  - [Adding a service](#adding-a-service)
  - [Removing a service](#removing-a-service)
  - [Patching services](#patching-services)
    - [All services](#all-services)
    - [A single service](#a-single-service)
  - [Backups](#backups)
    - [Perform a backup](#perform-a-backup)
    - [Restore a Backup](#restore-a-backup)
  - [Notes](#notes-1)
  - [Redis](#redis)
    - [docker-compose.yml](#docker-composeyml)



# About

This repository demonstrates how you can leverage Docker, Traefik, Terraform and Restic, to deploy multiple services to a single server in a way that is vertically scalable, and simple to secure, deploy, update, backup, restore and maintain. The best part… adding new services is as easy as adding a few files and modifying a couple of lines of code.

I have been deploying and maintaining self-hosted services for enterprise customers since 2009. In 2025, this stack - and similar stacks - are what I use to reduce deployment time from days to minutes.

**Important caveat**: This codebase is not appropriate for services that receive large amounts of traffic, however, for services that receive a relatively small / reasonable amount of traffic - which will be most services you deploy - it works well and saves considerable hosting costs, which makes all parties happy. That said, Traefik can be configured for large amounts of traffic by using Docker Swarm or Kubernetes.

**You are most welcome to use this code in your commercial projects, all that I ask in return is that you credit my work by providing a link back to this repository.**

Thank you & Enjoy!

## Stack overview

| Tool | About | Role |
| -------- | -------- | -------- |
| Terraform | Terraform is an infrastructure as code tool that lets you build, change, and version infrastructure safely and efficiently, all within your codebase. This includes low-level components like compute instances, storage, and networking; and high-level components like DNS entries and SaaS features. | Terraform spins up a single EC2 instance with all settings configured, mapped to the correct domain and sub-domains, ready for your containers to be deployed to. |
| Docker | An open-source platform that enables developers to build, deploy, run, update, and manage applications within lightweight, isolated environments called containers. | Each service is a docker-compose file containing the service information plus instructions for Traefik. Each Docker compose file spins up the service in a container on the server created by Terraform, ready for Traefik to discover. Docker stores all data in docker volumes. Applications can by updated with a single script. |
| Traefik | Traefik is a leading modern open source reverse proxy and ingress controller that makes deploying services and APIs easy. Traefik integrates with your existing infrastructure components, configuring itself automatically and dynamically. Traefik provides built-in automatic certificate management, load balancing, a web application firewall, automatic container discovery and port mapping and more… all with nearly zero configuration required. | Traefik automatically discovers all docker containers on the server, provisions all SSL certificates, maps them to the correct urls, and directs all traffic coming in and out of the server to the correct containers via its highly efficient built-in load-balancer. |
| Restic | Restic is an open source modern backup program that can back up your files. Supports Linux, BSD, Mac and Windows. Backup to many different storage types, including self-hosted and online services. A single executable that you can run without a server or complex setup. Only transfers the parts that actually changed in the files you back up. Carefully uses cryptography in every part of the process. Built-in verification, enabling you to make sure that your files can be restored when needed. | Automatically backs up all docker volumes, which can be restored by running a simple script with minimal down time. 


## Demo services

To demonstrate multiple services, I've included the following two services:

- **n8n** - workflow automation
- **redis** - an Redis instance that can be used by automations on n8n 

We also have a third service, which is Traefik itself. 

- **traefik** - a modern HTTP reverse proxy and load balancer that makes deploying microservices easy.

### Traefik
- A single instance of Traefik routes and manages traffic for all services. It runs on a docker network named `my_network`

### Services
- Each service has it's own folder, with a dedicated `docker-compose.yml` and `.env`


 
# Deployment

## Part 1 - Terraform

It's useful to know that you can copy the Traefik folder, along with the folders of each service, onto a server and deploy them manually if you wish.

However, in this repository, we'll make use of Terraform to deploy to AWS.

### AWS Docker Host Template (Terraform)

You will find all the files needed to deploy via Terraform in the project's root directory. Here I've made a reusable Terraform template that provisions:
- An Ubuntu 22.04 EC2 host with Docker + compose
- Optional Elastic IP
- Parameterized Security Group (SSH + app ports)
- SSM access by default (no SSH key required)
- Optional S3 backup bucket with IAM access policy
- Optional Route53 hosted zone and A records (root + subdomains)

### Prereqs
- Terraform >= 1.6
- AWS credentials configured (`aws configure`, env vars, or a role to assume)
- (Optional) Existing Route53 Hosted Zone if you don't want to create a new one

### Quickstart

1. Clone the template and copy the example variables:

```bash
cp terraform_config_examples/prod.auto.tfvars.example prod.auto.tfvars
```

2. Edit `prod.auto.tfvars` to suit your environment.

3. (Optional) Configure remote backend in `versions.tf` (S3 or HTTP) and run `terraform init -migrate-state` if moving from local.

4. Init/plan/apply:

```bash
terraform init
terraform plan -var-file="prod.auto.tfvars"
terraform apply -var-file="prod.auto.tfvars"
```

5. Outputs will include the instance ID, public IP, backup bucket name, and DNS info if enabled.

### Notes

- SSH: Disabled unless you provide ssh_allowed_cidrs. Use AWS Systems Manager Session Manager instead.
- S3 bucket: Uses a random 6-char numeric suffix for uniqueness.
- DNS:
  - Set `manage_zone = true` and `root_domain = "example.com"` to create a new public hosted zone.
  - Or set `manage_zone = false`, `hosted_zone_id = "Z###########"`, and `root_domain = "example.com"` to add records to an existing zone.
  - Set `create_dns_records = true` to actually create A records.

### Cleanup

```
terraform destroy -var-file="prod.auto.tfvars"
```

### Security
- Security Group rules are minimized. Limit SSH to your IP, or leave it disabled for SSM-only access.
- EBS volumes are encrypted; S3 bucket has public access blocked and SSE-S3 enabled.


## Part 2 - Prepare server

1. log back into the server with SSM or SSH

2. Set environment variables for each service

  Each service has it's own folder. 

  Where services require an a `.env` file, examples have been provided as `.env_example` files. 

  For each one:

   - make a copy of it in the same directory, 
   - rename as `.env`
   - fill in the environment variable values (refer to comments in the `.env_example` for details)   

3. Create required Docker volumes (one-time):

```
docker volume create n8n-data
docker volume create n8n-local-files
docker volume create redis_n8n_data
```
#### Configure backups via Restic 

1. create a password for encryption: 

  - create password file: `apg -a 1 -m 32 -n 1 -M NCL > restic_password.txt`
  (or copy an existing file to the backup directory. NOTE: The file should be named `restic_password.txt` and be stored in the root directory of the repository)

2. Using the encryption password, set the environment variables below:

```sh
unset HISTFILE
export RESTIC_REPOSITORY="s3:s3.amazonaws.com/<your-bucket>/restic"
export RESTIC_PASSWORD="$(cat ./restic_password.txt)"
```
Credentials are provided automatically by the EC2 instance profile (no manual keys needed).

3. Initialize:
```
restic init
```

#### Start services

1.   Pull container images for services (migration)
  
```sh
bash pull_images.sh
```

2. create `my_network` docker network 
  
`docker network create my_network`

3.  Start services
 
```sh
bash start_and_update.sh
```
Allow a few minutes for Traefik to provision certificates.



# Maintenance


## Adding a service

1. Create a new folder in repo root.
2. Add its `docker-compose.yml`, include Traefik labels, set network to: `my_network`.
3. Add folder path to `start_and_update.sh`.
4. Add sub-domain entry to `prod.auto.tfvars`.
5. Run `terraform apply`.

Need inspiration for new services to deploy? Visit [Awesome Docker Compose](https://awesome-docker-compose.com/)

## Removing a service

1. `docker compose -f "./<service>/docker-compose.yml" down`
2. Delete the folder.
3. Delete service volumes (`docker volume rm ...`).
4. Remove from `start_and_update.sh`.
5. Remove subdomain from `prod.auto.tfvars`.
6. Run `terraform apply`.


## Patching services

### All services

```sh
sudo chmod +X start_and_update.sh
bash start_and_update.sh
```
This pulls latest images and redeploys.

### A single service

To update a single service, pass it's folder path to docker compose. for example, to update the service `n8n`, run:

```sh
folder_path=n8n
docker-compose -f "./$folder_path/docker-compose.yml" pull
docker-compose -f "./$folder_path/docker-compose.yml" down
docker-compose -f "./$folder_path/docker-compose.yml" up -d
```

## Backups

All Docker volumes are tarballed then backed up with Restic to S3.

See `s3.tf` for bucket configuration.

### Perform a backup
1. Run the backup script to tarball all Docker volumes:
```sh
chmod +x helper_scripts/backup/backup.sh
bash helper_scripts/backup/backup.sh

```
This creates `backup_volumes/*.tgz` files, then runs `restic backup backup_volumes`.

2. Verify snapshots:
```
restic snapshots
```


### Restore a Backup
1. Restore the latest snapshot into the local backup_volumes directory:

```sh
restic restore latest --target backup_volumes
```
2. Rehydrate the Docker volumes from tarballs:
```
chmod +x helper_scripts/backup/restore.sh
bash helper_scripts/backup/restore.sh
```

## Notes

## Redis

To add a redis connection in n8n: 

PORT: `6379`
HOST: `redis`
URL:`redis://:PASSWORD@redis:6379`


### docker-compose.yml

`"--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"` provides the option to specify the certificate authority server URL for Let's Encrypt. The URL points to the staging environment of Let's Encrypt for testing and development purposes. Leave this commmented out in production.

`"--log.level=DEBUG"` can be helpful for troubleshooting and debugging purposes, but should commented out in production to avoid excessive Traefik logs