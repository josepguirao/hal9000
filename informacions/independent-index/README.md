# INFORMACIONS.AD — índice sin Work (09/11/2026)

**Estado: CÓDIGO DE ENSAYO, NO DESPLEGADO.**

Proyecto original INFORMACIONS, Sites ID appgprj_6aafae2ba6748191bf1b341c760560b3. El CMS editorial publica los cuatro locales, pero no sincroniza los listados estáticos. El archivo sigue mostrando como primera edición MATÍ 06/11. NO crear artículos para alterar índices, NO depender de Work.

## Archivos
- worker.mjs: endpoint de ensayo /_a24/index.json?lang=ca, vista /_a24/preview?lang=ca y salud /_a24/health; lectura de sitemap, deduplicación, ordenación, idiomas aislados, títulos sin invenciones y cache corta.
- worker.test.mjs: pruebas de 32 URLs (07/11 y 08/11, 4 franjas y 4 locales), orden, deduplicación y validación del dominio.
- ajw-visible-playlists.html: dos enlaces permanentes para incluir en la FUENTE original de /andorra-justice-watch, FUERA del último details.
- video-visibility.ts: comprobación estricta de ID/URL/publicación YouTube; no CTA ni player cuando falte cualquier requisito.
- wrangler.toml: workers.dev de ensayo únicamente; NO intercepta informacions.ad.

## Ejecución técnica propuesta
1. RAY escribe los artículos locales de manera idempotente: ID canónico + sufijo -ca/-es/-fr/-en, body de párrafos completos, sin format andorra24flash. Verificar GET por slug y HTML público.
2. El índice dinámico descubre URL que existen en sitemap.xml. Agrupar por fecha/franja y ordenar descendentemente. Mantener identificadores originales y preservar 25 ediciones históricas y 86 textos previos.
3. Cuando se disponga del código fuente legítimo del frontend, sustituir la dependencia de content/andorra24-scripts.json por consulta al CMS o al índice, integrándola en components/editorial/andorra24-bulletins.tsx y módulos de portada/sección. Invalidar cache después de publicar. No cambiar artículos individuales.
4. Añadir los enlaces visibles de AJW en el componente original, después de Arxiu audiovisual. No eliminar ni modificar vídeos.
5. Reutilizar video-visibility.ts en artículos y tarjetas. «Últimos cuatro vídeos» debe usar la metadata real de YouTube (videoId, idioma de audio, fecha) y mantenerse separado de los destacados, incluido Binance.
6. Verificar tanto SSR como navegación React hidratada. Inyectar HTML dentro del árbol React por HTMLRewriter puede ser revertido al hidratar y NO se considera una solución estable.
7. Despliegue versionado y reversible SOLO tras confirmar permisos, ensayo y copia de configuración.

## Ensayo local
Node 20+: ejecutar node --test worker.test.mjs. El Worker solo sirve rutas /_a24/* en un subdominio de ensayo Workers (no rutas del periódico). Examinar /_a24/index.json?lang=ca y /_a24/preview?lang=es. Si sitemap deja de tener URL, responder 503 sin sustituir contenido vivo.

## Permisos: bloqueo real actual
No se ha verificado acceso administrativo del propietario a la zona Cloudflare informacions.ad ni al repositorio fuente que compila el Site. El editor INFORMACIONS solo publica artículos, no componentes React. Ser servido desde infraestructura Cloudflare NO concede por sí solo permisos para modificar DNS o Workers.
La autorización mínima para seguir, si el propietario controla la zona, es lectura de Zone/DNS y edición de Workers Scripts/Routes, por interfaz oficial y sin compartir tokens en chats. Comprobar nube naranja, zona y ruta de ensayo antes de programar publicación. NO cambiar nombres de servidor ni DNS críticos.
Si el proxy no está bajo control del propietario, la reparación fiable será obtener el código fuente original y migrar progresivamente frontend a un repositorio propio con despliegue independiente, sin modificar el dominio hasta su prueba y autorización. No es un paso automático.

## Condiciones de cierre
- Archivo y portada incluyen ediciones 07/11, 08/11 y posteriores de CA/ES/FR/EN, correctas por fecha y franja, con los 25 históricos intactos.
- Contenido completo por idioma y enlaces correctos.
- Botones/reproductores ausentes si no hay vídeo real verificado.
- Enlaces al pie de AJW visibles fuera de desplegables: PLM0NJ3AhfV1Q y PLF_JWFAiXapA.
- Últimos vídeos por idioma/audio real, fecha y videoId; Binance no se fija en últimos.
- Verificación pública HTTP y navegador real después de publicar; rollback si falla.
