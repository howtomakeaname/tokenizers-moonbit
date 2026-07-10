#!/usr/bin/env node
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'

const [inputPath, outputPath = 'docs/.vuepress/public/benchmarks/latest.json'] = process.argv.slice(2)

if (!inputPath) {
  console.error('usage: node scripts/update-docs-benchmarks.mjs <bench-report.json> [output]')
  process.exit(2)
}

const raw = JSON.parse(await readFile(inputPath, 'utf8'))
const rows = Array.isArray(raw.rows) ? raw.rows : []

const report = {
  generated_at: new Date().toISOString(),
  target: raw.target ?? 'native',
  corpora: Array.isArray(raw.corpora) ? raw.corpora : [],
  models: Array.isArray(raw.models) ? raw.models : [],
  fail_above: raw.fail_above ?? null,
  passed: Boolean(raw.passed),
  rows: rows.map(row => ({
    name: String(row.name),
    moon_us: Number(row.moon_us),
    hf_us: Number(row.hf_us),
    ratio: Number(row.ratio),
    verdict: String(row.verdict),
  })),
  optimization_focus: Array.isArray(raw.optimization_focus) ? raw.optimization_focus : [],
  failures: Array.isArray(raw.failures) ? raw.failures : [],
  skipped_hf_baselines: Array.isArray(raw.skipped_hf_baselines) ? raw.skipped_hf_baselines : [],
}

await mkdir(path.dirname(outputPath), { recursive: true })
await writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8')
