package com.example.mappinges9.backend;

import org.springframework.stereotype.Component;
import org.springframework.web.context.annotation.SessionScope;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Component
@Getter
@Setter
@SessionScope
@NoArgsConstructor
public class MySession {
    User user;
}