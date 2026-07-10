<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { withBase } from 'vuepress/client'

type Verdict = 'faster' | 'same-range' | 'slower'

interface BenchmarkRow {
  name: string
  moon_us: number
  hf_us: number
  ratio: number
  verdict: Verdict
}

interface BenchmarkReport {
  generated_at?: string
  target: string
  corpora: string[]
  models: string[]
  passed: boolean
  rows: BenchmarkRow[]
  optimization_focus?: BenchmarkRow[]
  skipped_hf_baselines?: string[]
}

const props = withDefaults(defineProps<{
  locale?: 'en' | 'zh'
  src?: string
}>(), {
  locale: 'en',
  src: '/benchmarks/latest.json',
})

const report = ref<BenchmarkReport | null>(null)
const loading = ref(true)
const error = ref('')

const labels = computed(() => props.locale === 'zh'
  ? {
      title: '最新 MoonBit / HF 对比快照',
      description: '数据来自 benchmark JSON。Moon/HF 越低越好，1.00x 表示与 Python tokenizers 同量级。',
      loading: '正在加载 benchmark 数据...',
      unavailable: 'benchmark 数据暂不可用。',
      target: 'Target',
      corpora: '语料',
      models: '模型',
      rows: '用例',
      faster: '更快',
      same: '同量级',
      slower: '更慢',
      skipped: '跳过 baseline',
      focus: '优化关注',
      case: '用例',
      moon: 'MoonBit µs/op',
      hf: 'HF µs/op',
      ratio: 'Moon/HF',
      generated: '生成时间',
      fallback: '使用仓库内 fallback 数据',
    }
  : {
      title: 'Latest MoonBit / HF Snapshot',
      description: 'Data is loaded from the benchmark JSON. Lower Moon/HF is better; 1.00x means same range as Python tokenizers.',
      loading: 'Loading benchmark data...',
      unavailable: 'Benchmark data is not available.',
      target: 'Target',
      corpora: 'Corpora',
      models: 'Models',
      rows: 'Cases',
      faster: 'Faster',
      same: 'Same range',
      slower: 'Slower',
      skipped: 'Skipped baselines',
      focus: 'Optimization focus',
      case: 'Case',
      moon: 'MoonBit µs/op',
      hf: 'HF µs/op',
      ratio: 'Moon/HF',
      generated: 'Generated',
      fallback: 'Using checked-in fallback data',
    })

const rows = computed(() => report.value?.rows ?? [])
const skipped = computed(() => report.value?.skipped_hf_baselines ?? [])
const sortedRows = computed(() => [...rows.value]
  .sort((a, b) => b.ratio - a.ratio)
  .slice(0, 10))
const maxRatio = computed(() => Math.max(1.1, ...sortedRows.value.map(row => row.ratio)))

const counts = computed(() => ({
  faster: rows.value.filter(row => row.verdict === 'faster').length,
  same: rows.value.filter(row => row.verdict === 'same-range').length,
  slower: rows.value.filter(row => row.verdict === 'slower').length,
}))

const generatedAt = computed(() => {
  if (!report.value?.generated_at)
    return labels.value.fallback
  return report.value.generated_at
})

function ratioWidth(row: BenchmarkRow) {
  const pct = Math.max(4, Math.min(100, row.ratio / maxRatio.value * 100))
  return { width: `${pct}%` }
}

function formatNumber(value: number, digits = 2) {
  if (!Number.isFinite(value))
    return 'n/a'
  return value.toFixed(digits)
}

// Get base path from current URL
function getBase(): string {
  if (typeof window === 'undefined') return ''
  const path = window.location.pathname
  const match = path.match(/^(\/[^/]+\/)/)
  return match ? match[1] : ''
}

onMounted(async () => {
  try {
    const url = getBase() + props.src.replace(/^\//, '')
    console.log('BenchmarkSnapshot: fetching', url)
    const response = await fetch(url, { cache: 'no-store' })
    if (!response.ok)
      throw new Error(`${response.status} ${response.statusText}`)
    report.value = await response.json()
    console.log('BenchmarkSnapshot: loaded', report.value)
  } catch (err) {
    console.error('BenchmarkSnapshot error:', err)
    error.value = err instanceof Error ? err.message : String(err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <section class="benchmark-snapshot" aria-live="polite">
    <div class="snapshot-heading">
      <div>
        <h2>{{ labels.title }}</h2>
        <p>{{ labels.description }}</p>
      </div>
    </div>

    <p v-if="loading" class="snapshot-muted">{{ labels.loading }}</p>
    <p v-else-if="error" class="snapshot-muted">
      {{ labels.unavailable }} {{ error }}
    </p>

    <template v-else-if="report">
      <dl class="snapshot-meta">
        <div>
          <dt>{{ labels.target }}</dt>
          <dd>{{ report.target }}</dd>
        </div>
        <div>
          <dt>{{ labels.corpora }}</dt>
          <dd>{{ report.corpora.join(', ') }}</dd>
        </div>
        <div>
          <dt>{{ labels.models }}</dt>
          <dd>{{ report.models.length }}</dd>
        </div>
        <div>
          <dt>{{ labels.rows }}</dt>
          <dd>{{ rows.length }}</dd>
        </div>
        <div>
          <dt>{{ labels.generated }}</dt>
          <dd>{{ generatedAt }}</dd>
        </div>
      </dl>

      <div class="snapshot-summary">
        <span class="summary-pill faster">{{ counts.faster }} {{ labels.faster }}</span>
        <span class="summary-pill same">{{ counts.same }} {{ labels.same }}</span>
        <span class="summary-pill slower">{{ counts.slower }} {{ labels.slower }}</span>
        <span class="summary-pill skipped">{{ skipped.length }} {{ labels.skipped }}</span>
      </div>

      <div class="snapshot-bars" :aria-label="labels.focus">
        <div v-for="row in sortedRows" :key="row.name" class="snapshot-bar-row">
          <div class="bar-label">
            <span>{{ row.name }}</span>
            <strong>{{ formatNumber(row.ratio) }}x</strong>
          </div>
          <div class="bar-track">
            <div class="bar-fill" :class="row.verdict" :style="ratioWidth(row)" />
          </div>
        </div>
      </div>

      <div class="snapshot-table-wrap">
        <table class="snapshot-table">
          <thead>
            <tr>
              <th>{{ labels.case }}</th>
              <th>{{ labels.moon }}</th>
              <th>{{ labels.hf }}</th>
              <th>{{ labels.ratio }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in sortedRows" :key="`${row.name}-table`">
              <td>{{ row.name }}</td>
              <td>{{ formatNumber(row.moon_us) }}</td>
              <td>{{ formatNumber(row.hf_us) }}</td>
              <td>{{ formatNumber(row.ratio) }}x</td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
  </section>
</template>
