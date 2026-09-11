package devdata;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import jakarta.persistence.EntityTransaction;
import jakarta.persistence.metamodel.Attribute;
import jakarta.persistence.metamodel.EmbeddableType;
import jakarta.persistence.metamodel.EntityType;
import jakarta.persistence.metamodel.ManagedType;
import jakarta.persistence.metamodel.PluralAttribute;
import jakarta.persistence.metamodel.SingularAttribute;
import jakarta.persistence.metamodel.Type;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;

import java.lang.annotation.Annotation;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Member;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Random;
import java.util.Set;
import java.util.TreeSet;
import java.util.stream.Collectors;

/**
 * Riempie di righe inventate le tabelle ancora vuote, passando da Hibernate:
 * gli oggetti vengono costruiti dalle classi @Entity e salvati con persist().
 * Cosi' gli id li genera chi deve (IDENTITY, sequenze, UUID), le relazioni
 * puntano a righe che esistono, gli enum sono quelli veri e ogni riga passa
 * dalla stessa validazione (@NotNull, @Size, @Email...) dell'applicazione.
 *
 * Una riga che il database o la validazione rifiutano viene rifatta con
 * valori diversi; se proprio non entra si passa oltre e lo si scrive nel
 * resoconto. Non fa mai fallire l'avvio.
 */
final class Seeder {

    private final EntityManagerFactory emf;
    private final Validator validator;
    private final int rows;
    private final List<String> report = new ArrayList<>();
    private final Map<Class<?>, List<Object>> candidates = new HashMap<>();
    private int failedEntities;
    private int filledEntities;
    private long nextManualId;

    Seeder(EntityManagerFactory emf, Validator validator, int rows) {
        this.emf = emf;
        this.validator = validator;
        this.rows = rows;
    }

    int failedEntities() {
        return failedEntities;
    }

    List<String> run() {
        List<EntityType<?>> all = new ArrayList<>(emf.getMetamodel().getEntities());
        all.sort(Comparator.comparing(EntityType::getName));
        List<EntityType<?>> concrete = all.stream()
                .filter(t -> t.getJavaType() != null && !Modifier.isAbstract(t.getJavaType().getModifiers()))
                .collect(Collectors.toList());
        if (concrete.isEmpty()) {
            report.add("nessuna @Entity: niente da riempire");
            return report;
        }
        for (EntityType<?> type : insertionOrder(concrete)) seed(type);
        report.add("dati di prova: " + filledEntities + " entity riempite"
                + (failedEntities > 0 ? ", " + failedEntities + " con errori" : ""));
        return report;
    }

    // --- Ordine: prima le tabelle a cui le altre puntano ------------------------

    private List<EntityType<?>> insertionOrder(List<EntityType<?>> types) {
        List<EntityType<?>> ordered = new ArrayList<>();
        Set<EntityType<?>> visiting = new HashSet<>();
        for (EntityType<?> t : types) visit(t, types, ordered, visiting);
        return ordered;
    }

    private void visit(EntityType<?> t, List<EntityType<?>> types, List<EntityType<?>> ordered, Set<EntityType<?>> visiting) {
        if (ordered.contains(t) || !visiting.add(t)) return; // gia' fatto, o un ciclo
        for (Attribute<?, ?> a : t.getAttributes()) {
            Attribute.PersistentAttributeType kind = a.getPersistentAttributeType();
            if (kind != Attribute.PersistentAttributeType.MANY_TO_ONE && kind != Attribute.PersistentAttributeType.ONE_TO_ONE
                    && kind != Attribute.PersistentAttributeType.MANY_TO_MANY) continue;
            // L'altro lato (mappedBy) non ha colonne: non impone nessun ordine.
            if (!mappedBy(annotations(findField(t.getJavaType(), a.getName()), a.getJavaMember())).isEmpty()) continue;
            Class<?> target = a instanceof PluralAttribute<?, ?, ?> p ? p.getElementType().getJavaType() : a.getJavaType();
            for (EntityType<?> other : types) {
                if (other != t && target.isAssignableFrom(other.getJavaType()) && !other.getJavaType().isAssignableFrom(t.getJavaType())) {
                    visit(other, types, ordered, visiting);
                }
            }
        }
        visiting.remove(t);
        if (!ordered.contains(t)) ordered.add(t);
    }

    // --- Una entity --------------------------------------------------------------

    private void seed(EntityType<?> type) {
        String name = type.getName();
        long existing = count(type);
        if (existing > 0) {
            report.add(name + ": ha gia' " + existing + " righe, non la tocco");
            return;
        }
        nextManualId = maxId(type) + 1;
        int inserted = 0;
        String lastError = null;
        int consecutive = 0;
        for (int row = 1; row <= rows; row++) {
            String error = insertRow(type, row);
            if (error == null) {
                inserted++;
                consecutive = 0;
            } else {
                lastError = error;
                if (++consecutive >= 3 && inserted == 0) break;
            }
        }
        // Le righe nuove possono essere il bersaglio delle relazioni che vengono dopo.
        candidates.keySet().removeIf(c -> c.isAssignableFrom(type.getJavaType()));
        if (inserted == rows) {
            filledEntities++;
            report.add(name + ": " + inserted + " righe nuove");
        } else {
            failedEntities++;
            report.add("ERRORE " + name + ": " + inserted + " righe su " + rows + " -- " + lastError);
        }
    }

    private String insertRow(EntityType<?> type, int row) {
        String last = null;
        for (int attempt = 0; attempt < 5; attempt++) {
            EntityManager em = emf.createEntityManager();
            EntityTransaction tx = em.getTransaction();
            try {
                tx.begin();
                Object entity = newInstance(type.getJavaType());
                for (Attribute<?, ?> a : sorted(type.getAttributes(), type.getJavaType())) {
                    fill(entity, type, a, row, attempt, em, 0, false);
                }
                String invalid = validate(entity);
                if (invalid != null) {
                    last = invalid;
                    tx.rollback();
                    continue;
                }
                em.persist(entity);
                em.flush();
                tx.commit();
                return null;
            } catch (MissingTarget e) {
                if (tx.isActive()) tx.rollback();
                return e.getMessage();
            } catch (RuntimeException e) {
                last = rootMessage(e);
                try {
                    if (tx.isActive()) tx.rollback();
                } catch (RuntimeException ignored) {
                    // la transazione e' gia' andata
                }
            } finally {
                em.close();
            }
        }
        return last;
    }

    /** Una relazione obbligatoria senza righe a cui puntare: riprovare non serve. */
    private static final class MissingTarget extends RuntimeException {
        MissingTarget(String message) {
            super(message, null, false, false);
        }
    }

    // --- Un campo ---------------------------------------------------------------

    private void fill(Object owner, ManagedType<?> ownerType, Attribute<?, ?> a, int row, int attempt,
                      EntityManager em, int depth, boolean partOfId) {
        Member member = a.getJavaMember();
        Field field = findField(owner.getClass(), a.getName());
        List<Annotation> annotations = annotations(field, member);
        Random rnd = Values.random(owner.getClass().getName(), a.getName(), row, attempt);
        String entity = ownerType.getJavaType().getSimpleName();
        boolean isId = a instanceof SingularAttribute<?, ?> s && s.isId() || partOfId;

        switch (a.getPersistentAttributeType()) {
            case BASIC -> {
                SingularAttribute<?, ?> sa = (SingularAttribute<?, ?>) a;
                if (sa.isVersion()) return;
                if (has(annotations, "GeneratedValue", "UuidGenerator", "CreationTimestamp", "UpdateTimestamp",
                        "CurrentTimestamp", "Formula", "Generated")) return;
                if (sa.isId() && depth == 0 && hasMapsId(ownerType)) return; // lo copia Hibernate dalla relazione
                Values.Rules rules = Values.Rules.of(annotations, a.getJavaType());
                if (isId) {
                    rules.unique = true;
                    rules.required = true;
                }
                Object value;
                if (isId && depth == 0 && isWholeNumber(a.getJavaType())) {
                    value = convertNumber(nextManualId + row - 1 + attempt * 1000L, a.getJavaType());
                } else if (isId && a.getJavaType() == String.class) {
                    value = prefix(owner.getClass()) + "-" + String.format("%03d", row + attempt * 1000);
                } else {
                    value = Values.value(a.getJavaType(), a.getName(), entity, rules, row, attempt, rnd);
                }
                if (value != null) {
                    set(owner, field, member, value);
                } else if (rules.required) {
                    throw new MissingTarget("non so inventare un valore di tipo " + a.getJavaType().getSimpleName()
                            + " per il campo " + a.getName() + ": riempilo tu");
                }
            }
            case EMBEDDED -> {
                if (depth > 3) return;
                Object embedded = newInstance(a.getJavaType());
                EmbeddableType<?> et = emf.getMetamodel().embeddable(a.getJavaType());
                for (Attribute<?, ?> inner : sorted(et.getAttributes(), a.getJavaType())) {
                    fill(embedded, et, inner, row, attempt, em, depth + 1, isId);
                }
                set(owner, field, member, embedded);
            }
            case MANY_TO_ONE, ONE_TO_ONE -> {
                if (!mappedBy(annotations).isEmpty()) return; // l'altro lato: la colonna sta dall'altra parte
                SingularAttribute<?, ?> sa = (SingularAttribute<?, ?>) a;
                boolean unique = a.getPersistentAttributeType() == Attribute.PersistentAttributeType.ONE_TO_ONE
                        || has(annotations, "MapsId") || isId || joinColumnUnique(annotations);
                boolean required = !sa.isOptional() || has(annotations, "MapsId") || isId || joinColumnRequired(annotations);
                List<Object> ids = targets(a.getJavaType(), owner.getClass(), em);
                Object target = null;
                if (!ids.isEmpty()) {
                    int index = unique ? row - 1 + attempt : rnd.nextInt(ids.size());
                    if (index < ids.size()) target = em.find(a.getJavaType(), ids.get(index));
                }
                if (target != null) {
                    set(owner, field, member, target);
                } else if (required) {
                    throw new MissingTarget("serve almeno una riga " + (unique ? "libera " : "") + "di "
                            + a.getJavaType().getSimpleName() + " a cui collegare il campo " + a.getName());
                }
            }
            case MANY_TO_MANY -> {
                if (!mappedBy(annotations).isEmpty()) return;
                Class<?> element = ((PluralAttribute<?, ?, ?>) a).getElementType().getJavaType();
                List<Object> ids = targets(element, owner.getClass(), em);
                Collection<Object> collection = collection(owner, field, member);
                if (ids.isEmpty() || collection == null) return;
                Set<Integer> picked = new TreeSet<>();
                for (int i = 0; i < Math.min(2, ids.size()); i++) picked.add(rnd.nextInt(ids.size()));
                for (int index : picked) collection.add(em.find(element, ids.get(index)));
            }
            case ELEMENT_COLLECTION -> {
                Type<?> element = ((PluralAttribute<?, ?, ?>) a).getElementType();
                Collection<Object> collection = collection(owner, field, member);
                if (element.getPersistenceType() != Type.PersistenceType.BASIC || collection == null) return;
                Values.Rules rules = Values.Rules.of(List.of(), element.getJavaType());
                for (int i = 0; i < 2; i++) {
                    Object v = Values.value(element.getJavaType(), a.getName(), entity, rules, row * 10 + i, attempt, rnd);
                    if (v != null) collection.add(v);
                }
            }
            default -> {
                // ONE_TO_MANY: le righe figlie puntano a questa da sole.
            }
        }
    }

    /** Gli id delle righe a cui una relazione puo' puntare. */
    private List<Object> targets(Class<?> target, Class<?> owner, EntityManager em) {
        // Una relazione verso la propria gerarchia (un "padre" dello stesso tipo)
        // vede anche le righe appena inserite: niente cache.
        boolean self = target.isAssignableFrom(owner) || owner.isAssignableFrom(target);
        if (!self && candidates.containsKey(target)) return candidates.get(target);
        List<Object> ids = new ArrayList<>();
        String entityName = em.getMetamodel().entity(target).getName();
        for (Object e : em.createQuery("select e from " + entityName + " e", target).setMaxResults(500).getResultList()) {
            ids.add(emf.getPersistenceUnitUtil().getIdentifier(e));
        }
        if (!self) candidates.put(target, ids);
        return ids;
    }

    // --- Conteggi -----------------------------------------------------------------

    private long count(EntityType<?> type) {
        EntityManager em = emf.createEntityManager();
        try {
            String n = type.getName();
            try {
                return em.createQuery("select count(e) from " + n + " e where type(e) = " + n, Long.class).getSingleResult();
            } catch (RuntimeException e) {
                return em.createQuery("select count(e) from " + n + " e", Long.class).getSingleResult();
            }
        } finally {
            em.close();
        }
    }

    /** Il piu' grande id numerico scritto a mano, per continuare da li'. */
    private long maxId(EntityType<?> type) {
        if (!type.hasSingleIdAttribute() || !isWholeNumber(type.getIdType().getJavaType())) return 0;
        String idName = null;
        for (SingularAttribute<?, ?> a : type.getSingularAttributes()) if (a.isId()) idName = a.getName();
        if (idName == null) return 0;
        EntityManager em = emf.createEntityManager();
        try {
            Object max = em.createQuery("select max(e." + idName + ") from " + type.getName() + " e").getSingleResult();
            return max instanceof Number n ? n.longValue() : 0;
        } catch (RuntimeException e) {
            return 0;
        } finally {
            em.close();
        }
    }

    // --- Validazione -------------------------------------------------------------

    private String validate(Object entity) {
        if (validator == null) return null;
        Set<ConstraintViolation<Object>> violations = validator.validate(entity);
        if (violations.isEmpty()) return null;
        return violations.stream()
                .map(v -> v.getPropertyPath() + " " + v.getMessage())
                .sorted()
                .limit(3)
                .collect(Collectors.joining("; ", "non passa la validazione: ", ""));
    }

    static String rootMessage(Throwable e) {
        Throwable root = e;
        while (root.getCause() != null && root.getCause() != root) root = root.getCause();
        String message = root.getMessage() != null ? root.getMessage() : root.getClass().getSimpleName();
        message = message.lines().findFirst().orElse(message).trim();
        return message.length() > 220 ? message.substring(0, 220) + "..." : message;
    }

    // --- Riflessione ---------------------------------------------------------------

    static List<Attribute<?, ?>> sorted(Set<? extends Attribute<?, ?>> attributes, Class<?> type) {
        // L'ordine di dichiarazione, dalla superclasse in giu': e' anche quello
        // in cui le colonne compaiono nello schema.
        List<String> order = new ArrayList<>();
        List<Class<?>> chain = new ArrayList<>();
        for (Class<?> c = type; c != null && c != Object.class; c = c.getSuperclass()) chain.add(0, c);
        for (Class<?> c : chain) for (Field f : c.getDeclaredFields()) order.add(f.getName());
        List<Attribute<?, ?>> list = new ArrayList<>(attributes);
        list.sort(Comparator.comparingInt(a -> {
            int i = order.indexOf(a.getName());
            return i < 0 ? Integer.MAX_VALUE : i;
        }));
        return list;
    }

    static Field findField(Class<?> type, String name) {
        for (Class<?> c = type; c != null && c != Object.class; c = c.getSuperclass()) {
            try {
                return c.getDeclaredField(name);
            } catch (NoSuchFieldException ignored) {
                // nella superclasse, forse
            }
        }
        return null;
    }

    static List<Annotation> annotations(Field field, Member member) {
        List<Annotation> list = new ArrayList<>();
        if (field != null) list.addAll(List.of(field.getAnnotations()));
        if (member instanceof Method m) list.addAll(List.of(m.getAnnotations()));
        return list;
    }

    static boolean has(List<Annotation> annotations, String... simpleNames) {
        for (Annotation a : annotations) {
            String n = a.annotationType().getSimpleName();
            for (String s : simpleNames) if (n.equals(s)) return true;
        }
        return false;
    }

    static Annotation find(List<Annotation> annotations, String simpleName) {
        for (Annotation a : annotations) if (a.annotationType().getSimpleName().equals(simpleName)) return a;
        return null;
    }

    static String mappedBy(List<Annotation> annotations) {
        for (Annotation a : annotations) {
            String n = a.annotationType().getSimpleName();
            if (n.equals("OneToOne") || n.equals("OneToMany") || n.equals("ManyToMany")) {
                Object v = Values.attr(a, "mappedBy");
                if (v instanceof String s && !s.isEmpty()) return s;
            }
        }
        return "";
    }

    private static boolean joinColumnUnique(List<Annotation> annotations) {
        Annotation join = find(annotations, "JoinColumn");
        return join != null && Boolean.TRUE.equals(Values.attr(join, "unique"));
    }

    private static boolean joinColumnRequired(List<Annotation> annotations) {
        Annotation join = find(annotations, "JoinColumn");
        return join != null && Boolean.FALSE.equals(Values.attr(join, "nullable"));
    }

    private boolean hasMapsId(ManagedType<?> type) {
        for (Attribute<?, ?> a : type.getAttributes()) {
            if (has(annotations(findField(type.getJavaType(), a.getName()), a.getJavaMember()), "MapsId")) return true;
        }
        return false;
    }

    static Object newInstance(Class<?> type) {
        try {
            Constructor<?> c = type.getDeclaredConstructor();
            c.setAccessible(true);
            return c.newInstance();
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException(type.getSimpleName() + " non ha un costruttore senza argomenti", e);
        }
    }

    private static void set(Object owner, Field field, Member member, Object value) {
        try {
            if (field != null) {
                field.setAccessible(true);
                field.set(owner, value);
                return;
            }
            if (member instanceof Method getter) {
                String name = getter.getName().replaceFirst("^(get|is)", "");
                Method setter = owner.getClass().getMethod("set" + name, getter.getReturnType());
                setter.invoke(owner, value);
            }
        } catch (ReflectiveOperationException e) {
            throw new IllegalStateException("non riesco a scrivere il campo " + member.getName(), e);
        }
    }

    @SuppressWarnings("unchecked")
    private static Collection<Object> collection(Object owner, Field field, Member member) {
        if (field == null) return null;
        try {
            field.setAccessible(true);
            Object current = field.get(owner);
            if (current instanceof Collection<?> c) return (Collection<Object>) c;
            if (current != null) return null; // una Map: la lasciamo stare
            Collection<Object> created = List.class.isAssignableFrom(field.getType()) ? new ArrayList<>() : new LinkedHashSet<>();
            if (!field.getType().isAssignableFrom(created.getClass())) return null;
            field.set(owner, created);
            return created;
        } catch (ReflectiveOperationException e) {
            return null;
        }
    }

    private static boolean isWholeNumber(Class<?> t) {
        return t == Long.class || t == long.class || t == Integer.class || t == int.class
                || t == Short.class || t == short.class || t == java.math.BigInteger.class;
    }

    private static Object convertNumber(long v, Class<?> t) {
        if (t == Integer.class || t == int.class) return (int) v;
        if (t == Short.class || t == short.class) return (short) v;
        if (t == java.math.BigInteger.class) return java.math.BigInteger.valueOf(v);
        return v;
    }

    private static String prefix(Class<?> type) {
        String n = type.getSimpleName().replaceAll("Entity$", "").toUpperCase(java.util.Locale.ROOT);
        return n.length() > 3 ? n.substring(0, 3) : n;
    }
}
