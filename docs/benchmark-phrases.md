---
name: "Japan Voice App — v1 Benchmark Phrases"
type: benchmark
status: active
links:
  - "[[designs/v1-shell]]"
---

# v1 Benchmark Phrases

Ten bilingual phrase pairs used as the v1 acceptance check for OpenAI Realtime Japanese accuracy. First time you wire the realtime session, run these both directions and ask: did it translate intent, not just keywords?

If accuracy on this set is marginal (you regularly repeat yourself, or the translation misses the intent), that is the trigger to consider pivoting the provider pipeline (Approach B: separate STT + translate, documented in `docs/designs/v1-shell.md`). Don't trust "it worked on the example I happened to say" — trust this fixed yardstick.

## How to run the benchmark

1. Start a conversation session in the app.
2. For each phrase below, speak the source-language side. Verify the translated text on the opposite side conveys the intent, not just a word-for-word mapping.
3. Flip direction (swipe handoff) and speak the target-language side. Verify same.
4. Log any phrase that gets translated poorly, is misrecognized at the STT layer, or takes longer than ~1.5s to render the first text delta.
5. A passing v1 means at least 8/10 phrases translate cleanly in both directions.

## Phrases

| # | Category | English | Japanese (for reference — speak naturally) |
|---|----------|---------|--------------------------------------------|
| 1 | Station directions | "Excuse me, where's the nearest train station?" | すみません、一番近い駅はどこですか？ |
| 2 | Station directions | "How many minutes does it take to walk there?" | そこまで歩いて何分かかりますか？ |
| 3 | Restaurant — ordering | "What do you recommend?" | おすすめは何ですか？ |
| 4 | Restaurant — dietary | "I'm allergic to shellfish. Is there shellfish in this?" | 甲殻類アレルギーがあります。これに甲殻類は入っていますか？ |
| 5 | Counter / money | "Can I pay by card?" | カードで払えますか？ |
| 6 | Counter / money | "Keep the change, thank you." | お釣りは結構です、ありがとうございます。 |
| 7 | Small talk | "Where are you from?" | ご出身はどちらですか？ |
| 8 | Small talk | "This is my first time in Japan. I love it." | 日本に来るのは初めてです。とても気に入っています。 |
| 9 | Apology / misunderstanding | "I'm sorry, I didn't understand. Could you say that again slowly?" | すみません、わかりませんでした。もう一度ゆっくり言っていただけますか？ |
| 10 | Emergency / help | "I need a doctor. My friend isn't feeling well." | 医者が必要です。友達の具合が悪いです。 |

## What to look for beyond "did it translate"

- **Latency** — first text delta should start streaming within ~700ms of the end of utterance. If it's > 1.5s, the "realtime" wedge from `vision.md` is in trouble.
- **Interim vs final transcripts** — does the UI handle the model correcting itself mid-stream without jitter?
- **Politeness register** — Japanese has layered formality (keigo, teineigo, tameguchi). The model should default to polite (です/ます) for travel contexts. If it drops into casual, note it.
- **Homophones and proper nouns** — station names, food names, place names. Phrase #1 and #2 pressure this; add local station names in your actual test (e.g., "Shinjuku", "Kiyomizu-dera") to see how they round-trip.
- **Reverse direction quality** — JA→EN is often worse than EN→JA on conversational Japanese models. Don't skip the reverse leg.
