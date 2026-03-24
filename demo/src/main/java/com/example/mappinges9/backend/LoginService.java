package com.example.mappinges9.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.context.annotation.RequestScope;

import lombok.extern.slf4j.Slf4j;

@Service
@Slf4j
@RequestScope
public class LoginService {

    @Autowired
    MySession session;

    @Autowired
    private UserService userService;

    public User login(String name, String password) {
        log.info("Login attempt for user: {} session: {}", name, session);
        User u = userService.getByLoginAndPassword(name, password);
        if (u != null) {
            session.setUser(u);
            return u;
        }
        return null;
    }

    public void logout() {
        session.setUser(null);
    }
}
