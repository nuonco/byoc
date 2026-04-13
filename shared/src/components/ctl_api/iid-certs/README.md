# AWS IID Certificates (Config Overlay)

Place region-specific PEM files here (e.g., `us-west-2.pem`) to
override the certificates embedded in the ctl-api binary.

These are mounted into pods at `/etc/nuon/iid-certs` via a ConfigMap.

Source: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/regions-certs.html

Use the RSA-2048 certificates.
