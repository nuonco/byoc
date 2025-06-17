We’re going to be doing your initial Nuon platform installation in your cloud, and there’s some information we’ll need to collect and pre-requisites we’ll need to have set up before we can deploy.

1. **Region** - Which region would you like to deploy to?
2. **Public domain** - Decide on a public domain for the install. That is, if you were to log into the nuon platform, you’d navigate to https://app.<thedomainthatyouchoose.com>.  After the setup is complete, you’ll be setting that domain’s NS record to a route53 within the installation.
    - Subdomains are fine, eg. byoc.yourdomain.com
3. **Github App** - We require you to create a github app that has read only permission scopes to the repositories that you wish to pull code from. There will be instructions attached to this email that detail this process, but you’ll need the chosen domain from above.
4. **Auth0** setup- We require you to create an auth0 tenant to serve as an auth provider. We currently only support Google Workspace as the federated IDP at the moment, but if you have additional needs, please let us know. There is a document attached to this email that has detailed set up instructions, as well as a [terraform module](https://github.com/nuonco/byoc-auth0) to make this easier for you.

In summary, you will need to collect:

- And provide to us:
    - Region : e.g. us-east-1
    - Public Domain : e.g. “foo.bar.com”
    - Github:
        - Application name : e.g. “BYOC- Github App”
        - Github Application ID (e.g. 12345)
        - Github Client ID  (e.g Iv23liaPJvV5BB3vl3u7 )
    - Auth0:
        - Single Page App - Client ID ( e.g. D4J7AP2GfjYcXelIkfX1iOx42EYGdYJd
        - Native App - Client ID (e.g. fnPwEwkjbzr8clsSRSbssR2DNcNWvDBW)
- Keep on hand but do not provide to us (as they are your secrets)
    - Github :
        - Generated PEM key, base 64 encoded. This is created by clicking on the “Generate a private key” button near the bottom of the screen.
    - Auth0 :
        - Single Page App : Secret Key



---
### Github
**Configure Github App**

Create a github app so BYOC Nuon can clone code for components from private repos. Configure it thusly:

- Github app name: (pick any name)
- Homepage URL: [https://app.{{](https://app.{{/) $public_domain }}
- Post Installation:
    - Setup URL: [https://app.{{](https://app.{{/) $public_domain }}/connect
    - Redirect on Update: check
- Webhook:
    - Webhook: un-check
- Permissions:
    - Contents: Read-only
    - Where can this GitHub app be installed?: Only on this account. (unless you have repos you need to access in other
    GitHub accounts.)

Once the app has been created, scroll to the bottom and generate a PEM key. You will need to provide this as a secret
later.

---

### Auth0
Note: We have a [terraform module](https://github.com/nuonco/byoc-auth0) to create these elements for you.

**Configure Auth0**

Nuon uses Auth0 for authentication. If you do not already have an Auth0 tenant, create one. In this tenant you must
configure:

- An API
- A Single Page Application (for the CTL API to use)
- A Native Application (for the Dashboard to use)

**API**

The value of "Identifier" must be `https://api.<YOURDOMAINHERE>` This will be used the audience identifier and must
match the API URL. It cannot be changed after creation, so make sure this accurate.

| Setting | Value | Section |
| --- | --- | --- |
| Name | API Gateway | In creation modal. |
| Identifier | api.<YOURDOMAINHERE> | In creation modal. |
| Maximum Access Token Lifetime | 2592000 | Access Token Setting |
| Implicit/Hybrid Flow Access Token Lifetime | 86400 | Access Token Setting |
| Allow Skipping User Consent | true | Access Settings |

**Single Page Application**

| Setting | Value | Section |
| --- | --- | --- |
| Name | Nuon App | In creation modal. |
| Logout URL |  | Application URIs |
| Application Login URI |  | Application URIs |
| Allowed Callback URLs | [https://app.](https://app.{{/)<YOURDOMAINHERE>/api/auth/callback | Application URIs |
| Allowed Logout URLs | [https://app.](https://app.{{/)<YOURDOMAINHERE> | Application URIs |
| Allowed Web Origins | [https://app](https://app.{{/).<YOURDOMAINHERE> | Application URIs |
| Alow Cross-Origin Authentication | true | Cross-Origing Authentication |
| Maxmium Refresh Token Lifetime | 31557600 | Refresh Token Expiration |
| Allow Refresh Token Rotation | true | Refresh Token Rotation |
| Rotation Overlap Period | 0 | Refresh Token Rotation |

**Native Applicaton**

| Setting | Value | Section |
| --- | --- | --- |
| Name | Nuon CTL API  | In creation modal. |
| Description | For BYOC Nuon Install  | In creation modal. |
| Allow Cross-Origin Authentication | true | Cross-Origin Authentication |
| Device Code | checked | Advanced Settings > Grant Types |

**Update Inputs**

Once the dependencies have been configured, you can update your install inputs. This will trigger a workflow that's
going to fail because the install hasn't been provisioned yet. This won't cause any problems, and you can ignore it.
