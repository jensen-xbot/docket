// @ts-nocheck — Deno Edge Function; jsr: imports resolve at deploy time
import { createClient } from "jsr:@supabase/supabase-js@2";

interface ConversationMessage {
  role: "user" | "assistant";
  content: string;
}

interface ParsedTask {
  id: string;
  title: string;
  dueDate?: string; // ISO 8601: "yyyy-MM-dd" (date only) or "yyyy-MM-ddTHH:mm" (with time)
  priority: "low" | "medium" | "high";
  category?: string;
  notes?: string;
  shareWith?: string; // email or display name
  suggestion?: string;
  checklistItems?: string[]; // AI-suggested item names (ad-hoc grocery list)
  useTemplate?: string; // store name whose template to load (template-based grocery list)
  recurrenceRule?: string; // "daily", "weekly", "monthly" — null = not recurring
}

interface TaskContext {
  id: string; // UUID as string
  title: string;
  dueDate?: string; // ISO 8601: "yyyy-MM-dd" or "yyyy-MM-ddTHH:mm"
  priority: "low" | "medium" | "high";
  category?: string;
  isCompleted: boolean;
  progressPercentage: number;
  isProgressEnabled: boolean;
  recurrenceRule?: string; // "daily", "weekly", "monthly"
}

interface TaskChanges {
  title?: string;
  dueDate?: string; // ISO 8601: "yyyy-MM-dd" or "yyyy-MM-ddTHH:mm"
  priority?: "low" | "medium" | "high";
  category?: string;
  notes?: string;
  isCompleted?: boolean;
  isPinned?: boolean; // Pin/unpin task
  addChecklistItems?: string[]; // Add items to existing checklist
  removeChecklistItems?: string[]; // Remove items from checklist (by name)
  starChecklistItems?: string[]; // Star items (mark as important/heart)
  unstarChecklistItems?: string[]; // Unstar items
  checkChecklistItems?: string[]; // Check items (mark as done)
  uncheckChecklistItems?: string[]; // Uncheck items
  progressPercentage?: number; // "set progress on X to 75%", "update my report to 50% done"
  isProgressEnabled?: boolean; // "switch X to progress tracking", "enable progress on X"
  recurrenceRule?: string | null; // "daily", "weekly", "monthly" — null = turn off recurring
}

interface GroceryStoreContext {
  name: string;
  itemCount: number;
}

interface VoicePersonalization {
  vocabularyAliases?: Array<{ spoken: string; canonical: string }>;
  categoryMappings?: Array<{ from: string; to: string }>;
  storeAliases?: Array<{ spoken: string; canonical: string }>;
  timeHabits?: Array<{ category: string; pattern: string }>;
}

interface ParseRequest {
  messages: ConversationMessage[];
  today: string; // ISO 8601 date (yyyy-MM-dd)
  timezone: string; // IANA timezone (e.g., "America/New_York")
  contacts?: string[]; // Optional list of contact emails
  existingTasks?: TaskContext[]; // User's current tasks for context
  groceryStores?: GroceryStoreContext[]; // User's grocery store templates
  personalization?: VoicePersonalization; // Learned preferences from corrections
}

interface ParseResponse {
  type: "question" | "complete" | "update" | "delete";
  text?: string; // Follow-up question (when type == "question")
  tasks?: ParsedTask[]; // Extracted tasks (when type == "complete")
  taskId?: string; // Existing task ID (when type == "update" or "delete")
  changes?: TaskChanges; // Fields to change (when type == "update")
  summary?: string; // TTS readback text (when type == "complete", "update", or "delete")
  confidence?: "high" | "medium" | "low"; // Confidence level of the parse
}

const SYSTEM_PROMPT = `You are Docket's voice assistant. Help users create, update, and manage tasks through natural conversation. You speak via text-to-speech, so keep responses short and natural.

CRITICAL: Your response MUST be a JSON object with a "type" field set to EXACTLY "question", "complete", "update", or "delete". No other type values are allowed.

CONFIDENCE SCORING: Every response MUST include a "confidence" field set to "high", "medium", or "low" based on how well the user's intent was understood:
- "high": Clear action verb + clear object/task + explicit date + no sharing intent
  Examples: "Call mom tomorrow high priority", "Submit report by Friday 3pm"
- "medium": Vague title OR inferred priority OR relative date (next week, this weekend) OR share target mentioned OR minor ambiguity
  Examples: "meeting with Sarah", "Costco run next week share with Mike", "do something important"
- "low": Missing critical info (no clear title OR no date when one seems needed) OR high ambiguity OR incomplete task description
  Examples: "add a task", "remind me", "do that thing"

For updates and deletes: confidence is "high" if the task is clearly matched, "medium" if fuzzy matched, "low" if uncertain which task.

Behavior:
- TASK AWARENESS: You have access to the user's existing tasks (provided in the context). When the user asks to modify, complete, or delete a task, match it by title (fuzzy matching is fine — "dentist" matches "Dentist appointment") and return the appropriate type.
- GROCERY AWARENESS: You have access to the user's grocery store templates (provided in the context). When the user mentions groceries, shopping, or a store name, check if stores exist in context. If stores exist, ask which store or suggest using a template. If the user names a store with a template, ask if they want to use it. If the user confirms ("yes"), return type "complete" with useTemplate set to the store name and category set to "Groceries". If the user wants specific items only (e.g., "just milk, eggs, bread"), return type "complete" with checklistItems set to those item names and category set to "Groceries". Always set category to "Groceries" for grocery-related tasks.
- CHECKLIST OPERATIONS: When the user wants to modify a task's checklist (grocery list), use type "update" with the appropriate changes fields:
  - "add banana and frozen yogurt" → addChecklistItems: ["banana", "frozen yogurt"]
  - "remove milk" or "delete milk" → removeChecklistItems: ["milk"]
  - "mark banana as important" or "star banana" or "heart banana" → starChecklistItems: ["banana"]
  - "unstar milk" or "remove star from milk" → unstarChecklistItems: ["milk"]
  - "check off milk" or "mark milk as done" → checkChecklistItems: ["milk"]
  - "uncheck milk" → uncheckChecklistItems: ["milk"]
- PINNING: "pin this task" or "pin the grocery task" → isPinned: true, "unpin it" → isPinned: false
- PROGRESS: When the user wants to set progress on a task ("set progress on my report to 75%", "update the dentist task to 50% done", "I'm halfway through the client email"), return type "update" with changes.progressPercentage set to the number (0-100). When the user wants to enable progress tracking ("switch X to progress tracking", "enable progress on X", "turn on progress for X"), return type "update" with changes.isProgressEnabled = true. If they say "how far along am I on X?" and the task has isProgressEnabled, include the progress in your answer from the context.
- If the user asks about their tasks ("what do I have tomorrow?", "show me my tasks"), return type "question" with a helpful summary listing matching tasks from the context. When listing tasks that have isProgressEnabled, include the progress percentage (e.g., "Report is 45% done").
- If the user wants to CREATE a new task and provides enough info, return type "complete" with structured tasks and a TTS summary.
- If the user wants to UPDATE an existing task (mark done, change date, change priority, add notes, modify checklist, pin/unpin), return type "update" with the taskId and changes.
- If the user wants to DELETE a task, return type "delete" with the taskId.
- If critical info is missing (at minimum: a task title for creation, or which task for update/delete), return type "question" with a short follow-up question.
- If the user says a greeting (hi, hey, hello) or something vague, return type "question" with a warm greeting back + ask what they'd like to do. Use the timezone to determine time of day: before 12pm = "Good morning!", 12-5pm = "Good afternoon!", after 5pm = "Good evening!". Example: "Good evening! What can I help you with?"
- Keep responses natural and conversational, but concise (2-3 sentences). Use friendly phrases like "I created X for you", "I've marked Y as done", "I've deleted Z", "Done! Anything else?" to make it feel personal and helpful.
- CLOSING QUESTION: After every update, delete, or complete response, ALWAYS end your summary with "Will this be all?" or "Anything else?" so the user can naturally continue or end the conversation. E.g. "I've updated X to 70%. Will this be all?" or "I've marked Y as done. Anything else?"
- Be conversational but efficient. Don't ask about optional fields unless the user seems to want detail or says something vague.
- Accept corrections naturally ("actually make it Wednesday", "never mind the note", "change priority to low").
- When the user confirms ("yes" / "add it" / "sounds good"), finalize.
- If the user provides everything in one utterance, skip questions entirely and return the appropriate type immediately.
- CORRECTIONS AFTER SAVE: If the conversation shows a task was already created (assistant said "Done!" or "Added!") and the user says something like "actually make it 3pm" or "change it to Wednesday", return the SAME task with corrected fields (same title, updated fields). Do NOT create a brand new task — this is a correction to the previously saved one. Use the summary to say "Updated" not "Adding".

Response format — ALWAYS one of these four, INCLUDING the confidence field:

1. Follow-up question:
{"type": "question", "text": "Your short question here", "confidence": "low"}

2. Completed task(s) (new tasks):
{"type": "complete", "tasks": [...], "summary": "TTS readback sentence", "confidence": "high"}

3. Update existing task (change fields, mark done/complete, modify checklist, pin/unpin, progress, recurrence, etc.):
{"type": "update", "taskId": "uuid-of-existing-task", "changes": {"priority": "high", "dueDate": "2026-02-10", "recurrenceRule": "weekly", "isPinned": true, "progressPercentage": 75, "isProgressEnabled": true, "addChecklistItems": ["banana"], "starChecklistItems": ["milk"], ...}, "summary": "I've updated the task", "confidence": "high"}

4. Mark task as done/complete (this is an UPDATE, NOT type "complete"):
{"type": "update", "taskId": "uuid-of-existing-task", "changes": {"isCompleted": true}, "summary": "I've marked X as done", "confidence": "high"}

5. Delete existing task:
{"type": "delete", "taskId": "uuid-of-existing-task", "summary": "I've deleted the task", "confidence": "high"}

IMPORTANT: "mark as done", "mark as complete", "I finished X", "X is done" → use type "update" with changes.isCompleted = true. Do NOT use type "complete" for this — type "complete" is ONLY for creating new tasks.

For each task in a "complete" response, return:
- title: Clear, concise task title (action-oriented)
- dueDate: If the user specifies a TIME (e.g., "at 9am", "by 3pm", "in the morning"), use datetime format "yyyy-MM-ddTHH:mm" (e.g., "2026-02-09T09:00"). If NO time is mentioned, use date-only format "yyyy-MM-dd" (e.g., "2026-02-09"). Set to null if no date mentioned.
- priority: "low", "medium", or "high"
- category: Suggested category or null (always set to "Groceries" for grocery tasks)
- notes: Additional context/details from the user, or null
- shareWith: Email or display name to share with, or null. When shareWith is present, the summary MUST ask for confirmation — do NOT say "Done!" or "Added!". Use: "I'll share this with [name]. How would you like to send it? Docket, email, or text." This lets the user choose the share method before the task is created.
- suggestion: Optional improvement note for the user
- checklistItems: Array of item names (only for ad-hoc grocery lists, e.g., ["milk", "eggs", "bread"])
- useTemplate: Store name whose template to load (only when user confirms using a template, e.g., "Costco")
- recurrenceRule: If the user says "every day", "daily", "weekly", "every week", "every Monday", "monthly", "every month", set accordingly. Use "daily", "weekly", or "monthly". Omit or null if not recurring.

Extraction rules:
- Split compound sentences into separate tasks
- Infer priority from urgency words (urgent/ASAP/important = high)
- Infer due dates from relative terms (tomorrow, next week, Friday)
- Suggest a category based on context (Work, Personal, Health, Family, Finance, Shopping)
- Today's date is provided for relative date calculation
- If unsure about a field, use sensible defaults (medium priority, no due date)
- Extract notes from phrases like "note that...", "remember to...", "because...", "she said...", "make sure to..."
- Extract share targets from "share with...", "send to...", "assign to..."
- Do NOT fabricate notes or sharing intent — only extract what was said

Return valid JSON only. No markdown, no explanation.`;

// Simple in-memory rate limit: 60 requests per hour per user
const RATE_LIMIT = 60;
const WINDOW_MS = 60 * 60 * 1000; // 1 hour
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

    // Rate limit: 60 requests per hour per user
    const userId = user.id;
    if (!checkRateLimit(userId)) {
      return new Response(
        JSON.stringify({ error: "Rate limit exceeded. Try again later." }),
        { status: 429, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse request body
    const body: ParseRequest = await req.json();
    const { messages, today, timezone, contacts, existingTasks, groceryStores, personalization } = body;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid request: messages array required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get OpenRouter API key
    const openRouterApiKey = Deno.env.get("OPENROUTER_API_KEY");
    if (!openRouterApiKey) {
      return new Response(
        JSON.stringify({ error: "OpenRouter API key not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const model = Deno.env.get("OPENROUTER_MODEL") || "openai/gpt-4.1-mini";

    // Build system prompt with task context
    let systemContent = `${SYSTEM_PROMPT}\n\nToday's date: ${today}\nTimezone: ${timezone}`;
    
    if (existingTasks && existingTasks.length > 0) {
      const taskList = existingTasks.map((t) => {
        const dueDateStr = t.dueDate ? ` (due: ${t.dueDate})` : "";
        const categoryStr = t.category ? ` [${t.category}]` : "";
        const statusStr = t.isCompleted ? " [completed]" : "";
        const progressStr = t.isProgressEnabled ? ` [${t.progressPercentage}% progress]` : "";
        const recurStr = t.recurrenceRule ? ` [recurring: ${t.recurrenceRule}]` : "";
        return `- ${t.title}${dueDateStr}${categoryStr}${progressStr}${recurStr}${statusStr} (id: ${t.id})`;
      }).join("\n");
      
      systemContent += `\n\nUser's existing tasks:\n${taskList}\n\nWhen the user asks to modify, complete, or delete a task, match it by title and use the task's id in your response.`;
    }
    
    if (groceryStores && groceryStores.length > 0) {
      const storeList = groceryStores.map((s) => {
        return `- ${s.name} (${s.itemCount} items)`;
      }).join("\n");
      
      systemContent += `\n\nUser's grocery store templates:\n${storeList}\n\nWhen the user mentions groceries or shopping, check these stores. If they name a store, ask if they want to use the template. If they confirm, return useTemplate set to the store name.`;
    }
    
    if (personalization) {
      const lines: string[] = [];
      const vocab = personalization.vocabularyAliases as Array<{ spoken?: string; canonical?: string }> | undefined;
      if (vocab && vocab.length > 0) {
        // Group aliases by canonical form so the AI sees all known variants together
        // e.g. "Tuftek"/"Tuftec" → "TuffTek" instead of two separate entries
        const grouped = new Map<string, string[]>();
        for (const v of vocab) {
          if (!v?.spoken || !v?.canonical) continue;
          const existing = grouped.get(v.canonical) ?? [];
          existing.push(v.spoken);
          grouped.set(v.canonical, existing);
        }
        const groupedPairs: string[] = [];
        for (const [canonical, spokenForms] of grouped) {
          const quoted = spokenForms.map((s) => `"${s}"`).join("/");
          groupedPairs.push(`${quoted} → "${canonical}"`);
        }
        if (groupedPairs.length > 0) lines.push(`- Vocabulary corrections: ${groupedPairs.join(", ")}`);
      }
      const catMap = personalization.categoryMappings as Array<{ from?: string; to?: string }> | undefined;
      if (catMap && catMap.length > 0) {
        const pairs = catMap
          .filter((c) => c?.from && c?.to)
          .map((c) => `"${c.from}" → "${c.to}"`);
        if (pairs.length > 0) lines.push(`- Categories: User prefers ${pairs.join(", ")}`);
      }
      const stores = personalization.storeAliases as Array<{ spoken?: string; canonical?: string }> | undefined;
      if (stores && stores.length > 0) {
        // Group store aliases by canonical form too
        const grouped = new Map<string, string[]>();
        for (const s of stores) {
          if (!s?.spoken || !s?.canonical) continue;
          const existing = grouped.get(s.canonical) ?? [];
          existing.push(s.spoken);
          grouped.set(s.canonical, existing);
        }
        const groupedPairs: string[] = [];
        for (const [canonical, spokenForms] of grouped) {
          const quoted = spokenForms.map((s) => `"${s}"`).join("/");
          groupedPairs.push(`${quoted} → "${canonical}"`);
        }
        if (groupedPairs.length > 0) lines.push(`- Stores: ${groupedPairs.join(", ")}`);
      }
      const habits = personalization.timeHabits as Array<{ category?: string; pattern?: string }> | undefined;
      if (habits && habits.length > 0) {
        const habStrs = habits
          .filter((t) => t?.category && t?.pattern)
          .map((t) => `${t.category} tasks: ${t.pattern === "usually_has_time" ? "usually include a specific time" : "usually date-only"}`);
        if (habStrs.length > 0) lines.push(`- Time habits: ${habStrs.join("; ")}`);
      }
      if (lines.length > 0) {
        systemContent += `\n\nUSER PREFERENCES (learned from past corrections — ALWAYS apply these):\n${lines.join("\n")}\nThese corrections come from speech-to-text which often produces variant spellings of the same spoken word. Apply these even when the transcription is only phonetically similar (e.g. if "Tuftek" → "TuffTek" is listed, also correct "Tuftec", "Tuftech", "Tough Tech" to "TuffTek"). Use the canonical spelling in all task fields. Do not mention these corrections to the user.`;
      }
    }
    
    // Build chat completion request
    const chatMessages = [
      {
        role: "system",
        content: systemContent,
      },
      ...messages.map((msg) => ({
        role: msg.role,
        content: msg.content,
      })),
    ];

    // Call OpenRouter with 15s timeout
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 15000);
    let openRouterResponse: Response;
    try {
      openRouterResponse = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        signal: controller.signal,
        headers: {
          "Authorization": `Bearer ${openRouterApiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": supabaseUrl, // Optional: for OpenRouter analytics
          "X-Title": "Docket Voice Assistant",
        },
        body: JSON.stringify({
          model,
          messages: chatMessages,
          response_format: { type: "json_object" },
          temperature: 0.7,
        }),
      });
    } catch (e) {
      clearTimeout(timeoutId);
      if (e instanceof Error && e.name === "AbortError") {
        return new Response(
          JSON.stringify({ error: "Request timed out. Please try again." }),
          { status: 504, headers: { "Content-Type": "application/json" } }
        );
      }
      throw e;
    }
    clearTimeout(timeoutId);

    if (!openRouterResponse.ok) {
      const errorText = await openRouterResponse.text();
      console.error("OpenRouter error:", errorText);
      return new Response(
        JSON.stringify({ error: "AI service unavailable" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    const openRouterData = await openRouterResponse.json();
    const aiContent = openRouterData.choices?.[0]?.message?.content;

    if (!aiContent) {
      return new Response(
        JSON.stringify({ error: "Invalid AI response" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    // Parse AI response as JSON
    let parseResponse: ParseResponse;
    try {
      parseResponse = JSON.parse(aiContent);
    } catch (e) {
      console.error("Failed to parse AI response:", e, aiContent);
      return new Response(
        JSON.stringify({ error: "Invalid AI response format" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      );
    }

    // Normalize response type — if the AI returns an unexpected type
    // (e.g., "greeting", "clarification"), coerce it to "question" so
    // the client always gets a valid response instead of an error.
    const validTypes = ["question", "complete", "update", "delete"];
    if (!validTypes.includes(parseResponse.type)) {
      console.warn("AI returned unexpected type:", parseResponse.type, "— coercing to question");
      // Try to extract a usable text response from whatever the AI returned
      const fallbackText = parseResponse.text
        || (parseResponse as any).message
        || (parseResponse as any).response
        || "What would you like to do?";
      parseResponse = { type: "question", text: fallbackText };
    }

    // Ensure tasks have IDs if present
    if (parseResponse.tasks) {
      parseResponse.tasks = parseResponse.tasks.map((task) => ({
        ...task,
        id: task.id || crypto.randomUUID(),
      }));
    }

    // Return response
    return new Response(JSON.stringify(parseResponse), {
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
