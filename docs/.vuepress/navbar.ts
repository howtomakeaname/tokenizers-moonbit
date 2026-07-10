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
  { text: '指南', link: '/zh/guide/getting-started.html' },
  { text: '概念', link: '/zh/concepts/pipeline.html' },
  { text: '兼容性', link: '/zh/compatibility/overview.html' },
  { text: '迁移', link: '/zh/migration/from-huggingface.html' },
  { text: '参考', link: '/zh/reference/' },
  { text: '性能', link: '/zh/performance/benchmarks.html' },
  { text: '开发', link: '/zh/development/status.html' },
  { text: 'GitHub', link: 'https://github.com/howtomakeaname/tokenizers-moonbit' },
])
