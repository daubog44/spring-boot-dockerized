package com.example.demo;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class User {
    private String name;
    private String surname;
    private String username;
    private String password;
    private int eta;
    private Company company;

    public static User getAdmin() {
        User admin = new User();
        admin.setName("Admin");
        admin.setUsername("admin");
        return admin;
    }
}
