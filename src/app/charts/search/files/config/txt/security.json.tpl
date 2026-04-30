{
  "authentication": {
    "class": "solr.BasicAuthPlugin",
    "blockUnknown": true,
    "credentials": {
      ($ENV.SOLR_USERNAME): $ENV.USER_HASH,
      ($ENV.SOLR_ADMIN_USERNAME): $ENV.ADMIN_HASH
    }
  },
  "authorization": {
    "class": "solr.RuleBasedAuthorizationPlugin",
    "permissions": [
      {"name": "health-check", "path": "/admin/info/health", "role": null},
      {"name": "security-read", "role": "admin"},
      {"name": "security-edit", "role": "admin"},
      {"name": "schema-edit", "role": "admin"},
      {"name": "config-edit", "role": "admin"},
      {"name": "collection-admin-edit", "role": "admin"},
      {"name": "core-admin-edit", "role": "admin"},
      {"name": "read", "role": "user"},
      {"name": "update", "role": "user"}
    ],
    "user-role": {
      ($ENV.SOLR_USERNAME): "user",
      ($ENV.SOLR_ADMIN_USERNAME): ["admin", "user"]
    }
  }
}
