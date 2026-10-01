# EnlaceHub — Directorio compartido de enlaces

## Propósito

Construir una página web donde un grupo de amigos pueda reunir enlaces a otras páginas, organizarlos por categorías y consultarlos desde una única dirección. Varios usuarios deben poder entrar y trabajar simultáneamente desde computadora o celular. Los datos deben compartirse entre dispositivos y persistir al cerrar el navegador.

Este README es la especificación inicial para implementar el proyecto con Codex. Describe una aplicación pendiente de construcción; no afirma que las funciones ya estén implementadas. EnlaceHub es un nombre provisional.

## Estado actual

**Etapa 1 en progreso — interfaz de demostración funcional.** La base React + TypeScript + Vite está creada y el build de producción pasa correctamente. Incluye directorio responsive, datos de demostración identificados, búsqueda, filtros por categoría, favoritos locales de demostración y formulario de alta/edición. La integración base está preparada para Supabase; todavía no hay autenticación ni persistencia conectadas a un proyecto real.

Para ejecutar la interfaz:

```bash
npm install
npm run dev
```

Para verificar el build:

```bash
npm run build
```

## Tecnologías acordadas

- React, TypeScript y Vite para la interfaz.
- CSS para el diseño adaptable; mantener pocas dependencias.
- Supabase Auth para registro e inicio de sesión con correo y contraseña.
- Supabase Postgres, Row Level Security y Realtime para datos compartidos.
- GitHub para el código y Vercel para publicar el frontend.
- Supabase local CLI para verificar autenticación, políticas RLS y datos durante el desarrollo.

No implementar un servidor propio en la primera versión. No usar localStorage como fuente de datos compartidos. No prometer costos cero: revisar cuotas y condiciones vigentes antes de publicar.

## Alcance de la primera versión

Un único directorio compartido por el grupo. Como configuración inicial, solo usuarios autenticados y aprobados por el administrador pueden consultar y gestionar enlaces. No incluir varios grupos, chat, subida de archivos ni extracción automática de contenido de páginas.

### Usuarios y acceso

- Registro con nombre, correo y contraseña; inicio y cierre de sesión.
- Recuperación de contraseña y mensajes de error en español.
- Los nuevos registros quedan pendientes de aprobación.
- Un administrador activa o desactiva miembros desde un panel.
- Un usuario pendiente ve una pantalla informativa, sin acceso a los enlaces.
- La desactivación debe impedir lecturas y escrituras posteriores mediante políticas RLS, además de retirar el acceso en la interfaz.
- El primer administrador se configura manualmente mediante un procedimiento documentado y confiable. Nunca dar ese rol automáticamente al primer usuario registrado.

### Enlaces

- Crear un enlace con título, URL, descripción opcional y categoría.
- Mostrar título, dominio, descripción, categoría, autor y fecha de creación.
- Abrir en una pestaña nueva y permitir copiar la dirección.
- Editar y eliminar enlaces propios; el administrador puede gestionar todos.
- Pedir confirmación antes de eliminar.
- Validar URL con el parser URL y aceptar únicamente protocolos HTTP y HTTPS.
- Campos propuestos: título entre 1 y 120 caracteres, descripción hasta 500 y URL hasta 2048.
- No interpretar descripciones como HTML ni insertar contenido arbitrario.
- Abrir destinos con rel="noopener noreferrer".
- Avisar de enlaces repetidos por URL normalizada; este aviso no garantiza unicidad global ante creaciones simultáneas.

### Organización

- Categorías iniciales: Universidad, Proyectos, Herramientas, Documentos y Otros.
- El administrador puede crear y renombrar categorías.
- No eliminar categorías que tengan enlaces; solicitar reasignación primero.
- Buscador por título, descripción y dominio; filtros por categoría y por enlaces propios.
- Ordenar por fecha reciente o título.
- Favoritos personales sincronizados entre dispositivos, visibles únicamente para su propietario.
- Al eliminar un enlace, ocultar favoritos cuyo destino ya no exista y permitir limpiarlos.

### Tiempo real y concurrencia

- Usar suscripciones de Supabase Realtime para reflejar altas, cambios y eliminaciones sin recargar.
- Liberar listeners al desmontar vistas o cerrar sesión.
- Mantener los valores del formulario cuando falle un guardado.
- Usar timestamps del servidor y una revisión numérica por enlace.
- Al editar, comparar la revisión leída mediante una transacción. Si otro usuario modificó el enlace, informar el conflicto y ofrecer recargar antes de sobrescribir.
- Un enlace eliminado mientras se edita debe producir un mensaje claro.
- Mostrar estados de carga, guardado, vacío, error de permisos y pérdida de conexión. No mostrar éxito antes de confirmar la escritura.

## Permisos

| Acción | Visitante / pendiente | Miembro activo | Administrador activo |
|---|---|---|---|
| Consultar enlaces | No | Sí | Sí |
| Crear enlaces | No | Sí | Sí |
| Editar/eliminar propios | No | Sí | Sí |
| Editar/eliminar ajenos | No | No | Sí |
| Gestionar categorías | No | No | Sí |
| Gestionar favoritos propios | No | Sí | Sí |
| Aprobar/desactivar miembros | No | No | Sí |
| Cambiar roles desde la web | No | No | No |

Los roles se administran fuera del cliente con herramientas confiables. Ocultar un botón no sustituye la autorización en RLS. Impedir que el administrador se desactive a sí mismo desde el panel.

## Modelo de datos propuesto

### users/{uid}

- displayName: string
- role: "member" o "admin"
- active: boolean
- createdAt: timestamp del servidor

El registro solo puede crear su propio perfil con role="member" y active=false. El usuario puede modificar únicamente su nombre. El administrador puede actualizar active de otros miembros, sin cambiar role ni createdAt. Los miembros leen su perfil; solo el administrador lista perfiles. Mantener el correo en Authentication salvo que una necesidad concreta justifique almacenarlo también.

### categories/{categoryId}

- name: string
- createdAt: timestamp
- updatedAt: timestamp

### links/{linkId}

- title: string
- url: string
- normalizedUrl: string
- description: string
- categoryId: string
- createdBy: uid
- createdAt: timestamp
- updatedAt: timestamp
- revision: integer, inicialmente 1

createdBy y createdAt son inmutables. Cada actualización incrementa revision en uno. Validar que la categoría exista. Resolver el nombre del autor mediante un perfil público mínimo separado si es necesario; no permitir listar perfiles privados para mostrar autores.

### publicProfiles/{uid}

- displayName: string

Lectura permitida a miembros activos. El propietario puede actualizar únicamente su nombre. Este documento no contiene roles ni datos de contacto.

### users/{uid}/favorites/{linkId}

- createdAt: timestamp

Cada usuario activo solo puede leer y modificar sus propios favoritos.

## Reglas de seguridad obligatorias

- Denegar todo por defecto y autorizar explícitamente cada colección.
- Comprobar autenticación, perfil activo, propiedad y rol en las reglas.
- Validar tipos, longitudes, campos permitidos e invariantes de creación/actualización.
- No permitir cambiar propietario, fechas originales o privilegios desde el navegador.
- Incluir el esquema SQL y políticas RLS en el repositorio; no dejar la base de datos sin protección.
- Verificar que un usuario no pueda editar enlaces ajenos, leer favoritos ajenos, autoaprobarse ni elevar su rol.
- Las variables VITE_* quedan expuestas al navegador. La clave `anon` de Supabase no sustituye las políticas RLS. Nunca incluir la clave `service_role` en el frontend o GitHub.

## Interfaz

Diseño limpio, en español y adaptable a celular y computadora. Usar tarjetas con buen contraste y distribución consistente.

Vistas necesarias:

1. Inicio de sesión, registro y recuperación de contraseña.
2. Pantalla de acceso pendiente o desactivado.
3. Directorio con buscador, categorías, favoritos y botón Agregar enlace.
4. Formulario de creación/edición en modal o panel.
5. Panel de administración para miembros y categorías.

Incluir etiquetas de formulario, navegación por teclado, foco visible, cierre accesible de modales y mensajes de validación junto al campo. Los enlaces largos no deben romper el diseño.

## Estructura orientativa

```text
src/
  components/
  pages/
  hooks/
  contexts/
  services/
    supabase.ts
    auth.ts
    links.ts
    categories.ts
    favorites.ts
  types/
  utils/
  styles/
  App.tsx
  main.tsx
firestore.rules
firestore.indexes.json
supabase/schema.sql
.env.example
.gitignore
README.md
```

Separar acceso a datos, validación e interfaz. Ajustar la estructura si mejora la claridad, sin añadir arquitectura innecesaria.

## Configuración a documentar durante la implementación

Crear .env.example con valores vacíos para:

```dotenv
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

Explicar cómo crear el proyecto Supabase, habilitar correo/contraseña, ejecutar `supabase/schema.sql`, configurar el primer administrador y autorizar los dominios de desarrollo/producción. No habilitar Storage si no se utiliza.

Excluir .env.local, credenciales privadas, node_modules y dist del repositorio; conservar .env.example. Documentar los comandos reales de instalación, desarrollo, emuladores, pruebas y build cuando existan.

Para Vercel, documentar el comando de build, directorio de salida dist, variables de entorno y reescritura de rutas si se usa un router. El frontend y las políticas de Supabase se despliegan por separado.

## Etapas de implementación con Codex

1. Crear React + TypeScript + Vite y diseñar las vistas con datos de demostración claramente identificados.
2. Integrar Authentication, perfiles y aprobación de miembros.
3. Implementar categorías, CRUD de enlaces, validación, reglas y pruebas de permisos.
4. Agregar suscripciones, búsqueda, filtros, favoritos y control de conflictos.
5. Revisar accesibilidad, diseño móvil, errores y pruebas con dos sesiones.
6. Completar instrucciones y dejar listo para GitHub y Vercel. Publicar cuando el usuario lo solicite.

Al terminar cada etapa, informar brevemente qué funciona, cómo comprobarlo y qué configuración externa falta. No afirmar que Supabase o el despliegue funcionan si solo se probaron datos locales.

## Criterios de aceptación

- Dos miembros activos ven el mismo directorio y los cambios sin recargar.
- Los enlaces persisten después de cerrar sesión y desde otro dispositivo.
- Cada miembro puede gestionar sus enlaces y no los de otros; el administrador sí puede gestionar todos.
- Los favoritos son personales y se sincronizan.
- Los usuarios pendientes o desactivados no acceden a los datos mediante llamadas directas.
- La interfaz impide guardar campos inválidos y las reglas también rechazan documentos inválidos.
- Se informa de conflictos de edición sin sobrescritura silenciosa.
- La búsqueda y los filtros funcionan; el sitio se adapta a móvil.
- Pasan el build y las pruebas relevantes de reglas, permisos y conflictos.
- No quedan credenciales privadas ni reglas permisivas en el repositorio.

## Instrucción inicial para Codex

> Lee este README e implementa EnlaceHub por etapas. Empieza por la etapa 1 y deja una interfaz funcional con datos de demostración. Respeta el stack, los permisos y el modelo de datos. No uses almacenamiento local como sustituto de Supabase. No inventes credenciales ni presentes simulaciones como funciones conectadas. Cuando necesites configurar Supabase, indica exactamente qué dato o acción falta. Actualiza este README con instrucciones verificadas y el estado real del proyecto.
#   M E N U _ C A R R E R A _ T U R I S M O  
 