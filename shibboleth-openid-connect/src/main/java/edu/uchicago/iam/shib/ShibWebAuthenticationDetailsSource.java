package edu.uchicago.iam.shib;

import org.springframework.security.authentication.AuthenticationDetailsSource;
import org.springframework.security.web.authentication.preauth.PreAuthenticatedGrantedAuthoritiesWebAuthenticationDetails;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import org.mitre.openid.connect.model.DefaultUserInfo;

import java.util.ArrayList;

import javax.servlet.http.HttpServletRequest;

public class ShibWebAuthenticationDetailsSource implements 
        AuthenticationDetailsSource {

	@Override
	public Object buildDetails(Object context) {

		ArrayList<GrantedAuthority> roles = new ArrayList<GrantedAuthority>();

		return new PreAuthenticatedGrantedAuthoritiesWebAuthenticationDetails
			((HttpServletRequest)context, roles);
	}
}