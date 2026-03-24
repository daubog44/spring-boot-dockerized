package com.example.demo;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.support.ClassPathXmlApplicationContext;

@SpringBootApplication
@Slf4j
public class DemoApplication {

	public static void main(String[] args) {
		SpringApplication.run(DemoApplication.class, args);

		// Caricamento del contesto XML
		try (ClassPathXmlApplicationContext context = new ClassPathXmlApplicationContext("file.xml")) {
			// Recupero dei due bean
			User u1 = (User) context.getBean("u1");
			User u2 = (User) context.getBean("u2");
			User u4 = (User) context.getBean("u4");

			log.info("Bean u1: {}", u1);
			log.info("Bean u2: {}", u2);
			log.info("Bean u4: {}", u4);

			// Verifica se u1 e u2 sono diversi (identità)
			log.info("u1 e u2 sono lo stesso oggetto? {}", (u1 == u2));

			// Verifica se l'azienda è la stessa
			if (u1.getCompany() != null && u2.getCompany() != null) {
				log.info("La company di u1 e u2 è la stessa? {}", (u1.getCompany() == u2.getCompany()));
			}
		}
	}

}
