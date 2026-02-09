// @ts-nocheck — Deno Edge Function; jsr: imports resolve at deploy time
import { createClient } from "jsr:@supabase/supabase-js@2";

interface TranscribeRequest {
  audio: string; // Base64-encoded WAV audio data
}

interface TranscribeResponse {
  text: string;
}

Deno.serve(async (req: Request) => {
  // CORS headers
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
    // Verify JWT
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

    // Verify the user is authenticated
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

    // Parse request body
    const body: TranscribeRequest = await req.json();
    const { audio } = body;

    if (!audio || typeof audio !== "string") {
      return new Response(
        JSON.stringify({ error: "Invalid request: audio (base64) required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get OpenAI API key for Whisper transcription
    // Note: Whisper uses OpenAI's /v1/audio/transcriptions endpoint directly.
    // OpenRouter doesn't proxy Whisper, so we use OpenAI API key here.
    // Cost: ~$0.006/minute of audio (~$0.001 per typical utterance)
    // Set OPENAI_API_KEY in Supabase Edge Function secrets (same place as OPENROUTER_API_KEY)
    const openaiApiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openaiApiKey) {
      return new Response(
        JSON.stringify({ error: "OpenAI API key not configured. Set OPENAI_API_KEY in Supabase Edge Function secrets." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Decode base64 audio
    const audioBuffer = Uint8Array.from(atob(audio), (c) => c.charCodeAt(0));

    // Create FormData for multipart/form-data request
    const formData = new FormData();
    const audioBlob = new Blob([audioBuffer], { type: "audio/wav" });
    formData.append("file", audioBlob, "audio.wav");
    formData.append("model", "whisper-1");
    formData.append("language", "en"); // English only for v1.1

    // Call OpenAI Whisper API
    const whisperResponse = await fetch("https://api.openai.com/v1/audio/transcriptions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${openaiApiKey}`,
      },
      body: formData,
    });

    if (!whisperResponse.ok) {
      const errorText = await whisperResponse.text();
      console.error("OpenAI Whisper error:", errorText);
      return new Response(
        JSON.stringify({ error: "Transcription service unavailable" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    const whisperData = await whisperResponse.json();
    const transcribedText = whisperData.text || "";

    // Return response
    const response: TranscribeResponse = { text: transcribedText };
    return new Response(JSON.stringify(response), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
