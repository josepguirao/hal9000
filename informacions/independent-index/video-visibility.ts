/**
 * UI del sitio original: nunca mostrar botón/reproductor con un ID inventado.
 * La verificación pública debe quedar almacenada por el publicador tras
 * consultar YouTube. Este módulo no comprueba disponibilidad por sí mismo.
 */
export type ArticleVideo = {
  videoId?: string | null;
  youtubeUrl?: string | null;
  video?: { id?: string | null; url?: string | null; publicVerified?: boolean | null };
  youtubePublicVerified?: boolean | null;
};
export function publishedYouTubeUrl(a: ArticleVideo): string | null {
  const id = (a.video?.id ?? a.videoId ?? "").trim();
  const raw = a.video?.url ?? a.youtubeUrl ?? "";
  const verified = a.video?.publicVerified === true || a.youtubePublicVerified === true;
  if (!verified || !/^[\w-]{11}$/.test(id) || !raw) return null;
  try {
    const u = new URL(raw);
    if (u.protocol !== "https:") return null;
    if ((u.hostname === "www.youtube.com" || u.hostname === "youtube.com") &&
        u.pathname === "/watch" && u.searchParams.get("v") === id) return u.href;
    if (u.hostname === "youtu.be" && u.pathname === "/" + id) return u.href;
  } catch { /* Sin enlace real */ }
  return null;
}
/*
 * React:
 * const watchUrl = publishedYouTubeUrl(article);
 * {watchUrl && <a href={watchUrl}>Veure vídeo</a>}
 * {watchUrl && <YouTubePlayer videoId={article.video?.id ?? article.videoId} />}
 * Usar la misma comprobación en recomendaciones, tarjetas y los cuatro idiomas.
 */
