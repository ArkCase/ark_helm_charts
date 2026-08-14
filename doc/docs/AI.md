# Artificial Intelligence (AI) Integration for [ArkCase](https://www.arkcase.com/)

## Table of Contents

- [Introduction](#introduction) 
- [Base Configuration](#base-configuration) 
- [Special Considerations](#special-considerations)

## <a name="introduction"></a>Introduction

This document describes how to enable and configure the Artificial Intelligenc (*AI*) functionality for ArkCase using these Helm charts. As with any community-release project, Issues and PRs are always welcome to help move this code further along.

ArkCase supports AI functionality via an [Ollama](https://ollama.com) (or API-equivalent replacement) deployment. This is currently the only LLM engine supported, albeit others may be added in the futue. The exercise of deploying and configuring Ollama is beyond the scope of this document. As part of its AI suite, ArkCase also deploys a [Milvus](https://milvus.io/) vector database (but only if the AI features are enabled, see below).

## <a name="base-configuration"></a>Base Configuration

### Basics

Supply a map as below.

```yaml
global:
  ai:
    # Optional - can be used as a master switch, but its value depends on
    #            the effective values of the "chatbot" and "redaction" flags
    enabled: true
    # Optional - defaults to "false" if not provided
    chatbot: true
    # Optional - defaults to "false" if not provided
    redaction: true
    # Optional - defaults to "${.Release.Name}-llm"
    llm: "some-secret-name"
```

The keys in the `global.ai` map indicate how the integrations will behave. The `global.ai.enabled` flag serves as a master switch to turn the entire suite on or off in a single place. It need not be specified, and if not provided its value will be computed (and possibly adjusted) depending on the values of the `global.ai.chatbot` and `global.ai.redaction` flags as follows:

  - If `global.ai.enabled` is specified and expressly set to `false`, the entire AI suite is disabled and the vector database components will not be rendered, along with any other AI-related bits.
  - If `global.ai.enabled` is specified and set to `true`, or if it's not specified, then...
    - If at least one of `global.ai.chatbot` or `global.ai.redaction` is specified and set to `true`, then the `global.ai.enabled` flag will have a value of `true`
    - If at neither `global.ai.chatbot` nor `global.ai.redaction` are specified or are set to `false`, then the `global.ai.enabled` flag will have a value of `false`

Finally, the value `global.ai.llm` provides the name of a secret which contains the connectivity details to the LLM engine. If the value is not provided, a default name is computed using the Helm release name, following the format `${RELEASE}-llm`. The name of any arbitrary secret may be specified here. The secret, however, _*MUST*_ be structured as follows (example secret YAML provided for reference):

```yaml
apiVersion: v1
kind: Secret
metadata:
  # This must be the value of `global.ai.llm`
  name: "some-secret-name"
  # This must be the namespace that the application is being deployed into
  namespace: "some-namespace"
type: Opaque
stringData:
  # Required, must be a valid URL
  url: "http://ollama.example.com"
  # Optional, will be defaulted to an empty string if not provided
  api-key: "some-long-hex-value"
  # Optional, will be defaulted to an empty string if not provided
  username: "some-username"
  # Optional, will be defaulted to an empty string if not provided
  password: "some-password"
```

_*NOTE: The secret for LLM connectivity MUST exist, or deployment will fail*_

## <a name="special-considerations"></a>Special Considerations

### TBD ...
