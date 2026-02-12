// @ts-nocheck — Deno Edge Function; jsr: imports resolve at deploy time
import { createClient } from "jsr:@supabase/supabase-js@2";

interface CorrectionEntry {
  taskId: string;
  fieldName: string;
  originalValue?: string;
  correctedValue?: string;
  category?: string;
}

interface RecordRequest {
  corrections: CorrectionEntry[];
}

interface ProfileMapping {
  [key: string]: unknown;
  count: number;
  last_used: string;
}

const RATE_LIMIT = 30;
const WINDOW_MS = 60 * 60 * 1000;
const MAX_MAPPINGS = 50;
const rateLimitMap = new Map<string, { count: number; windowStart: number }>();

function checkRateLimit(userId: string): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(userId);
  if (!entry) {
    rateLimitMap.set(userId, { count: 1, windowStart: now });
    return true;
  }
  if (now - entry.windowStart > WINDOW_MS) {
    rateLimitMap.set(userId, { count: 1, windowStart: now });
    return true;
  }
  if (entry.count >= RATE_LIMIT) {
    return false;
  }
  entry.count++;
  return true;
}

/** Extract word-level vocabulary alias from title correction. E.g. "Krogers" -> "Kroger" */
function extractVocabularyAlias(original: string, corrected: string): { spoken: string; canonical: string } | null {
  const origWords = original.split(/\s+/);
  const corrWords = corrected.split(/\s+/);
  if (origWords.length !== corrWords.length) return null;
  let spoken: string | null = null;
  let canonical: string | null = null;
  for (let i = 0; i < origWords.length; i++) {
    if (origWords[i] !== corrWords[i]) {
      if (spoken !== null) return null; // more than one word differed
      spoken = origWords[i];
      canonical = corrWords[i];
    }
  }
  if (spoken && canonical && spoken !== canonical) {
    return { spoken, canonical };
  }
  return null;
}

/** Upsert or increment a mapping in the array, then sort and cap */
function upsertMapping(
  arr: ProfileMapping[],
  key: (m: ProfileMapping) => string,
  newEntry: ProfileMapping,
  idField: string
): ProfileMapping[] {
  const keyVal = key(newEntry);
  const idx = arr.findIndex((m) => key(m) === keyVal);
  const now = new Date().toISOString().slice(0, 10);
  let updated: ProfileMapping[];
  if (idx >= 0) {
    updated = [...arr];
    (updated[idx] as ProfileMapping).count = ((updated[idx] as ProfileMapping).count as number) + 1;
    (updated[idx] as ProfileMapping).last_used = now;
  } else {
    updated = [...arr, { ...newEntry, count: 1, last_used: now }];
  }
  updated.sort((a, b) => {
    const ac = (a.count as number) ?? 0;
    const bc = (b.count as number) ?? 0;
    if (bc !== ac) return bc - ac;
    return ((b.last_used as string) ?? "").localeCompare((a.last_used as string) ?? "");
  });
  return updated.slice(0, MAX_MAPPINGS);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const userId = user.id;
    if (!checkRateLimit(userId)) {
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
        { status: 429, headers: { "Content-Type": "application/json" } }
      );
    }

    const body: RecordRequest = await req.json();
    const { corrections } = body;

    if (!corrections || !Array.isArray(corrections) || corrections.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid request: corrections array required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch or create user_voice_profiles row
    const { data: profile, error: profileError } = await supabase
      .from("user_voice_profiles")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();

    if (profileError) {
      console.error("profile fetch error:", profileError);
      return new Response(
        JSON.stringify({ error: "Failed to load profile" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    let vocab = (profile?.vocabulary_aliases ?? []) as ProfileMapping[];
    let categoryMappings = (profile?.category_mappings ?? []) as ProfileMapping[];
    let storeAliases = (profile?.store_aliases ?? []) as ProfileMapping[];
    let timeHabits = (profile?.time_habits ?? []) as ProfileMapping[];

    for (const c of corrections) {
      if (!c.taskId || !c.fieldName) continue;

      // Insert into voice_corrections for audit
      await supabase.from("voice_corrections").insert({
        user_id: userId,
        task_id: c.taskId,
        field_name: c.fieldName,
        original_value: c.originalValue ?? null,
        corrected_value: c.correctedValue ?? null,
      });

      const orig = c.originalValue ?? "";
      const corr = c.correctedValue ?? "";

      switch (c.fieldName) {
        case "title": {
          const alias = extractVocabularyAlias(orig, corr);
          if (alias) {
            vocab = upsertMapping(
              vocab,
              (m) => `${(m as { spoken?: string }).spoken}:${(m as { canonical?: string }).canonical}`,
              { spoken: alias.spoken, canonical: alias.canonical } as ProfileMapping,
              "spoken"
            );
          }
          break;
        }
        case "category": {
          if (orig && corr) {
            categoryMappings = upsertMapping(
              categoryMappings,
              (m) => `${(m as { from?: string }).from}:${(m as { to?: string }).to}`,
              { from: orig, to: corr } as ProfileMapping,
              "from"
            );
          }
          break;
        }
        case "hasTime": {
          if (orig === "true" || orig === "false") {
            const pattern = corr === "true" ? "usually_has_time" : "usually_date_only";
            const cat = c.category ?? "General";
            timeHabits = upsertMapping(
              timeHabits,
              (m) => `${(m as { category?: string }).category}:${(m as { pattern?: string }).pattern}`,
              { category: cat, pattern } as ProfileMapping,
              "category"
            );
          }
          break;
        }
        default:
          break;
      }
    }

    // Upsert user_voice_profiles
    const now = new Date().toISOString();
    const row = {
      user_id: userId,
      vocabulary_aliases: vocab,
      category_mappings: categoryMappings,
      store_aliases: storeAliases,
      time_habits: timeHabits,
      updated_at: now,
    };

    const { error: upsertError } = await supabase
      .from("user_voice_profiles")
      .upsert(row, { onConflict: "user_id" });

    if (upsertError) {
      console.error("profile upsert error:", upsertError);
      return new Response(
        JSON.stringify({ error: "Failed to save profile" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("record-corrections error:", e);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
