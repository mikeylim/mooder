// server.js
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import admin from "firebase-admin";
import fs from "fs";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const suggestionSchema = {
	type: "OBJECT",
	properties: {
		title: { type: "STRING" },
		items: {
			type: "ARRAY",
			items: {
				type: "OBJECT",
				properties: {
					text: { type: "STRING" },
					time: { type: "STRING" },
					effort: { type: "STRING" },
				},
				required: ["text", "time", "effort"],
			},
		},
	},
	required: ["title", "items"],
};

// Add a request logger and verify the /health handler is reached
app.use((req, res, next) => {
	console.log("➡️", req.method, req.url);
	next();
});

// ✅ Firebase Admin init (service account JSON file)
const serviceAccount = JSON.parse(
	fs.readFileSync(process.env.FIREBASE_SERVICE_ACCOUNT_PATH, "utf8")
);

admin.initializeApp({
	credential: admin.credential.cert(serviceAccount),
});

// Helper: verify Firebase ID token
async function requireAuth(req) {
	const authHeader = req.headers.authorization || "";
	const match = authHeader.match(/^Bearer (.+)$/);
	if (!match) throw new Error("Missing Authorization Bearer token");
	const idToken = match[1];
	const decoded = await admin.auth().verifyIdToken(idToken);
	return decoded; // includes uid, email, etc.
}

function buildPrompt({ category, stateTag, primaryMood, intensity, energy, tension, drivers }) {
	return `
You are a supportive wellbeing assistant (not a therapist).
Generate 5 practical suggestions for category="${category}" tailored to:
stateTag="${stateTag}", primaryMood="${primaryMood}", intensity=${intensity}, energy=${energy}, tension=${tension},
drivers=${JSON.stringify(drivers)}.

Rules:
- No medical advice, no diagnosis.
- No extreme dieting, no alcohol/drugs.
- Keep each suggestion concrete and doable.
- Output STRICT JSON only:
{"title": string, "items":[{"text":string,"time":"5/20/60 min","effort":"low/med/high"}]}
`;
}

const CF_MODEL = "@cf/meta/llama-3.1-8b-instruct-fast";

function looksLikeGeminiQuotaError(status, bodyText) {
	// Gemini quota / rate-limit often shows as 429; sometimes other statuses with "quota"
	const s = (bodyText || "").toLowerCase();
	return (
		status === 429 || s.includes("quota") || s.includes("rate limit") || s.includes("exceeded")
	);
}

function safeJsonParseMaybe(text) {
	// Try direct parse first
	try {
		return JSON.parse(text);
	} catch (_) {}

	// Fallback: extract the first JSON object substring
	const match = text.match(/\{[\s\S]*\}/);
	if (match) {
		try {
			return JSON.parse(match[0]);
		} catch (_) {}
	}
	return null;
}
async function runCloudflareLlama({ prompt }) {
	const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
	const token = process.env.CLOUDFLARE_API_TOKEN;

	if (!accountId || !token) {
		throw new Error(
			"Cloudflare fallback not configured (missing CLOUDFLARE_ACCOUNT_ID/CLOUDFLARE_API_TOKEN)."
		);
	}

	const cfUrl = `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/run/${CF_MODEL}`;

	const cfResp = await fetch(cfUrl, {
		method: "POST",
		headers: {
			"Content-Type": "application/json",
			Authorization: `Bearer ${token}`,
		},
		body: JSON.stringify({
			messages: [
				{
					role: "system",
					content:
						"You output STRICT JSON only. No markdown, no commentary. Return only one JSON object.",
				},
				{ role: "user", content: prompt },
			],
			temperature: 0.6,
			max_tokens: 700,
		}),
	});

	const cfBodyText = await cfResp.text();
	if (!cfResp.ok) {
		throw new Error(`Cloudflare Workers AI failed (${cfResp.status}): ${cfBodyText}`);
	}

	const cfData = JSON.parse(cfBodyText);

	// Cloudflare model returns the assistant text in result.response (string)
	const text = cfData?.result?.response;
	if (!text || typeof text !== "string") {
		throw new Error("Cloudflare returned empty response.");
	}

	const parsed = safeJsonParseMaybe(text);
	if (!parsed) {
		throw new Error(`Cloudflare output parse failed. Raw:\n${text}`);
	}

	parsed.provider = "cloudflare";
	return parsed;
}

app.post("/suggestions", async (req, res) => {
	try {
		const user = await requireAuth(req);

		const {
			category,
			stateTag,
			primaryMood,
			intensity,
			energy,
			tension,
			drivers = [],
			selfHarmThoughts = false,
		} = req.body || {};

		if (selfHarmThoughts) {
			return res.status(200).json({
				title: "Safety mode",
				items: [
					{
						text: "If you're feeling at risk right now, consider contacting local emergency services or a trusted person.",
						time: "5 min",
						effort: "low",
					},
				],
			});
		}

		if (!category || !stateTag || !primaryMood) {
			return res.status(400).json({ error: "Missing required fields." });
		}

		const prompt = buildPrompt({
			category,
			stateTag,
			primaryMood,
			intensity,
			energy,
			tension,
			drivers,
		});

		const apiKey = process.env.GEMINI_API_KEY;
		if (!apiKey) {
			return res.status(500).json({ error: "GEMINI_API_KEY not set." });
		}

		const modelName = process.env.GEMINI_MODEL || "models/gemini-2.5-flash";
		const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/${modelName}:generateContent?key=${apiKey}`;
		console.log("Using Gemini model:", modelName);

		const geminiResp = await fetch(geminiUrl, {
			method: "POST",
			headers: { "Content-Type": "application/json" },
			body: JSON.stringify({
				contents: [{ role: "user", parts: [{ text: prompt }] }],
				generationConfig: {
					responseMimeType: "application/json",
					responseSchema: suggestionSchema,
					temperature: 0.6,
				},
			}),
		});

		// ✅ If Gemini fails due to quota/rate-limit, fallback to Cloudflare
		if (!geminiResp.ok) {
			const txt = await geminiResp.text();
			console.error("Gemini status:", geminiResp.status);
			console.error("Gemini body:", txt);

			if (looksLikeGeminiQuotaError(geminiResp.status, txt)) {
				console.warn("Gemini quota/rate-limit hit. Falling back to Cloudflare:", CF_MODEL);

				const cfParsed = await runCloudflareLlama({ prompt });
				return res.json(cfParsed);
			}

			return res.status(500).json({ error: "Gemini request failed." });
		}

		const data = await geminiResp.json();

		const text = data?.candidates?.[0]?.content?.parts
			?.map((p) => p.text)
			.join("\n")
			.trim();

		if (!text) {
			console.error("Gemini empty response:", JSON.stringify(data, null, 2));
			return res.status(500).json({ error: "Gemini returned empty response." });
		}

		let parsed;
		try {
			parsed = JSON.parse(text);
		} catch (e) {
			console.error("Failed to parse Gemini JSON text:", text);
			return res.status(500).json({ error: "Gemini output parse failed." });
		}

		parsed.provider = "gemini";
		return res.json(parsed);
	} catch (e) {
		console.error(e);
		return res.status(401).json({ error: e.message || "Unauthorized" });
	}
});

app.get("/health", (req, res) => {
	console.log("✅ health hit");
	res.status(200).json({ ok: true });
});

const port = process.env.PORT || 8787;
app.listen(port, "0.0.0.0", () => console.log(`Backend running on http://0.0.0.0:${port}`));
