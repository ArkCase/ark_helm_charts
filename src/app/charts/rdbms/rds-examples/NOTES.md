# Lots learned today regarding RDS:

* All username secrets created by the SQL provider's thinghymebob look exactly like the main RDSInstance secret:

    * username
    * password
    * endpoint
    * port

* The DB name is NOT added to the secret ... which may well be an oversight on my part - I shall look into it when I return. This means that whomever consumes the connectivity info for a given Database (as opposed to a Database Server Instance) must know the DB's name beforehand in order to connect to said DB using the provided coordinates

* There MUST be an init container that waits for the RDS stuff to become available before allowing bootup to continue for dependent subsystems (i.e. everyone who needs the DB must wait for the RDS instance and DB configs to be completed and available before continuing to boot).  Luckily once all that's initialized the first time, there's no need for waits b/c that "waiter pod" will return almost immediately.

* The created RDS-related resources must have Helm's "keep" annotation set so they don't get removed on un-deployment, lest we want to weep at destroyed environments left, right, and center ...

All resources are namespaced, so it's not possible to relocate them to a different namespace. Thus, a clone must be created in the target, and manual DB transplants (copies) executed.
