# Nuon BYOC

Nuon BYOC is an app config where Nuon deploys the Nuon control and data plane into your AWS or GCP cloud account.

You must be a licensed Nuon customer to use Nuon BYOC. [Contact sales](https://nuon.co/contact-sales) and share your use case and requirements.

Alternatively, if you are interested in using Nuon Cloud, our SaaS service, [sign up here](https:aap.nuon.co).

## Use Case

Nuon BYOC is for software vendors who want the security of Nuon's control plane running in their AWS or GCP account but with the convenience of Nuon managing their Nuon deployment. Vendors can cut off Nuon's access by scaling down the ASG (AWS) or managed instance group (GCP) running the [Nuon runner](https://docs.nuon.co/concepts/runners), an agent that communicates with Nuon Cloud to install and manage the vendor's instance of Nuon. Vendors can scale it back up to grant access to Nuon to perform upgrades or troubleshoot.

## Apps

This repo contains an app config per cloud:

- [`byoc-nuon`](./byoc-nuon) — deploys Nuon into your AWS account on EKS.
- [`byoc-nuon-gcp`](./byoc-nuon-gcp) — deploys Nuon into your GCP project on GKE.

## Sandboxes

Sandboxes are Terraform that install your app’s underlying infrastructure like AWS EKS or GCP GKE. Learn more about [sandboxes](https://docs.nuon.co/concepts/sandboxes).

- The AWS app uses the [`aws-eks-karpenter-sandbox`](https://github.com/nuonco/aws-eks-karpenter-sandbox), which provisions an EKS cluster with Karpenter for node autoscaling.
- The GCP app uses the [`gcp-gke-sandbox`](https://github.com/nuonco/gcp-gke-sandbox), which provisions a private GKE cluster.

## Documentation

Check out the [Nuon BYOC documentation](https://docs.nuon.co/guides/byoc).
