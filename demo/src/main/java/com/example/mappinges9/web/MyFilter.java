package com.example.mappinges9.web;

import java.io.IOException;

import org.springframework.stereotype.Component;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.context.support.WebApplicationContextUtils;

import com.example.mappinges9.backend.MySession;
import com.example.mappinges9.backend.User;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;

@Component
@Slf4j
public class MyFilter implements jakarta.servlet.Filter {

    private boolean containsAny(String utl, String... txt) {
        for (String t : txt) {
            if (utl.contains(t)) {
                return true;
            }
        }
        return false;
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {

        HttpServletRequest httpRequest = (HttpServletRequest) request;
        HttpServletResponse httpResponse = (HttpServletResponse) response;

        String url = httpRequest.getRequestURI();

        WebApplicationContext context = WebApplicationContextUtils
                .getWebApplicationContext(httpRequest.getServletContext());
        MySession session = context.getBean(MySession.class);

        User u = session.getUser();

        if (u == null && !containsAny(url, "/login")) {
            httpResponse.sendRedirect("/login");
        } else {
            chain.doFilter(request, response);
        }

    }
}
