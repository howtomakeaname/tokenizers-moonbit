import { defineNavbarConfig } from 'vuepress-theme-plume'

export const navbar = defineNavbarConfig([
  { text: 'Guide', link: '/guide/getting-started.html' },
  { text: 'Concepts', link: '/concepts/pipeline.html' },
  { text: 'Compatibility', link: '/compatibility/overview.html' },
  { text: 'Migration', link: '/migration/from-huggingface.html' },
  { text: 'Reference', link: '/reference/' },
  { text: 'Performance', link: '/performance/benchmarks.html' },
  { text: 'Development', link: '/development/status.html' },
  { text: '中文', link: '/zh/' },
  { text: 'GitHub', link: 'https://github.com/howtomakeaname/tokenizers-moonbit' },
])
