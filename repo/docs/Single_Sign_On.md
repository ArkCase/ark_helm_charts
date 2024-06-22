# Single Sign On (SSO) Integration for [ArkCase](https://www.arkcase.com/)

## Table of Contents

- [Introduction](#introduction) 
- [OpenID Connect](#oidc) 
- [SAML](#saml)

## <a name="introduction"></a>Introduction

This documetn describes how to enable and configure Single Sign-On (*SSO*) functionality for ArkCase using these Helm charts. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

ArkCase supports SSO functionality via either [OpenID Connect](https://openid.net/developers/how-connect-works/) or [Security Assertion Markup Language](https://en.wikipedia.org/wiki/Security_Assertion_Markup_Language). Currently, the two are mutually exclusive and you can enable one or the other, but not both simultaneously. You can also choose to not enable either of them and continue using the default authentication model.

In this document *OpenID Connect* will be abbreviated as *OIDC*, and *Security Assertion Markup Language* as *SAML*.

## <a name="oidc"></a>OpenID Connect

### Configuration

Supply a map as below.

```yaml
global:
  sso:
    # Optional - defaults to "true" if not provided
    enabled: true
    # Optional - is only needed if the "saml" section is also provided
    protocol: "oidc"
    oidc:
      arkcase:
        # Optional - defaults to "true" if not provided
        enabled: true
        registrationId: "id"
        redirectUri: "https://localhost:8443/arkcase/login/oauth2/code/cognito"
        clientId: "******"
        clientSecret: "******"
        authorizationUri: "...."
        tokenUri: "...."
        jwkSetUri: "...."
        usernameAttribute: "email"
        userInfoUri: "...."
        scope: "email,openid"
        responseType: "code"
        responseMode: "form_post"
```

The keys in the `global.sso.oidc` map indicate client identifiers as they will be displayed in the software for selecting the SSO provider. These _clients_ can be enabled or disabled by adding an `enabled` flag with a value of either `true` or `false`. If the `enabled` flag is not present, the client is assumed to be enabled.

The values for `clientId`, `clientSecret`, `authorizationUri`, `tokenUri`, `jwkSetUri`, and `userInfoUri` come from your OIDC provider. Some of these will come from their well-known metadata URL. Your identity provider administrator must provide you with these values for OIDC SSO to succeed. The `scope`, `responseType`, and `responseMode` values shown above work in most situations, but can be changed as circumstances demand for particular OIDC services or customer requirements.

There are also two modes of operation for OIDC:

- _*Legacy mode*_ is required for versions of ArkCase prior to `2024.01.01` (i.e. `2023.xx.xx` and older). This mode will be activated when the list of computed clients contains a single enabled entry named either `arkcase` or `legacy`. In this mode of operation the value for `redirectUri` will be computed as `${global.conf.baseUrl}/login/oauth2/code/${registrationId}`, and any manually-provided value will be ignored.

- _*Modern mode*_ is required for versions of ArkCase equal to or greater than `2024.01.01`. This mode will be activated when the list of computed clients contains more than one enabled client, or the single client's name is neither `arkcase` nor `legacy` (e.g. you can use the name `default`)

If the list of clients contains no enabled clients, but OIDC configuration is enabled overall, this will result in a rendering error due to incomplete or inconsistent configuration.

This document will be updated with any changes relevant to _*Modern mode*_. These versions of ArkCase are in a state of constant development, so changes should be expected frequently.

### User Administration

For ArkCase application users, the ArkCase directory needs a user entry for every OIDC user; this is how ArkCase knows which privileges each user has.  You must pre-populate the ArkCase directory with the users, which your customer will provide. The user password doesn't matter, since the OIDC identity provider performs the authentication.  The user entries in the ArkCase directory must have the same email as the real users, and must be in the appropriate ArkCase groups so they get the right privileges when they login.   

For FOIA portal users, the work described above is not needed.  Every FOIA portal user gets the same privileges, and ArkCase will add each one to the portal directory as they register their accounts at the identity provider.

## <a name="saml"></a>Security Assertion Markup Language

### Configuration

Supply a map as below.

```yaml
global:
  sso:
    # Optional - defaults to "true" if not provided
    enabled: true
    # Optional - is only needed if the "oidc" section is also provided
    protocol: "saml"
    saml:
      entityId: "..."
      identityProviderUrl: "..."
```

The `entityId` value identifies this ArkCase deployment to the identity provider.  You and the identity provider administrator must agree on this value (similar to the OIDC's `clientId`).  The `identityProviderUrl` is the URL for the SAML metadata from your identity provider, and they must provide you with this value.

You may have to provide the ArkCase SAML metadata URL to your identity provider. In this case, the ArkCase SAML metadata URL will use the form: `${global.conf.baseUrl}/saml/metadata`.

## User Administration

For ArkCase application users, the ArkCase directory needs a user entry for every SAML user; this is how ArkCase knows which privileges each user has.  You must pre-populate the ArkCase directory with the users, which your customer will provide. The user password doesn't matter, since the SAML identity provider performs the authentication.  The user entries in the ArkCase directory must have the same user id as the real users, and must be in the appropriate ArkCase groups so they get the right privileges when they login.   

In some situations the identity provider may not be able to provide the ArkCase user id; for example, some ArkCase sites use an ArkCase-specific user prefix, so that the user "Tom Jones" may have a user id like "334.tom.jones".  If this is the case, you must work with your identity provider claims mapping feature, so as to transform the incoming user id into the ArkCase user id.  

ArkCase does not support SAML authentication for FOIA portal users.
