package com.example.mappinges9.backend;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;

@Service
public class UserService {

    private Map<String, User> db = new HashMap<>();

    public void add(User... u) {
        for (User ui : u) {
            db.put(ui.getName(), ui);
        }
    }

    @PostConstruct
    public void init() {
        db.put("Mario", new User("Mario", "Rossi", "1234"));
        db.put("Luigi", new User("Luigi", "Rossi", "1234"));
        db.put("Peach", new User("Peach", "Rossi", "1234"));
    }

    public List<User> getAllUsers() {
        return db.values().stream().toList();
    }

    public User getByLogin(String name) {
        return db.get(name);
    }

    public User getByLoginAndPassword(String name, String password) {
        User u = getByLogin(name);
        return (u != null && u.getPassword().equals(password)) ? u : null;
    }

}
