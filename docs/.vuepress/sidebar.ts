import type { ThemeSidebarMulti } from 'vuepress-theme-plume'

export const enSidebar: ThemeSidebarMulti = {
  '/guide/': [
    {
      text: 'Guide',
      items: [
        { text: 'Getting Started', link: '/guide/getting-started.html' },
        { text: 'Loading Tokenizers', link: '/guide/loading.html' },
        { text: 'Encoding and Decoding', link: '/guide/encoding-decoding.html' },
        { text: 'Truncation and Padding', link: '/guide/truncation-padding.html' },
        { text: 'Added Tokens', link: '/guide/added-tokens.html' },
        { text: 'Hub and Offline Cache', link: '/guide/pretrained-and-hub.html' },
      ],
    },
  ],
  '/concepts/': [
    {
      text: 'Concepts',
      items: [
        { text: 'Pipeline', link: '/concepts/pipeline.html' },
        { text: 'Offsets', link: '/concepts/offsets.html' },
        { text: 'Backend Model', link: '/concepts/backends.html' },
        { text: 'Regex Strategy', link: '/concepts/regex-support.html' },
      ],
    },
  ],
  '/compatibility/': [
    {
      text: 'Compatibility',
      items: [
        { text: 'Overview', link: '/compatibility/overview.html' },
        { text: 'Component Matrix', link: '/compatibility/components.html' },
        { text: 'Verified Models', link: '/compatibility/verified-models.html' },
        { text: 'Limitations', link: '/compatibility/limitations.html' },
      ],
    },
  ],
  '/migration/': [
    {
      text: 'Migration',
      items: [
        { text: 'From HuggingFace', link: '/migration/from-huggingface.html' },
        { text: 'API Mapping', link: '/migration/api-mapping.html' },
        { text: 'Differences', link: '/migration/differences.html' },
      ],
    },
  ],
  '/reference/': [
    {
      text: 'Reference',
      items: [
        { text: 'Overview', link: '/reference/' },
        { text: 'Tokenizer', link: '/reference/tokenizer.html' },
        { text: 'Components', link: '/reference/components.html' },
        { text: 'Types and Errors', link: '/reference/types-and-errors.html' },
        { text: 'Hub', link: '/reference/hub.html' },
        { text: 'Trainer', link: '/reference/trainer.html' },
      ],
    },
  ],
  '/performance/': [
    {
      text: 'Performance',
      items: [
        { text: 'Benchmarks', link: '/performance/benchmarks.html' },
        { text: 'Methodology', link: '/performance/methodology.html' },
      ],
    },
  ],
  '/development/': [
    {
      text: 'Development',
      items: [
        { text: 'Status', link: '/development/status.html' },
        { text: 'Testing', link: '/development/testing.html' },
        { text: 'Docs Workflow', link: '/development/docs-workflow.html' },
      ],
    },
  ],
}

export const zhSidebar: ThemeSidebarMulti = {
  '/zh/': [
    {
      text: '中文',
      items: [
        { text: '概览', link: '/zh/' },
        { text: '使用指南', link: '/zh/usage.html' },
        { text: 'API', link: '/zh/api.html' },
        { text: '组件与限制', link: '/zh/components.html' },
        { text: '迁移', link: '/zh/migration-from-hf.html' },
        { text: 'Benchmarks', link: '/zh/benchmarks.html' },
      ],
    },
  ],
}
