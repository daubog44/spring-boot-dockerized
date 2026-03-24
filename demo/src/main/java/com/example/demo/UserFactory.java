package com.example.demo;

import lombok.Data;

@Data
public class UserFactory {
    private String suffix;

    public User createUser(String n, String s) {
        User user = new User();
        user.setName(n);
        user.setSurname(s + " " + suffix);
        return user;
    }
}
