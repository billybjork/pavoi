# TikTok Live Stream Comment Analysis

You are analyzing comments from a TikTok Live shopping stream for a jewelry brand (PAVOI). Your task is to extract **specific, unique insights** from this particular stream's comments.

## Context
- **Platform**: TikTok Live shopping stream
- **Brand**: PAVOI (affordable, high-quality costume jewelry)
- **Comment format**: Each comment includes the username and their message
- **Note**: Flash sale/promotional comments have already been filtered out

## Your Task

Find insights that are **specific to this stream** - things that wouldn't apply to every stream. Skip generic observations like "viewers are excited" or "people are buying things."

Look for:
- Specific product concerns or complaints (with product numbers if mentioned)
- Unusual questions or requests that came up multiple times
- Specific quality issues mentioned
- Requests for products/features not currently offered
- Notable negative feedback that needs addressing

## Format Requirements

Return 3-5 bullet points maximum. Each bullet MUST include at least one example comment on a separate indented line.

Format each bullet EXACTLY like this (note the newline and indentation for examples):
- [Insight description]
  - *@username*: "their actual comment"

If multiple examples, add each on its own indented line:
- [Insight description]
  - *@username1*: "comment one"
  - *@username2*: "comment two"

## Guidelines

- Be specific: "3 viewers asked about ring size 8" is better than "sizing questions came up"
- Skip the obvious: Don't mention that people are happy or buying things - that's expected
- Cite evidence: Every insight needs a real example comment from the data
- Only include notable patterns: If something only came up once, it's probably not worth mentioning
- Product numbers matter: If viewers reference specific numbers (#4, "number 12"), include them

## Example Output

- Tarnishing concerns for rings specifically - 3 viewers mentioned rings tarnishing quickly
  - *@Cari9394*: "Why did my ring tarnish after wearing it only two days"
- Requests for size 8 bracelets - multiple viewers with larger wrists asking for 8" options
  - *@Diana Touchet*: "Do u have any in an 8?"
- Interest in the black clover bracelet being restocked
  - *@myfavfindz*: "I thought the clover would go on flash sale :("

---

Now analyze the following comments:
