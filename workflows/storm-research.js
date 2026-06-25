export const meta = {
  name: 'storm-research',
  description: 'STORM: retrieval-grounded, multi-perspective research/brainstorm. Modes A=writing-research B=deep-research C=decision/eval-prep. Adds the real "R" (retrieval/grounding) the viral 4-prompt version drops.',
  whenToUse: 'args:{mode:"A"|"B"|"C", topic, groundingFiles?:[paths], deliverable?, useUGC?:bool, date}. Personas ground in the provided local files and/or fresh UGC (twitter/opencli), never the model\'s memory alone. Returns {mode, researchQuestion, personas, groundedViews, contradictionMap, synthesis, peerReview, telemetry, incomplete?}. The CALLER writes the .md artifacts (scripts have no FS access).',
  phases: [
    { title: 'Scope' },
    { title: 'Ground' },
    { title: 'Contradict' },
    { title: 'Synthesize' },
    { title: 'PeerReview' },
  ],
}

// ---- defensive args parse (args can arrive as a bare string or stringified JSON) ----
let A = args
if (typeof A === 'string') { try { A = JSON.parse(A) } catch (e) { A = { topic: args } } }
A = A || {}
const MODE = String(A.mode || 'A').toUpperCase()
const TOPIC = A.topic || '(no topic provided)'
const GROUNDING_FILES = Array.isArray(A.groundingFiles) ? A.groundingFiles : (A.groundingFiles ? [A.groundingFiles] : [])
const USE_UGC = A.useUGC === true // default OFF — only reach external UGC when explicitly asked
const DELIVERABLE = A.deliverable || (MODE === 'A' ? 'a piece of writing (e.g. an X thread)' : MODE === 'C' ? 'a decision briefing' : 'a research report')
const DATE = A.date || 'undated'

const MODE_FRAME = ({
  A: 'WRITING-RESEARCH: produce research material + sharp angles + a suggested structure to feed a drafting step. SCAFFOLD, do NOT ghostwrite finished prose.',
  B: 'DEEP-RESEARCH: produce a thorough, multi-perspective, source-grounded report.',
  C: 'DECISION/EVAL-PREP: produce 5-perspective analysis + a reliability score + ONE specific recommended action with caveats.',
})[MODE] || 'WRITING-RESEARCH (default)'

const GROUND_NOTE = GROUNDING_FILES.length
  ? 'Read these local grounding files FIRST (Read tool) and base your evidence on them; cite by file path + a short quote:\n' + GROUNDING_FILES.map(f => '  - ' + f).join('\n')
  : 'No local grounding files were provided.'
const UGC_NOTE = USE_UGC
  ? 'You may ALSO ground via fresh UGC: twitter CLI ( ~/.local/bin/twitter search "<q>" -c </dev/null ) and opencli/autocli for Reddit/HN/X threads. Prefer first-hand voices over generic web; cite URLs.'
  : 'Do NOT use external web/UGC search — ground ONLY in the provided files. If a claim cannot be grounded in them, omit it (do not invent citations).'

log('storm-research mode=' + MODE + ' | groundingFiles=' + GROUNDING_FILES.length + ' | useUGC=' + USE_UGC + ' | deliverable=' + DELIVERABLE)

// ============================== Scope ==============================
phase('Scope')
const SCOPE_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    researchQuestion: { type: 'string' },
    personas: {
      type: 'array', minItems: 4, maxItems: 6,
      items: {
        type: 'object', additionalProperties: false,
        properties: {
          name: { type: 'string' },
          lens: { type: 'string', description: 'what this persona uniquely sees that others miss' },
          seedArchetype: { type: 'string', enum: ['Practitioner', 'Academic', 'Skeptic', 'Economist', 'Historian', 'Other'] },
        },
        required: ['name', 'lens', 'seedArchetype'],
      },
    },
  },
  required: ['researchQuestion', 'personas'],
}
const scope = await agent(
  'You are the SCOPE agent for a STORM-style task.\nMode: ' + MODE_FRAME + '\nTopic / brief: ' + TOPIC + '\nDeliverable: ' + DELIVERABLE + '\n' + GROUND_NOTE + '\n\nDefine (1) a sharp researchQuestion the deliverable should answer, and (2) 4-6 TOPIC-ADAPTIVE personas, each seeded by one STORM archetype (Practitioner / Academic / Skeptic / Economist / Historian) but specialized to THIS topic. Personas must genuinely see different things (no near-duplicates). Return the schema.',
  { label: 'scope', phase: 'Scope', schema: SCOPE_SCHEMA })

if (!scope || !Array.isArray(scope.personas) || !scope.personas.length) {
  return { mode: MODE, incomplete: true, reason: 'Scope failed — no personas produced.', telemetry: { stage: 'scope', date: DATE } }
}

// ============================== Ground ==============================
phase('Ground')
const VIEW_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    persona: { type: 'string' },
    coreStance: { type: 'string' },
    strongestEvidence: { type: 'string' },
    theOneThingOthersWontSay: { type: 'string' },
    citations: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, properties: { claim: { type: 'string' }, source: { type: 'string' }, quote: { type: 'string' } }, required: ['claim', 'source'] },
    },
    sourcesUsed: { type: 'integer', description: 'count of distinct sources you actually grounded in' },
  },
  required: ['persona', 'coreStance', 'strongestEvidence', 'theOneThingOthersWontSay', 'citations', 'sourcesUsed'],
}
const groundedRaw = await pipeline(
  scope.personas,
  (p) => agent(
    'You are persona "' + p.name + '" (lens: ' + p.lens + '; seed: ' + p.seedArchetype + ') in a STORM task.\nMode: ' + MODE_FRAME + '\nResearch question: ' + scope.researchQuestion + '\nTopic: ' + TOPIC + '\n\nSTEP 1 — ASK: 2-3 sharp questions only YOUR lens would ask.\nSTEP 2 — GROUND + ANSWER each from REAL sources:\n' + GROUND_NOTE + '\n' + UGC_NOTE + '\n\nReturn your view: coreStance (2 sentences), strongestEvidence (grounded), theOneThingOthersWontSay, citations[] (every factual claim -> source path/URL + short quote), and sourcesUsed. Omit any claim you cannot ground rather than fabricate a citation.',
    { label: 'view:' + p.seedArchetype, phase: 'Ground', schema: VIEW_SCHEMA, model: 'sonnet' })
)
const views = groundedRaw.filter(Boolean)
const groundedCount = views.reduce((n, v) => n + (Number(v.sourcesUsed) || 0), 0)
const droppedViews = scope.personas.length - views.length
log('Ground: ' + views.length + '/' + scope.personas.length + ' personas returned (' + droppedViews + ' dropped); ' + groundedCount + ' total source-groundings.')

// ============================== Contradict ==============================
phase('Contradict')
const CONTRA_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    agreements: { type: 'array', items: { type: 'string' } },
    contradictions: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, properties: { claim: { type: 'string' }, whoSays: { type: 'string' }, whoDisputes: { type: 'string' }, evidenceEachSide: { type: 'string' }, whyItMatters: { type: 'string' } }, required: ['claim', 'whoSays', 'whoDisputes', 'whyItMatters'] },
    },
    gaps: { type: 'array', items: { type: 'string' } },
  },
  required: ['agreements', 'contradictions', 'gaps'],
}
const contradictionMap = await agent(
  'You are the CONTRADICTION-MAP agent. Given these grounded persona views, find where the voices FIGHT — that is where real insight lives.\nViews (JSON):\n' + JSON.stringify(views).slice(0, 14000) + '\n\nReturn: agreements (what all agree on -> likely true), contradictions (specific claim, who says vs who disputes, evidence each side, why it matters), gaps (what NO persona addressed -> the field blind spot). Return the schema.',
  { label: 'contradict', phase: 'Contradict', schema: CONTRA_SCHEMA })

// ============================== Synthesize ==============================
phase('Synthesize')
const SYNTH_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    briefing: { type: 'string', description: 'synthesized briefing — every factual claim traces to a citation' },
    candidateAngles: { type: 'array', items: { type: 'string' } },
    suggestedStructure: { type: 'string', description: 'for writing: thesis + beat-by-beat arc + 2-3 hook options + a controversy/binary close; else a section outline' },
    reliabilityRanking: {
      type: 'array',
      items: { type: 'object', additionalProperties: false, properties: { finding: { type: 'string' }, reliability: { type: 'string', enum: ['high', 'medium', 'low'] }, supportedBy: { type: 'string' } }, required: ['finding', 'reliability'] },
    },
    specificAction: { type: 'string' },
  },
  required: ['briefing', 'candidateAngles', 'suggestedStructure', 'reliabilityRanking'],
}
const writingExtra = MODE === 'A'
  ? 'Because this feeds a DRAFTING step, ALSO produce candidateAngles and a suggestedStructure (thesis + beat-by-beat arc + 2-3 hook options + a controversy/binary close). SCAFFOLD ONLY — do not write finished publishable prose.'
  : 'Produce candidateAngles and a section outline as suggestedStructure.'
const synthesis = await agent(
  'You are the SYNTHESIS agent.\nMode: ' + MODE_FRAME + '\nDeliverable: ' + DELIVERABLE + '. Topic: ' + TOPIC + '.\nPull everything into a briefing no single persona could write. ' + writingExtra + '\n\nGrounded views: ' + JSON.stringify(views).slice(0, 9000) + '\nContradiction map: ' + JSON.stringify(contradictionMap).slice(0, 4000) + '\n\nEvery factual claim in the briefing must trace to a persona citation. Rank findings by reliability. Return the schema.',
  { label: 'synthesize', phase: 'Synthesize', schema: SYNTH_SCHEMA })

// ============================== Peer review (adversarial) ==============================
phase('PeerReview')
const REVIEW_SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    reliabilityScore: { type: 'integer', description: '0-100 overall confidence' },
    strongClaims: { type: 'array', items: { type: 'string' } },
    weakClaims: { type: 'array', items: { type: 'string' } },
    ungroundedClaims: { type: 'array', items: { type: 'string' }, description: 'claims with NO supporting citation — the hallucination risk' },
    biases: { type: 'array', items: { type: 'string' } },
    missingAngles: { type: 'array', items: { type: 'string' } },
    riskFlags: { type: 'array', items: { type: 'string' }, description: 'confidentiality leaks, unverifiable numbers, obvious AI-tells' },
  },
  required: ['reliabilityScore', 'ungroundedClaims', 'weakClaims', 'riskFlags'],
}
const peerReview = await agent(
  'You are the PEER-REVIEW agent. Be adversarial — default every factual claim to UNSUPPORTED unless it carries a real citation in the views. Grade the synthesis HONESTLY (no flattery).\nSynthesis: ' + JSON.stringify(synthesis).slice(0, 9000) + '\nGrounded views (for citation-checking): ' + JSON.stringify(views).slice(0, 6000) + '\n\nFlag: ungroundedClaims (no citation -> hallucination risk), weakClaims, biases (which persona dominated), missingAngles (the 6th lens), riskFlags (confidentiality leaks, unverifiable numbers/percentiles, obvious AI-tells). Give a 0-100 reliabilityScore. Return the schema.',
  { label: 'peer-review', phase: 'PeerReview', schema: REVIEW_SCHEMA })

// ============================== Completeness critic (no false-green) ==============================
const incomplete = !contradictionMap || !synthesis || !peerReview || views.length < Math.min(4, scope.personas.length) || groundedCount === 0
const telemetry = {
  mode: MODE,
  personasPlanned: scope.personas.length,
  personasReturned: views.length,
  personasDropped: droppedViews,
  totalSourceGroundings: groundedCount,
  ungroundedClaimCount: peerReview ? (peerReview.ungroundedClaims || []).length : null,
  reliabilityScore: peerReview ? peerReview.reliabilityScore : null,
  usedUGC: USE_UGC,
  groundingFiles: GROUNDING_FILES.length,
  date: DATE,
}
log('Done. telemetry=' + JSON.stringify(telemetry))

return {
  mode: MODE,
  incomplete: incomplete || undefined,
  reason: incomplete ? 'A stage failed or grounding was empty — DO NOT treat as clean; re-run.' : undefined,
  researchQuestion: scope.researchQuestion,
  personas: scope.personas,
  groundedViews: views,
  contradictionMap,
  synthesis,
  peerReview,
  telemetry,
}
