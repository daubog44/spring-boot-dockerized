package com.example.mappinges9.web;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.ModelAndView;

import com.example.mappinges9.backend.ProductService;
import lombok.extern.slf4j.Slf4j;

@Controller
@Slf4j
@RequestMapping("/products")
public class ProductController {
	@Autowired
	ProductService s;

	@GetMapping
	public String products(Model m, @RequestParam(defaultValue = "") String query) throws IOException {
		m.addAttribute("products", s.filterByNameOrDescription(query));
		m.addAttribute("query", query);
		return "products-view";
	}

}
