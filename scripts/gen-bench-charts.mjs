#!/usr/bin/env node
/**
 * Generate ECharts chart configurations from benchmark JSON.
 *
 * Usage:
 *   node scripts/gen-bench-charts.mjs [input.json] [output-dir]
 *
 * Reads bench_compare.py --json-out report and generates:
 *   - ratio-bar.json: Moon/HF ratio bar chart (top N cases)
 *   - scatter.json: Moon µs vs HF µs scatter plot
 *   - summary.json: faster/same/slower pie chart
 *   - model-heatmap.json: per-model average ratio heatmap
 */

import { mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'

const [inputPath = 'reports/bench-native-mixed.json', outputDir = 'docs/.vuepress/public/benchmarks/charts'] = process.argv.slice(2)

const COLORS = {
  faster: '#22c55e',
  same: '#f59e0b',
  slower: '#ef4444',
  moon: '#3b82f6',
  hf: '#8b5cf6',
  grid: '#e5e7eb',
  gridDark: '#374151',
  text: '#1f2937',
  textDark: '#d1d5db',
}

async function main() {
  let raw
  try {
    raw = JSON.parse(await readFile(inputPath, 'utf8'))
  } catch {
    console.error(`Cannot read ${inputPath}; skipping chart generation.`)
    process.exit(0)
  }

  const rows = Array.isArray(raw.rows) ? raw.rows : []
  if (rows.length === 0) {
    console.log('No benchmark rows; skipping chart generation.')
    process.exit(0)
  }

  await mkdir(outputDir, { recursive: true })

  // Parse model name from row name (e.g. "gpt2-encode-mixed" -> "gpt2")
  const modelOf = (name) => name.split('-')[0]

  // Group rows by model
  const byModel = {}
  for (const row of rows) {
    const model = modelOf(row.name)
    if (!byModel[model]) byModel[model] = []
    byModel[model].push(row)
  }

  const models = Object.keys(byModel).sort()

  // 1. Ratio bar chart (top 15 by ratio, descending)
  const topN = 15
  const sorted = [...rows].sort((a, b) => b.ratio - a.ratio).slice(0, topN)
  const ratioBar = {
    tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
    grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
    xAxis: {
      type: 'value',
      name: 'Moon/HF Ratio',
      min: 0,
      max: Math.max(1.5, ...sorted.map(r => r.ratio)),
      splitLine: { lineStyle: { type: 'dashed' } },
    },
    yAxis: {
      type: 'category',
      data: sorted.map(r => r.name).reverse(),
      axisLabel: { fontSize: 11 },
    },
    series: [{
      type: 'bar',
      data: sorted.map(r => ({
        value: r.ratio,
        itemStyle: {
          color: r.verdict === 'faster' ? COLORS.faster
            : r.verdict === 'slower' ? COLORS.slower
            : COLORS.same,
        },
      })).reverse(),
      label: {
        show: true,
        position: 'right',
        formatter: '{c}x',
        fontSize: 11,
      },
      markLine: {
        silent: true,
        data: [{ xAxis: 1.0, lineStyle: { color: '#9ca3af', type: 'dashed' } }],
        label: { formatter: '1.0x' },
      },
    }],
  }
  await writeFile(path.join(outputDir, 'ratio-bar.json'), JSON.stringify(ratioBar, null, 2))

  // 2. Scatter plot: Moon µs vs HF µs
  const scatterData = rows.map(r => ({
    value: [r.hf_us, r.moon_us],
    name: r.name,
    itemStyle: {
      color: r.verdict === 'faster' ? COLORS.faster
        : r.verdict === 'slower' ? COLORS.slower
        : COLORS.same,
    },
  }))
  const maxUs = Math.max(...rows.map(r => Math.max(r.hf_us, r.moon_us)))
  const scatter = {
    tooltip: {
      trigger: 'item',
      formatter: (p) => `${p.data.name}<br/>HF: ${p.data.value[0].toFixed(1)} µs<br/>Moon: ${p.data.value[1].toFixed(1)} µs<br/>Ratio: ${(p.data.value[1] / p.data.value[0]).toFixed(3)}x`,
    },
    grid: { left: '10%', right: '10%', bottom: '15%', top: '10%' },
    xAxis: {
      type: 'value',
      name: 'HF µs/op',
      nameLocation: 'middle',
      nameGap: 30,
      min: 0,
    },
    yAxis: {
      type: 'value',
      name: 'Moon µs/op',
      nameLocation: 'middle',
      nameGap: 40,
      min: 0,
    },
    series: [{
      type: 'scatter',
      data: scatterData,
      symbolSize: 10,
      markLine: {
        silent: true,
        data: [{
          type: 'line',
          lineStyle: { color: '#9ca3af', type: 'dashed' },
          label: { formatter: 'y = x' },
        }],
        // y = x line from origin
      },
    }],
    // Add diagonal reference line as a separate series
    visualMap: { show: false },
  }
  // Add y=x reference line
  scatter.series.push({
    type: 'line',
    data: [[0, 0], [maxUs * 1.1, maxUs * 1.1]],
    lineStyle: { color: '#9ca3af', type: 'dashed', width: 1 },
    symbol: 'none',
    silent: true,
    tooltip: { show: false },
  })
  await writeFile(path.join(outputDir, 'scatter.json'), JSON.stringify(scatter, null, 2))

  // 3. Summary pie chart
  const counts = {
    faster: rows.filter(r => r.verdict === 'faster').length,
    same: rows.filter(r => r.verdict === 'same-range').length,
    slower: rows.filter(r => r.verdict === 'slower').length,
  }
  const summary = {
    tooltip: { trigger: 'item', formatter: '{b}: {c} ({d}%)' },
    legend: { bottom: '5%', left: 'center' },
    series: [{
      type: 'pie',
      radius: ['40%', '70%'],
      avoidLabelOverlap: true,
      itemStyle: { borderRadius: 6, borderColor: '#fff', borderWidth: 2 },
      label: { show: true, formatter: '{b}\n{c}' },
      data: [
        { value: counts.faster, name: 'Faster', itemStyle: { color: COLORS.faster } },
        { value: counts.same, name: 'Same Range', itemStyle: { color: COLORS.same } },
        { value: counts.slower, name: 'Slower', itemStyle: { color: COLORS.slower } },
      ],
    }],
  }
  await writeFile(path.join(outputDir, 'summary.json'), JSON.stringify(summary, null, 2))

  // 4. Model average ratio heatmap (grouped bar)
  const modelStats = models.map(model => {
    const modelRows = byModel[model]
    const avgRatio = modelRows.reduce((s, r) => s + r.ratio, 0) / modelRows.length
    const minRatio = Math.min(...modelRows.map(r => r.ratio))
    const maxRatio = Math.max(...modelRows.map(r => r.ratio))
    return { model, avgRatio, minRatio, maxRatio, count: modelRows.length }
  }).sort((a, b) => b.avgRatio - a.avgRatio)

  const modelBar = {
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params) => {
        const p = params[0]
        const stat = modelStats[p.dataIndex]
        return `${stat.model}<br/>Avg: ${stat.avgRatio.toFixed(3)}x<br/>Min: ${stat.minRatio.toFixed(3)}x<br/>Max: ${stat.maxRatio.toFixed(3)}x<br/>Cases: ${stat.count}`
      },
    },
    grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
    xAxis: {
      type: 'value',
      name: 'Avg Moon/HF Ratio',
      min: 0,
      max: Math.max(1.5, ...modelStats.map(s => s.avgRatio)),
      splitLine: { lineStyle: { type: 'dashed' } },
    },
    yAxis: {
      type: 'category',
      data: modelStats.map(s => s.model),
      axisLabel: { fontSize: 11 },
    },
    series: [{
      type: 'bar',
      data: modelStats.map(s => ({
        value: s.avgRatio,
        itemStyle: {
          color: s.avgRatio < 0.9 ? COLORS.faster
            : s.avgRatio > 1.1 ? COLORS.slower
            : COLORS.same,
        },
      })),
      label: {
        show: true,
        position: 'right',
        formatter: (p) => `${p.value.toFixed(3)}x`,
        fontSize: 11,
      },
      markLine: {
        silent: true,
        data: [{ xAxis: 1.0, lineStyle: { color: '#9ca3af', type: 'dashed' } }],
        label: { formatter: '1.0x' },
      },
    }],
  }
  await writeFile(path.join(outputDir, 'model-bar.json'), JSON.stringify(modelBar, null, 2))

  console.log(`Generated 4 chart configs in ${outputDir}/`)
}

main().catch(err => {
  console.error(err)
  process.exit(1)
})
