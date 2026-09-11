/**
 * I DTO condivisi fra i microservizi: chi chiama (un client Feign) e chi
 * risponde (un controller) usano la stessa classe, cosi' il contratto non puo'
 * divergere.
 *
 * <p>Un DTO e' un record, senza logica e senza annotazioni JPA:
 *
 * <pre>{@code
 * public record LibroDto(Long id, String titolo, boolean disponibile) {}
 * }</pre>
 *
 * <p>Le annotazioni di validazione ({@code @NotBlank}, {@code @Email}, ...) si
 * possono usare: il modulo dipende da jakarta.validation-api.
 */
package com.example.ttfcloud_esame.common.dto;
