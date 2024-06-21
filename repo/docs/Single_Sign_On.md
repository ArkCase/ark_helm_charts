# Single Sign On (SSO) Integration

- [OIDC](#oidc)

## Introduction

SSO is supported via [OIDC](https://openid.net/developers/how-connect-works/) or [SAML](https://en.wikipedia.org/wiki/Security_Assertion_Markup_Language).

## <a name="oidc"></a>OIDC

### Configuration

Supply a map as below.

```yaml
global:
  conf:
    sso:
      enabled: true
      protocol: "oidc"
      oidc:
        clients:
          arkcase:
            registrationId: "id"
            clientId: "******"
            clientSecret: "******"
            redirectUri: "https://localhost:8443/arkcase/login/oauth2/code/cognito"
            authorizationUri: "...."
            tokenUri: "...."
            jwkSetUri: "...."
            usernameAttribute: "email"
            userInfoUri: "...."
            scope: "email,openid"
            responseType: "code"
            responseMode: "form_post"
            usersDirectory: "...."
```

The `authorizationUri`, `tokenUri`, `jwkSetUri`, and `userInfoUri` come from your OIDC provider's well known metadata URL. Your identity provider administrator will provide you this URL.

For classic ArkCase (which uses an AngularJS UI, and has a version below 2024), the `registrationId` must match the last path element of the `redirectUri`.  The `redirectUri` must be of the form: `https://$baseUrl/arkcase/login/oauth2/code/$registrationId`.

This document will be updated when OIDC is supported on modern ArkCase (Angular UI, versions 2024 and above).

The `scope`, `responseType`, and `responseMode` shown above work in most situations, but can be changed as circumstances demand for particular OIDC services or customer requirements.

`usersDirectory` must be the LDAP Spring bean name of the directory holding the user records for the OIDC users.  By convention, this bean name is formed by replacing the dots in the domain name with underscores.  So, for a login domain `dev.arkcase.com`, the `usersDirectory` is `dev_arkcase_com`.

You must obtain the `clientId` and `clientSecret` from your identity provider administrator.

### User Administration

For ArkCase application users, the ArkCase directory needs a user entry for every OIDC user; this is how ArkCase knows which privileges each user has.  You must pre-populate the ArkCase directory with the users, which your customer will provide. The user password doesn't matter, since the OIDC identity provider performs the authentication.  The user entries in the ArkCase directory must have the same email as the real users, and must be in the appropriate ArkCase groups so they get the right privileges when they login.   

For FOIA portal users, the work described above is not needed.  Every FOIA portal user gets the same privileges, and ArkCase will add each one to the portal directory as they register their accounts at the identity provider.

## <a name="saml"></a>SAML

### Configuration

Supply a map as below.

```yaml
global:
  conf:
    sso:
      enabled: true
      protocol: "saml"
      saml:
        entityId: "..."
        identityProviderUrl: "..."
```

The `entityId` identifies this ArkCase deployment to the identity provider.  You and the identity provider administrator must agree on this value (similar to the OIDC `clientId`).

The `identityProviderUrl` is the URL of the SAML metadata from your identity provider.  Your identity provider administrator will provide you this value.

You may have to provide the ArkCase SAML metadata URL to your identity provider.  The ArkCase SAML metadata URL will use the form: `https://$baseUrl/arkcase/saml/metadata`.

## User Administration

For ArkCase application users, the ArkCase directory needs a user entry for every SAML user; this is how ArkCase knows which privileges each user has.  You must pre-populate the ArkCase directory with the users, which your customer will provide. The user password doesn't matter, since the SAML identity provider performs the authentication.  The user entries in the ArkCase directory must have the same user id as the real users, and must be in the appropriate ArkCase groups so they get the right privileges when they login.   

In some situations the identity provider may not be able to provide the ArkCase user id; for example, some ArkCase sites use an ArkCase-specific user prefix, so that the user "Tom Jones" may have a user id like "334.tom.jones".  If this is the case, you must work with your identity provider claims mapping feature, so as to transform the incoming user id into the ArkCase user id.  

ArkCase does not support SAML authentication for FOIA portal users.