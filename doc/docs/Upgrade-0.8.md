
# [ArkCase](https://www.arkcase.com/) Upgrade from series 0.7.0 to series 0.8.0 Helm charts

- [Major Changes](#major-changes)
- [Password Storage](#passwords)
- [Values Changes](#values)

## <a name="major-changes"></a>Major Changes

The new `0.8.0` series Helm charts are a significant improvement over the `0.7.0` (and prior) series in terms of security. Password values for embedded and externally-provided services are no longer expected to be provided via values, and are instead meant to be supplied via `Secret resouces`. Also, the charts and containers include code that will facilitate password rotation (only for services provisioned by the chart!) via an undeploy-redeploy pattern.

Finally, there are no default passwords used anywhere anymore, which significantly bolsters security overall.

## <a name="passwords"></a>Password Storage

In the `0.7.0` series Helm charts, passwords for both internal services provisioned by the chart, as well as provided externally, were supplied to Helm as part of the values configurations. This meant that those passwords had to be exposed in plaintext in order to be consumed by the chart during rendering.

This also meant that those passwords would be locked in using plaintext in some of the rendered resources. This is, of course, a very poor security practice and goes against the generally-accepted best practice of cloud computing regarding storing those sensitive values in `Secret` resouces.

The new `0.8.0` series Helm charts correct this situation in several ways:

  - Service passwords are now stored and consumed from `Secret` resources
  - The containers for the embedded resources include script code that performs password updates and resets, facilitating password rotations
  - Containers consume password values directly from `Secret` resources, most frequently via environment variables

Existing passwords for rendered services are generally re-used when performing in-place upgrades with Helm (i.e. `helm upgrade ...`). Specifically, if the `Secret` housing a given password exists when a deployment or upgrade is attempted, the password value housed therein is reused verbatim. However, if the secret disappears, as would be the case during a reinstall (i.e. `helm uninstall` followed by `helm install`), its password will be re-generated. The service containers will then consume this new password and ensure that any necessary updates are applied for it to work correctly.

This has two basic use modes: services provisioned by the chart, and externally-provided services.

In a very general sense, every "account" that is needed to be served by a service (however it's being provisioned) will need a `Secret` resource that provides all the required connectivity information. For instance: for a database connection that means the host, port, username, password, and database name.

### Services Provisioned by the Chart

In this section the `rdbms` service will be used as an example, but the same principles apply for any support service.

When the chart is first deployed (i.e. no prior deployment) using an embedded instance of `rdbms`, all the necessary resources for that service to be provided are rendered by Helm. This includes the necessary `Secret` resources housing all databases expected to be consumed from it. In its current incarnation, 5 databases (each with their specific username) are required.


