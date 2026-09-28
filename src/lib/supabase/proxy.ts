import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { getSupabaseEnv, hasSupabaseEnv } from "./env";

// Runs before each page request (called from src/proxy.ts). It refreshes the
// user's login session if it has expired and saves the new auth cookies.
// Role-based redirects (student → /dashboard, admin → /admin) come in Phase 3.
export async function updateSession(request: NextRequest) {
  if (!hasSupabaseEnv()) {
    console.warn("Supabase env vars not set — skipping session refresh.");
    return NextResponse.next({ request });
  }

  const { url, publishableKey } = getSupabaseEnv();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        cookiesToSet.forEach(({ name, value }) =>
          request.cookies.set(name, value),
        );
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
        Object.entries(headers ?? {}).forEach(([key, value]) =>
          response.headers.set(key, value),
        );
      },
    },
  });

  // Don't put code between createServerClient and getClaims — it triggers
  // the session refresh.
  await supabase.auth.getClaims();

  return response;
}
