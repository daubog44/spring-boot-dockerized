package com.example.mappinges9.web;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.context.annotation.RequestScope;
import org.springframework.web.servlet.ModelAndView;

import com.example.mappinges9.backend.LoginService;
import com.example.mappinges9.backend.MySession;
import com.example.mappinges9.backend.ProductService;
import lombok.extern.slf4j.Slf4j;

@Controller
@Slf4j
@RequestScope
public class HomeController {

	@Autowired
	ProductService s;

	@Autowired
	MySession session;

	@GetMapping("")
	public String home(Model m) throws IOException {
		m.addAttribute("msg", "Benvenuto nella home del sito!");
		m.addAttribute("session", session);
		return "home-view";
	}

}
