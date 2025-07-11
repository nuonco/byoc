# Changelog

Basic changelog tracking changes merged to main. We track by release and tag moving forward. Some changes included here
precede the release cycle.

## v0.2.5

Simplify nodepool disruption budgets.

## v0.2.4

Pin the AMI to al2023@v20240807.

## v0.2.2

Update to 596 + (HOTFIX) PR 9478 to resolve empty inputs issue.

## v0.2.1

Ensure all workloads run on nodes in the private subnets.

## v0.2.0

- Temporal dynamic configs for large activities.
- New RDS Output.
- Improved README.

## v0.1.0

Introduces a new action `ctl_api_rsg_set_tag` used to ensure all runners for a given install use the
`container_image_tag` `cloud`.

## v0.0.0

Manual release created. See release for full details.

## 7404071 (#196)

Updates the `ctl_api_startup` action with optional parameters to enable debug sql logging.

## bfefc56 (#195)

Introduces a new action `ctl_api_add_support_users` to add nuon support users to an org.

## e948165 (#182)

Fix the temporal init db script in the `temporal_init_db` component to use the correct visiblity database schema.

## 89f8413 (#167)

Refactor temporal db initialization for improved visibility.
