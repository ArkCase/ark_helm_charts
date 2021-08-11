ark_helm_charts
===============

Collection of Helm charts for ArkCase.

How to update the repo?
-----------------------

Whenever you add a new Helm chart or make changes to an existing one,
you need to update the repo. In order to do that, you need to clone
this repo on your local computer and run the following (you need to
have `helm` installed on your local computer):

  1. Create a branch
  2. If creating a new chart, add the new chart to
     [the charts directory](charts)
  3. Run `$ helm package charts/*`
  4. Run `$ helm repo index --url https://arkcase.github.io/ark_helm_charts/ .`
  5. Commit the tarball(s) that helm created and the `index.yaml` file
  6. Run `$ git push`
  7. The new Helm chart (or changes to existing Helm charts) will be
     available once the PR is accepted and merged into the `develop`
     branch
