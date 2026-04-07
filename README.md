# Nuon BYOC



Nuon BYOC is an app config where Nuon deploys the Nuon control and data plane into your AWS cloud account.

You must be a licensed Nuon customer to use Nuon BYOC. [Contact sales](https://nuon.co/contact-sales) and share your use case and requirements.

Alternatively, if you are interested in using Nuon Cloud, our SaaS service, [sign up here](https:aap.nuon.co).

## Use Case

Nuon BYOC is for software vendors who want the security of Nuon's control plane running in their AWS account but with the convenience of Nuon managing their Nuon deployment. Vendors can cut off Nuon's access by scaling down the ASG with the [Nuon runner](https://docs.nuon.co/concepts/runners), an agent that communicates with Nuon Cloud to install and manage the vendor's instance of Nuon. Vendors can scale up the ASG to grant access to Nuon to perform upgrades or troubleshoot.

## Sandbox

This application uses the [`aws-eks-karpenter-sandbox`](https://github.com/nuonco/aws-eks-karpenter-sandbox). Sandboxes are Terraform that install your app’s underlying infrastructure like AWS EKS. Learn more about [sandboxes](https://docs.nuon.co/concepts/sandboxes).

## Documentation

Check out the [Nuon BYOC documentation](https://docs.nuon.co/guides/byoc).
