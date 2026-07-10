<script setup lang="ts">
import { onMounted, onUnmounted, ref, shallowRef } from 'vue'
import { withBase } from 'vuepress/client'

const props = defineProps<{
  src: string
  title?: string
  height?: number
}>()

const container = ref<HTMLDivElement | null>(null)
const chart = shallowRef<any>(null)
const loading = ref(true)
const error = ref('')

async function initChart() {
  if (!container.value) return

  try {
    const echarts = await import('echarts')
    chart.value = echarts.init(container.value)

    const resp = await fetch(withBase(props.src))
    if (!resp.ok) throw new Error(`${resp.status} ${resp.statusText}`)
    const option = await resp.json()

    chart.value.setOption(option)
    loading.value = false
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err)
    loading.value = false
  }
}

function handleResize() {
  chart.value?.resize()
}

onMounted(() => {
  initChart()
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  chart.value?.dispose()
  window.removeEventListener('resize', handleResize)
})
</script>

<template>
  <div class="benchmark-chart">
    <h3 v-if="title">{{ title }}</h3>
    <div
      ref="container"
      class="chart-container"
      :style="{ height: `${height || 400}px` }"
    />
    <p v-if="loading" class="chart-loading">Loading chart...</p>
    <p v-if="error" class="chart-error">{{ error }}</p>
  </div>
</template>

<style scoped>
.benchmark-chart {
  margin: 1.5rem 0;
}

.benchmark-chart h3 {
  margin-bottom: 0.5rem;
  font-size: 1.1rem;
}

.chart-container {
  width: 100%;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  overflow: hidden;
}

.chart-loading,
.chart-error {
  text-align: center;
  padding: 1rem;
  color: var(--vp-c-text-2);
  font-size: 0.9rem;
}

.chart-error {
  color: var(--vp-c-danger-1);
}
</style>
