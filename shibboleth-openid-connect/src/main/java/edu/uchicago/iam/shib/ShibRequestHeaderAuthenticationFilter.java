package edu.uchicago.iam.shib;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.web.authentication.preauth.RequestHeaderAuthenticationFilter;
import org.springframework.security.core.Authentication;
import org.springframework.security.authentication.AbstractAuthenticationToken;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import java.util.Collections;
import java.util.List;
import java.util.ArrayList;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.authority.GrantedAuthoritiesContainer;

import org.mitre.openid.connect.model.OIDCAuthenticationToken;
import org.mitre.openid.connect.model.DefaultUserInfo;
import org.mitre.openid.connect.service.UserInfoService;

public class ShibRequestHeaderAuthenticationFilter 
        extends RequestHeaderAuthenticationFilter {

	@Autowired
	private UserInfoService userInfoService;

	public void successfulAuthentication(
			HttpServletRequest request, HttpServletResponse response,
			Authentication authentication) {

		DefaultUserInfo userInfo = new DefaultUserInfo();

		userInfo.setPreferredUsername(request.getHeader("eppn"));
		userInfo.setName(request.getHeader("cn"));
		userInfo.setSub(request.getHeader("eppn"));

		userInfo.setGivenName(request.getHeader("givenName"));
		userInfo.setFamilyName(request.getHeader("sn"));
		userInfo.setMiddleName(request.getHeader("ucMiddleName"));

		userInfo.setEmail(request.getHeader("mail"));
		userInfo.setEmailVerified(true);

		userInfo.setCustomField("affiliation",
			request.getHeader("affiliation"));
		userInfo.setCustomField("ucisMemberOf",
			request.getHeader("ucisMemberOf"));
		userInfo.setCustomField("persistent-id",
			request.getHeader("persistent-id"));
		userInfo.setCustomField("eduPersonPrincipalName",
			request.getHeader("eduPersonPrincipalName"));
		userInfo.setCustomField("chicagoid",
			request.getHeader("chicagoID"));
		userInfo.setCustomField("cnetid",
			request.getHeader("uid"));

		userInfoService.save(userInfo);

		ArrayList<GrantedAuthority> roles = new ArrayList<GrantedAuthority>();
		String[] shibRoles = request.getHeader("ucisMemberOf").split(";");

		for (String shibRole : shibRoles) {
			if (shibRole.equals("uc:applications:openidc:access:authorized"))
				roles.add(new SimpleGrantedAuthority("ROLE_USER"));

			if (shibRole.equals("uc:applications:openidc:administrator"))
				roles.add(new SimpleGrantedAuthority("ROLE_ADMIN"));
		}

		Authentication betterAuth = new OIDCAuthenticationToken(
			userInfo.getSub(), "https://openidcdev.uchicago.edu/", userInfo,
			roles, null, null, null
		);

		super.successfulAuthentication(request, response, betterAuth);
	}
}