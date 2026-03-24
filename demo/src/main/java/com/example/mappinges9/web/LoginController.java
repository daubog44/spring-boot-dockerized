package com.example.mappinges9.web;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.context.annotation.RequestScope;

import com.example.mappinges9.backend.LoginService;
import com.example.mappinges9.backend.MySession;
import com.example.mappinges9.backend.User;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

@Controller
@RequestScope
@RequestMapping("/login")
public class LoginController {

    @Autowired
    LoginService ls;

    @Autowired
    MySession session;

    @GetMapping
    public String loginForm() {
        return "login-view";
    }

    @PostMapping
    public String postMethodName(Model m, @RequestParam String name, @RequestParam String password) {
        User u = ls.login(name, password);

        if (u != null) {
            return "redirect:/";
        } else {
            m.addAttribute("error", "Credenziali errate");
            return "login-view";
        }
    }

    @GetMapping("/logout")
    public String logout() {
        ls.logout();
        return "redirect:/login";
    }

}
