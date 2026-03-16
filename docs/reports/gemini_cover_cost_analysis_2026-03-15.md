# Gemini Cover Cost Analysis - 2026-03-15

## Official pricing basis

Source:
- https://ai.google.dev/pricing

Relevant Gemini 2.5 Flash Image prices on the official Gemini API pricing page:
- Input: `$0.30 / 1,000,000 tokens`
- Output: `$0.039 / image`
- Pricing footnote: output images up to `1024x1024` consume `1290` output tokens, equivalent to `$30 / 1,000,000 output tokens`
- Free tier: **not available** for this image model on the official Gemini API pricing page

Batch pricing exists, but the current PASSAGETR cover pipeline does not use batch mode.

## Current PASSAGETR implementation

Current cover generation path:
- Function: `supabase/functions/admin_ai_generate_reading_cover/index.ts`
- Mode: standard synchronous `generateContent`
- Model: `gemini-2.5-flash-image`
- Shape: one generated cover attempt per request
- This means current production cost should be calculated with the **standard** pricing column, not batch pricing.

## Cost formula for our system

For one successful cover generation request:

`total_cost_usd ~= 0.039 + (input_tokens / 1_000_000 * 0.30)`

Because prompt input is short, output image cost dominates.

Practical rule of thumb:
- 1 cover generation attempt ~= `$0.039`
- Input token cost is usually negligible relative to image output cost

## Invoice-backed analysis

Observed billing data from the March 2026 invoice screenshots:
- Gemini 2.5 Flash Native Image Generation output usage: `1,050,417 output tokens`
- Output cost: `TRY 1,382.54`
- Image input usage: `149,395 input tokens`
- Input cost: `TRY 1.97`

Derived from official pricing:
- Output USD cost:
  - `1,050,417 / 1,000,000 * $30 = $31.51251`
- Input USD cost:
  - `149,395 / 1,000,000 * $0.30 = $0.0448185`
- Total USD:
  - `$31.5573285`

Invoice-implied FX rate:
- `TRY 1,384.51 / $31.5573285 ~= 43.87 TRY / USD`

## Why 250 ready covers still produced ~TRY 1.4k

Dashboard snapshot:
- Ready covers: `250`

But billed output-token usage corresponds to:
- `1,050,417 / 1290 ~= 814` image-equivalent outputs

That means billing reflects roughly:
- `814` generated image outputs
- not `250` currently persisted covers

So the cost is high because the system appears to have generated covers about:
- `814 / 250 ~= 3.26x`
more often than the number of covers currently visible as ready.

Most likely causes:
- repeated regeneration on the same readings
- failed persistence after a successful image generation call
- manual test generations
- batch retries and repeated run attempts
- replacing an existing cover, which generates a new billable image again

Important:
- `ready cover count` is a content state metric
- `billed image outputs` is an API usage metric
- these two numbers are not expected to match 1:1

## Estimated unit cost in PASSAGETR

Using official standard pricing and the invoice-implied FX:

### Ideal single-attempt cover
- Output cost per image: `$0.039`
- Approx TRY cost per image:
  - `0.039 * 43.87 ~= TRY 1.71`
- With prompt input included, practical estimate:
  - `~TRY 1.71 - TRY 1.72 / cover attempt`

### 250 one-pass covers
- `250 * $0.039 ~= $9.75`
- `~TRY 427 - TRY 430`

### 682 one-pass covers
- `682 * $0.039 ~= $26.598`
- `~TRY 1,166 - TRY 1,172`

### Remaining 432 missing covers
- `432 * $0.039 ~= $16.848`
- `~TRY 739 - TRY 742`

## Practical conclusion

The high March 2026 bill is not explained by the official per-image price being unexpectedly high.
It is explained by:
- using a paid image-generation API with **no free API tier**
- generating many more image outputs than the final ready-cover count

## Recommendation

If cover generation should remain low-cost:
- keep throttling and pause guards
- avoid repeated regenerate actions on the same reading
- add failed-only retry instead of full reruns
- add per-run estimated cost before start
- consider batch image generation pricing if Google exposes a usable batch workflow for this model in your pipeline
