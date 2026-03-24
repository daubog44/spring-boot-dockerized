package com.example.mappinges9.backend;

import java.util.List;

import org.springframework.stereotype.Service;

@Service
public class ProductService {

	private List<Product> db = List.of(
			new Product(1L, "PC", "...", 1200f),
			new Product(2L, "mouse", "...", 18f),
			new Product(3L, "tablet", "...", 600f));

	public List<Product> getAll() {
		return db;
	}

	public List<Product> get(String q) {
		return db.stream().filter(p -> p.getName().contains(q) || p.getDescription().contains(q)).toList();
	}

	public List<Product> filterByNameOrDescription(String q) {
		String q2 = q.toLowerCase();
		return db.stream()
				.filter(p -> p.getName().toLowerCase().contains(q2) || p.getDescription().toLowerCase().contains(q2))
				.toList();
	}
}
