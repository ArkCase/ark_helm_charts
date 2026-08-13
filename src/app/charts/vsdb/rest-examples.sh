
DB_ROLE_ADMIN="${DATABASE}-owner"
DB_ROLE_RW="${DATABASE}-rw"
DB_ROLE_RO="${DATABASE}-ro"

# Create database
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/database/create" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"dbName": "${DATABASE}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/database/describe" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"dbName": "${DATABASE}"
	}'

# Create the collection
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/collections/create" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"dbName": "${DATABASE}",
		"collectionName": "${COLLECTION}",
		"dimension": ${DIMENSION}
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/collections/describe" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"dbName": "${DATABASE}",
		"collectionName": "${COLLECTION}"
	}'

# Create the admin role
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/create" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_ADMIN}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/describe" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_ADMIN}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/grant_privilege" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_ADMIN}",
		"objectType": "Database",
		"objectName": "${DATABASE}",
		"privilege": "DB_Admin"
	}'

# Create the read-write role
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/create" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_RW}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/describe" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_RW}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/grant_privilege" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_RW}",
		"objectType": "Database",
		"objectName": "${DATABASE}",
		"privilege": "DB_RW"
	}'

# Create the read-only role
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/create" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_RO}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/describe" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_RO}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/roles/grant_privilege" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"roleName": "${DB_ROLE_RO}",
		"objectType": "Database",
		"objectName": "${DATABASE}",
		"privilege": "DB_RO"
	}'

# Create user
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/users/create" \
	--user <(cat "${AUTH_INFO}") \
	--header 'Content-Type: application/json' \
	--data '{
		"userName": "${USERNAME}",
		"password": "${PASSWORD}"
	}'
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/users/describe" \
	--user <(cat "${AUTH_INFO}") \
	--header 'Content-Type: application/json' \
	--data '{
		"userName": "${USERNAME}"
	}'

# Reset password
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/users/update_password" \
	--user <(cat "${AUTH_INFO}") \
	--header 'Content-Type: application/json' \
	--data '{
		"userName": "${USERNAME}",
		"password": "",
		"newPassword": "${PASSWORD}"
	}'

# Grant the user ownership of their DB
curl --request POST \
	--url "https://localhost:19530/v2/vectordb/users/grant_role" \
	--user <(cat "${AUTH_INFO}") \
	--header "Content-Type: application/json" \
	--data '{
		"userName": "${USERNAME}",
		"roleName": "${DB_ROLE_ADMIN}"
	}'
