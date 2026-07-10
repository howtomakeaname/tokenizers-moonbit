import { defineNavbarConfig } from 'vuepress-theme-plume'

export const enNavbar = defineNavbarConfig([
  { text: 'Guide', link: '/guide/getting-started.html' },
  { text: 'Concepts', link: '/concepts/pipeline.html' },
  { text: 'Compatibility', link: '/compatibility/overview.html' },
  { text: 'Migration', link: '/migration/from-huggingface.html' },
  { text: 'Reference', link: '/reference/' },
  { text: 'Performance', link: '/performance/benchmarks.html' },
  { text: 'Development', link: '/development/status.html' },
  { text: 'GitHub', link: 'https://github.com/howtomakeaname/tokenizers-moonbit' },
])

export const zhNavbar = defineNavbarConfig([
  { text: '指南', link: '/zh/usage.html' },
  { text: 'API', link: '/zh/api.html' },
  { text: '组件与限制', link: '/zh/components.html' },
  { text: '迁移', link: '/zh/migration-from-hf.html' },
  { text: 'Benchmarks', link: '/zh/benchmarks.html' },
  { text: 'GitHub', link: 'https://github.com/howtomakeaname/tokenizers-moonbit' },
])
