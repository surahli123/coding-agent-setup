// x-research — deep research ANY topic via X/Twitter (the twitter CLI), fan-out → synthesize.
// Generalized 2026-06-13 from the successful agent-swarm research run (wf_ec0a6e3a-fec).
//
// WHAT: 4 parallel sonnet agents search X through 4 distinct LENSES of your topic, expand the
// best hits, then 1 opus agent synthesizes a cited summary. Mechanical work = sonnet, synthesis
// = opus (cost discipline). X-only (the twitter CLI), not WebSearch.
//
// INVOKE:
//   Workflow({ name: "x-research", args: "how are people doing prompt caching at scale" })
//   Workflow({ name: "x-research", args: { topic: "...", practitioners: ["karpathy","swyx"] } })

export const meta = {
  name: 'x-research',
  description: 'Deep-research any topic on X/Twitter via the twitter CLI: 4 parallel sonnet agents search through distinct lenses (consensus / builders / critiques / frontier), then one opus agent synthesizes a cited summary. Pass the topic as args (string) or args.topic.',
  phases: [
    { title: 'Search', detail: '4 parallel sonnet agents sweep X through 4 lenses of the topic' },
    { title: 'Synthesize', detail: 'one opus agent writes a cited summary' },
  ],
}

const topic = args ? (typeof args === 'string' ? args : (args.topic || args.question || '')) : ''
const practitioners = (args && typeof args === 'object' && Array.isArray(args.practitioners)) ? args.practitioners : []
if (!topic) {
  log('x-research: no topic provided. Pass args:"<your question>" or args:{topic:"..."}.')
  return { error: 'No topic. Invoke with args:"<research question>".' }
}

const TW = `TOOL: use the local twitter CLI ONLY (NOT WebSearch). Verified syntax:
  ~/.local/bin/twitter -c search "QUERY" -t top --min-likes 20          # -c=compact (global, before subcmd)
  ~/.local/bin/twitter -c search "QUERY" --from <handle>                # tweets from a specific account
  ~/.local/bin/twitter -c search "QUERY" --since 2026-04-01             # recency filter (YYYY-MM-DD)
  ~/.local/bin/twitter article -m <tweet-url>                           # fetch a Twitter Article's full text
Always wrap every call: timeout 90 ~/.local/bin/twitter ... </dev/null   (close stdin so it can't hang).
Compact search returns JSON [{id, author, text, likes, rts, time}]. Many high-signal tweets are just a t.co
link — note author+likes+gist; if a tweet clearly links a Twitter Article, fetch it with 'article -m'.
Form 2-4 queries combining the TOPIC with your LENS; vary keywords. Return raw structured findings only.`

const FIND_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          author: { type: 'string' },
          gist: { type: 'string', description: 'the claim/insight/pattern this tweet makes about the topic' },
          ref: { type: 'string', description: 'tweet id or url' },
          likes: { type: 'number' },
          relevance: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
        required: ['author', 'gist', 'relevance'],
      },
    },
  },
  required: ['findings'],
}

const SYNTH_SCHEMA = {
  type: 'object',
  properties: {
    summary: { type: 'string', description: 'the prose answer to the topic, grounded in the findings' },
    consensus: { type: 'array', items: { type: 'string' }, description: 'what most credible voices agree on' },
    disagreements: { type: 'array', items: { type: 'string' }, description: 'where credible voices conflict' },
    keyFindings: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' }, description: 'what is unresolved / under-discussed' },
    topSources: { type: 'array', items: { type: 'object', properties: { author: { type: 'string' }, why: { type: 'string' } }, required: ['author', 'why'] } },
  },
  required: ['summary', 'consensus', 'keyFindings', 'topSources'],
}

const fromHint = practitioners.length ? ` Known practitioners to try with --from: ${practitioners.join(', ')}.` : ''
const LENSES = [
  { key: 'consensus', lens: 'FOUNDATIONAL / CONSENSUS — broad keywords; what most credible people agree on; the canonical explanations and widely-shared threads.' },
  { key: 'builders', lens: `PRACTITIONERS / BUILDERS — what people actually BUILDING this say (concrete implementations, code, lessons learned). Prefer high-engagement hands-on accounts.${fromHint}` },
  { key: 'critiques', lens: 'CRITIQUES / FAILURES / GOTCHAS — skeptics, things that go wrong, failure modes, "X is overrated / here is why it breaks".' },
  { key: 'frontier', lens: 'RECENT / FRONTIER — newest developments and emerging patterns; use --since with a recent date to bias toward the last weeks/months.' },
]

phase('Search')
const found = (await parallel(LENSES.map(l => () =>
  agent(`Research this TOPIC on X/Twitter through ONE lens, return structured findings.\nTOPIC: ${topic}\nLENS: ${l.lens}\n\n${TW}`,
    { label: `x:${l.key}`, phase: 'Search', model: 'sonnet', schema: FIND_SCHEMA })
))).filter(Boolean)
const all = found.flatMap(r => r.findings || [])
log(`x-research "${topic.slice(0, 50)}": ${all.length} findings across ${LENSES.length} lenses`)

phase('Synthesize')
const synthesis = await agent(
  `Synthesize a cited research summary answering this TOPIC, grounded ONLY in the X/Twitter findings below. ` +
  `Be concrete and opinionated; separate consensus from disagreement; name the strongest sources; flag what's ` +
  `still unresolved. Do not invent claims not supported by the findings.\n\nTOPIC: ${topic}\n\nFINDINGS (json):\n` +
  `${JSON.stringify(all).slice(0, 12000)}`,
  { label: 'synthesize', phase: 'Synthesize', model: 'opus', schema: SYNTH_SCHEMA }
)

return { topic, synthesis, stats: { findings: all.length, lenses: LENSES.length } }
