import { createClient } from "jsr:@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: {
    id: string;
    task_id: string;
    owner_id: string;
    shared_with_id: string | null;
    shared_with_email: string | null;
    status: string;
    created_at: string;
  };
  schema: string;
  old_record: null | Record<string, unknown>;
}

// APNs HTTP/2 API endpoint
const APNS_PRODUCTION_URL = "https://api.push.apple.com";
const APNS_DEVELOPMENT_URL = "https://api.sandbox.push.apple.com";

async function sendAPNsNotification(
  deviceToken: string,
  bundleId: string,
  payload: Record<string, unknown>,
  jwt: string
): Promise<Response> {
  const isProduction = Deno.env.get("APNS_PRODUCTION") === "true";

  const url = isProduction
    ? `${APNS_PRODUCTION_URL}/3/device/${deviceToken}`
    : `${APNS_DEVELOPMENT_URL}/3/device/${deviceToken}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-priority": "10",
      "apns-push-type": "alert",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  return response;
}

async function createAPNsJWT(
  keyId: string,
  teamId: string,
  privateKeyPem: string
): Promise<string> {
  // Parse the PEM key to get the raw key bytes
  const keyData = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  
  const keyBytes = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

  // Import the private key
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    {
      name: "ECDSA",
      namedCurve: "P-256",
    },
    false,
    ["sign"]
  );

  // Create JWT payload (expires in 1 hour)
  const payload = {
    iss: teamId,
    iat: getNumericDate(new Date()),
  };

  // Create JWT
  const jwt = await create(
    { alg: "ES256", kid: keyId },
    payload,
    cryptoKey
  );

  return jwt;
}

Deno.serve(async (req: Request) => {
  try {
    const payload: WebhookPayload = await req.json();

    // Only process INSERT events where status is 'accepted'
    if (payload.type !== "INSERT" || payload.record.status !== "accepted") {
      return new Response(
        JSON.stringify({ message: "Ignored: not an accepted share" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { shared_with_id, task_id, owner_id } = payload.record;

    // Skip if recipient not resolved yet
    if (!shared_with_id) {
      return new Response(
        JSON.stringify({ message: "Recipient not resolved yet" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch task title
    const { data: task, error: taskError } = await supabase
      .from("tasks")
      .select("title")
      .eq("id", task_id)
      .single();

    if (taskError || !task) {
      console.error("Error fetching task:", taskError);
      return new Response(
        JSON.stringify({ error: "Task not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fetch sender's display name
    const { data: senderProfile } = await supabase
      .from("user_profiles")
      .select("display_name, email")
      .eq("id", owner_id)
      .single();

    const senderName = senderProfile?.display_name || 
                       senderProfile?.email?.split("@")[0] || 
                       "Someone";

    // Fetch recipient's device tokens
    const { data: deviceTokens, error: tokenError } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", shared_with_id)
      .eq("platform", "ios");

    if (tokenError) {
      console.error("Error fetching device tokens:", tokenError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch device tokens" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!deviceTokens || deviceTokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No device tokens found for recipient" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get APNs configuration
    const keyId = Deno.env.get("APNS_KEY_ID");
    const teamId = Deno.env.get("APNS_TEAM_ID");
    const privateKey = Deno.env.get("APNS_PRIVATE_KEY");
    const bundleId = Deno.env.get("APNS_BUNDLE_ID") || "com.jensen.docket";

    if (!keyId || !teamId || !privateKey) {
      console.error("Missing APNs configuration");
      return new Response(
        JSON.stringify({ error: "APNs not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Create JWT once for all notifications
    const jwt = await createAPNsJWT(keyId, teamId, privateKey);

    // Send push notification to all recipient's devices
    const results = await Promise.allSettled(
      deviceTokens.map(async ({ token }) => {
        const notification = {
          aps: {
            alert: {
              title: "Task Shared",
              body: `${senderName} shared "${task.title}" with you`,
            },
            sound: "default",
            badge: 1,
          },
          task_id: task_id, // Custom payload for navigation
        };

        const response = await sendAPNsNotification(token, bundleId, notification, jwt);
        
        if (!response.ok) {
          const errorText = await response.text();
          throw new Error(`APNs error: ${response.status} ${errorText}`);
        }
        
        return response;
      })
    );

    const successCount = results.filter((r) => r.status === "fulfilled").length;
    const failureCount = results.filter((r) => r.status === "rejected").length;

    if (failureCount > 0) {
      console.error("Some notifications failed:", results.filter((r) => r.status === "rejected"));
    }

    return new Response(
      JSON.stringify({
        message: `Sent ${successCount} notification(s), ${failureCount} failed`,
        successCount,
        failureCount,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error in push-share-notification:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
