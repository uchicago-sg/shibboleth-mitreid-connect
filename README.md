## Shibboleth OpenID Connect Overlay

This is a rudimentary Maven overlay for MITREid Connect; it adds support for
running MITRE behind a Shibboleth-enabled Apache server that adds authentication
headers.

### Configuration

The following files should be edited before deployment:

1. OpenID Connect `issuer` in
   `shibboleth-openid-connect/src/main/webapp/WEB-INF/server-config.xml`.
   
        <bean id="configBean" class="org.mitre.openid.connect.config.ConfigurationPropertiesBean">
          <!-- This property is changed to match the deployed URL of the example overlay project. -->
          <!-- This property sets the root URL of the server, known as the issuer -->
          <property name="issuer" value="https://path/to/my/server/" />
        
          <!-- This property is a URL pointing to a logo image 24px high to be used in the top bar -->
          <property name="logoImageUrl" value="resources/images/openid_connect_small.png" />
        
          <!-- This property sets the display name of the server, displayed in the topbar and page title -->
          <property name="topbarTitle" value="My OpenID Connect Server" />
          
          <!-- This property forces the issuer value to start with "https" -->
          <property name="forceHttps" value="true" />
        </bean>
   
2. JDBC `url`, `username`, `password` in
   `shibboleth-openid-connect/src/main/webapp/WEB-INF/data-context.xml`.

      	<bean id="dataSource" class="org.apache.commons.dbcp.BasicDataSource" destroy-method="close">
      		<property name="driverClassName" value="com.mysql.jdbc.Driver" />
      		<property name="url" value="jdbc:mysql://localhost/openidc" />
      		<property name="username" value="openidc" />
      		<property name="password" value="" />		
      	</bean>

Deployments other than those at the University of Chicago will probably want to
edit `./shibboleth-openid-connect/src/main/java/edu/uchicago/iam/shib/ShibRequestHeaderAuthenticationFilter.java`,
to configure the LDAP attributes a user must have before being granted administrative
access to OpenID Connect. 

More information is available on the MITREid Connect [wiki](https://github.com/mitreid-connect/OpenID-Connect-Java-Spring-Server/wiki/Server-configuration).

### Deployment

To deploy this package:

1. Install Apache2 and Tomcat. A script, `install.sh`, is provided, which will
   configure an instance on Red Hat Enterprise Linux.

        yum install tomcat6 tomcat-native mysql-server mysql-connector-java
   
2. Configure Shibboleth authentication on Apache2.
3. Configure a proxy to Tomcat, making sure to enable `ShibUseHeaders On`:

        ProxyPass /Shibboleth.sso !
        ProxyPass / ajp://localhost:8081/
         
        <Location />
          AuthType shibboleth
          ShibUseHeaders On
        </Location>
         
        <LocationMatch ^/(login|authorize|manage)>
          ShibRequestSetting requireSession 1
          Require valid-user
        </LocationMatch>

4. Run `mvn package` in this repository, and copy
   `target/shibboleth-openid-connect.war` to `path/to/tomcat6/webapps/ROOT.war`.
   
        % mvn package
        % scp target/shibboleth-openid-connect.war my-server:/var/lib/tomcat6/webapps/ROOT.war
   
5. Run the MySQL setup script at
  `shibboleth-openid-connect/src/main/resources/db/tables/mysql_database_tables.sql`.
  
        # mysql -u root < mysql_database_tables.sql

To install this package, first configure the OpenID Connect server in
`shibboleth-openid-connect/src/main/webapp/WEB-INF/server-config.xml`.
All configuration is optional, except the value of `issuer`, which should be
a publishable base URL for the deployed service, ending in a slash.

Next, configure the MySQL data backend, in
`./shibboleth-openid-connect/src/main/webapp/WEB-INF/data-context.xml`.

### License

This code is covered under the Apache license:

    Copyright 2015 The MITRE Corporation
    and the MIT Kerberos and Internet Trust Consortium
        
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
    http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.