const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

exports.generateSuggestions = onCall(async (request) => {
	// Require auth (since this is user-specific app behavior)
	if (!request.auth) {
		throw new HttpsError("unauthenticated", "Please sign in.");
	}

	const {
		category,
		stateTag,
		primaryMood,
		intensity,
		energy,
		tension,
		drivers = [],
	} = request.data || {};

	if (!category || !stateTag) {
		throw new HttpsError("invalid-argument", "Missing category or stateTag.");
	}

	const apiKey = process.env.OPENAI_API_KEY;
	if (!apiKey) {
		throw new HttpsError("failed-precondition", "OPENAI_API_KEY not set.");
	}

	const prompt = `
You are a supportive wellbeing assistant (not a therapist).
Generate 5 practical suggestions for category="${category}" tailored to:
stateTag="${stateTag}", primaryMood="${primaryMood}", intensity=${intensity}, energy=${energy}, tension=${tension},
drivers=${JSON.stringify(drivers)}.

Rules:
- No medical advice, no diagnosis.
- No extreme dieting, no alcohol/drugs.
- Output STRICT JSON with:
{"title": string, "items":[{"text":string,"time":"5/20/60 min","effort":"low/med/high"}]}
`;

	try {
		const resp = await fetch("https://api.openai.com/v1/responses", {
			method: "POST",
			headers: {
				Authorization: `Bearer ${apiKey}`,
				"Content-Type": "application/json",
			},
			body: JSON.stringify({
				model: "gpt-4.1-mini",
				input: prompt,
			}),
		});

		if (!resp.ok) {
			const txt = await resp.text();
			logger.error("OpenAI error", txt);
			throw new HttpsError("internal", "AI request failed.");
		}

		const data = await resp.json();

		// Responses API returns content in output; simplest is to ask for JSON and parse it from text.
		const text = JSON.stringify(data);
		// For v1, easiest: return raw and refine parsing next iteration
		return {
			title: "Suggestions",
			items: [{ text: "Parsing step next", time: "5 min", effort: "low" }],
		};
	} catch (e) {
		logger.error(e);
		throw new HttpsError("internal", "Failed to generate suggestions.");
	}
});
