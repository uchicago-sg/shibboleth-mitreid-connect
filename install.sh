#!/bin/bash -ex
#
# Preconditions:
# - Shibboleth is configured.
# - Apache is configured in /etc/httpd, to use the Shibboleth module.
# - Current versions of IAM Fedora Linux.
# - Firewalled access to :80, :443, and :22 only.
# - The environment has root permissions.
#

if [ -z "$HOST_NAME" ]; then
  HOST_NAME=openidc.uchicago.edu
fi

yum install tomcat6 tomcat-native mysql-server mysql-connector-java

cat > /etc/httpd/vhosts.d/tomcat-ajp.conf <<EOF
<VirtualHost *:80>
  ServerName $HOST_NAME
  ServerAlias openidcdev
  Redirect / https://$HOST_NAME/
</VirtualHost>

<VirtualHost *:443>
  ServerName $HOST_NAME
  SSLEngine On
  SSLCertificateFile /etc/httpd/ssl/server.crt
  SSLCertificateKeyFile /etc/httpd/ssl/server.key

  ProxyPass /Shibboleth.sso !
  ProxyPass /local http://localhost:8082/
  ProxyPass / ajp://localhost:8081/

  <Location />
    AuthType shibboleth
    ShibUseHeaders On
  </Location>

  <LocationMatch ^/(login|authorize|manage)>
    ShibRequestSetting requireSession 1
    Require valid-user
  </LocationMatch>
</VirtualHost>
EOF

cat > /etc/tomcat6/server.xml <<EOF
<?xml version='1.0' encoding='utf-8'?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
<Server port="8005" shutdown="SHUTDOWN">

  <!--Initialize Jasper prior to webapps are loaded. Documentation at /docs/jasper-howto.html -->
  <Listener className="org.apache.catalina.core.JasperListener" />
  <!-- Prevent memory leaks due to use of particular java/javax APIs-->
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <!-- JMX Support for the Tomcat server. Documentation at /docs/non-existent.html -->
  <Listener className="org.apache.catalina.mbeans.ServerLifecycleListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />

  <!-- A "Service" is a collection of one or more "Connectors" that share
       a single "Container" Note:  A "Service" is not itself a "Container", 
       so you may not define subcomponents such as "Valves" at this level.
       Documentation at /docs/config/service.html
   -->
  <Service name="Catalina">

    <!-- Define an AJP 1.3 Connector on port 8081 -->
    <Connector port="8081" protocol="AJP/1.3"/>

    <Engine name="Catalina" defaultHost="localhost">

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true"
            xmlValidation="false" xmlNamespaceAware="false">

      </Host>
    </Engine>
  </Service>
</Server>
EOF

mysql -u root <<EOF
-- Copied from:
--   openid-connect-server-webapp/src/main/resources/db/tables/
--     mysql_database_tables.sql

CREATE TABLE IF NOT EXISTS access_token (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	token_value VARCHAR(4096),
	expiration TIMESTAMP NULL,
	token_type VARCHAR(256),
	refresh_token_id BIGINT,
	client_id VARCHAR(256),
	auth_holder_id BIGINT,
	id_token_id BIGINT,
	approved_site_id BIGINT
);

CREATE TABLE IF NOT EXISTS address (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	formatted VARCHAR(256),
	street_address VARCHAR(256),
	locality VARCHAR(256),
	region VARCHAR(256),
	postal_code VARCHAR(256),
	country VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS approved_site (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	user_id VARCHAR(4096),
	client_id VARCHAR(4096),
	creation_date TIMESTAMP NULL,
	access_date TIMESTAMP NULL,
	timeout_date TIMESTAMP NULL,
	whitelisted_site_id VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS approved_site_scope (
	owner_id BIGINT,
	scope VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS authentication_holder (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	owner_id BIGINT,
	authentication LONGBLOB
);

CREATE TABLE IF NOT EXISTS client_authority (
	owner_id BIGINT,
	authority LONGBLOB
);

CREATE TABLE IF NOT EXISTS authorization_code (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	code VARCHAR(256),
	authentication LONGBLOB
);

CREATE TABLE IF NOT EXISTS client_grant_type (
	owner_id BIGINT,
	grant_type VARCHAR(2000)
);

CREATE TABLE IF NOT EXISTS client_response_type (
	owner_id BIGINT,
	response_type VARCHAR(2000)
);

CREATE TABLE IF NOT EXISTS blacklisted_site (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	uri VARCHAR(2048)
);

CREATE TABLE IF NOT EXISTS client_details (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	
	client_description VARCHAR(1024),
	reuse_refresh_tokens BOOLEAN NOT NULL DEFAULT 1,
	dynamically_registered BOOLEAN NOT NULL DEFAULT 0,
	allow_introspection BOOLEAN NOT NULL DEFAULT 0,
	id_token_validity_seconds BIGINT NOT NULL DEFAULT 600,
	
	client_id VARCHAR(256),
	client_secret VARCHAR(2048),
	access_token_validity_seconds BIGINT,
	refresh_token_validity_seconds BIGINT,
	
	application_type VARCHAR(256),
	client_name VARCHAR(256),
	token_endpoint_auth_method VARCHAR(256),
	subject_type VARCHAR(256),
	
	logo_uri VARCHAR(2048),
	policy_uri VARCHAR(2048),
	client_uri VARCHAR(2048),
	tos_uri VARCHAR(2048),

	jwks_uri VARCHAR(2048),
	sector_identifier_uri VARCHAR(2048),
	
	request_object_signing_alg VARCHAR(256),
	
	user_info_signed_response_alg VARCHAR(256),
	user_info_encrypted_response_alg VARCHAR(256),
	user_info_encrypted_response_enc VARCHAR(256),
	
	id_token_signed_response_alg VARCHAR(256),
	id_token_encrypted_response_alg VARCHAR(256),
	id_token_encrypted_response_enc VARCHAR(256),
	
	token_endpoint_auth_signing_alg VARCHAR(256),
	
	default_max_age BIGINT,
	require_auth_time BOOLEAN,
	created_at TIMESTAMP NULL,
	initiate_login_uri VARCHAR(2048),
	post_logout_redirect_uri VARCHAR(2048),
	unique(client_id)
);

CREATE TABLE IF NOT EXISTS client_request_uri (
	owner_id BIGINT,
	request_uri VARCHAR(2000)
);

CREATE TABLE IF NOT EXISTS client_default_acr_value (
	owner_id BIGINT,
	default_acr_value VARCHAR(2000)
);

CREATE TABLE IF NOT EXISTS client_contact (
	owner_id BIGINT,
	contact VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS client_redirect_uri (
	owner_id BIGINT, 
	redirect_uri VARCHAR(2048) 
);

CREATE TABLE IF NOT EXISTS refresh_token (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	token_value VARCHAR(4096),
	expiration TIMESTAMP NULL,
	auth_holder_id BIGINT,
	client_id VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS client_resource (
	owner_id BIGINT, 
	resource_id VARCHAR(256) 
);

CREATE TABLE IF NOT EXISTS client_scope (
	owner_id BIGINT,
	scope VARCHAR(2048)
);

CREATE TABLE IF NOT EXISTS token_scope (
	owner_id BIGINT,
	scope VARCHAR(2048)
);

CREATE TABLE IF NOT EXISTS system_scope (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	scope VARCHAR(256) NOT NULL,
	description VARCHAR(4096),
	icon VARCHAR(256),
	allow_dyn_reg BOOLEAN NOT NULL DEFAULT 0,
	default_scope BOOLEAN NOT NULL DEFAULT 0,
	structured BOOLEAN NOT NULL DEFAULT 0,
	structured_param_description VARCHAR(256),
	unique(scope)
);

CREATE TABLE IF NOT EXISTS user_info (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	sub VARCHAR(256),
	preferred_username VARCHAR(256),
	name VARCHAR(256),
	given_name VARCHAR(256),
	family_name VARCHAR(256),
	middle_name VARCHAR(256),
	nickname VARCHAR(256),
	profile VARCHAR(256),
	picture VARCHAR(256),
	website VARCHAR(256),
	email VARCHAR(256),
	email_verified BOOLEAN,
	gender VARCHAR(256),
	zone_info VARCHAR(256),
	locale VARCHAR(256),
	phone_number VARCHAR(256),
	phone_number_verified BOOLEAN,
	address_id VARCHAR(256),
	updated_time VARCHAR(256),
	birthdate VARCHAR(256),
	custom_fields BLOB
);

CREATE TABLE IF NOT EXISTS whitelisted_site (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	creator_user_id VARCHAR(256),
	client_id VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS whitelisted_site_scope (
	owner_id BIGINT,
	scope VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS pairwise_identifier (
	id BIGINT AUTO_INCREMENT PRIMARY KEY,
	identifier VARCHAR(256),
	sub VARCHAR(256),
	sector_identifier VARCHAR(2048)
);
EOF

mysql -u root <<EOF
-- Copied from:
--   openid-connect-server-webapp/src/main/resources/db/scopes.sql

SET AUTOCOMMIT FALSE;

START TRANSACTION;

--
-- Insert scope information into the temporary tables.
-- 

INSERT INTO system_scope_TEMP (scope, description, icon, allow_dyn_reg, default_scope, structured, structured_param_description) VALUES
  ('openid', 'log in using your identity', 'user', true, true, false, null),
  ('profile', 'basic profile information', 'list-alt', true, true, false, null),
  ('email', 'email address', 'envelope', true, true, false, null),
  ('address', 'physical address', 'home', true, true, false, null),
  ('phone', 'telephone number', 'bell', true, true, false, null),
  ('offline_access', 'offline access', 'time', true, true, false, null);
  
--
-- Merge the temporary scopes safely into the database. This is a two-step process to keep scopes from being created on every startup with a persistent store.
--

MERGE INTO system_scope
	USING (SELECT scope, description, icon, allow_dyn_reg, default_scope, structured, structured_param_description FROM system_scope_TEMP) AS vals(scope, description, icon, allow_dyn_reg, default_scope, structured, structured_param_description)
	ON vals.scope = system_scope.scope
	WHEN NOT MATCHED THEN
	  INSERT (scope, description, icon, allow_dyn_reg, default_scope, structured, structured_param_description) VALUES(vals.scope, vals.description, vals.icon, vals.allow_dyn_reg, vals.default_scope, vals.structured, vals.structured_param_description);

COMMIT;

SET AUTOCOMMIT TRUE;
EOF