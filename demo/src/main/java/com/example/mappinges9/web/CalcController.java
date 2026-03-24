package com.example.mappinges9.web;

import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Controller
@RequestMapping("/calc")
public class CalcController {

	@Data
	@NoArgsConstructor
	@AllArgsConstructor
	public static class Dati{
		private int x,y,somma;
	}
	
	@GetMapping("")
	public String getCalc(Model m) {
		m.addAttribute("dati", new Dati());
		return "calc-view";
	}

	@PostMapping("")
	public String somma(@RequestParam int a, 
			@RequestParam int b, Model m) {
		m.addAttribute("dati", new Dati(a,b,a+b));
		return "calc-view";
	}
	
}
