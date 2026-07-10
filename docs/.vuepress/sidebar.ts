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
  '/zh/guide/': [
    {
      text: '指南',
      items: [
        { text: '快速开始', link: '/zh/guide/getting-started.html' },
        { text: '加载 Tokenizer', link: '/zh/guide/loading.html' },
        { text: '编码与解码', link: '/zh/guide/encoding-decoding.html' },
        { text: '截断与 Padding', link: '/zh/guide/truncation-padding.html' },
        { text: 'Added Tokens', link: '/zh/guide/added-tokens.html' },
        { text: 'Hub 与离线缓存', link: '/zh/guide/pretrained-and-hub.html' },
      ],
    },
  ],
  '/zh/concepts/': [
    {
      text: '概念',
      items: [
        { text: 'Pipeline', link: '/zh/concepts/pipeline.html' },
        { text: 'Offsets', link: '/zh/concepts/offsets.html' },
        { text: 'Backend Model', link: '/zh/concepts/backends.html' },
        { text: 'Regex 策略', link: '/zh/concepts/regex-support.html' },
      ],
    },
  ],
  '/zh/compatibility/': [
    {
      text: '兼容性',
      items: [
        { text: '概览', link: '/zh/compatibility/overview.html' },
        { text: '组件矩阵', link: '/zh/compatibility/components.html' },
        { text: '已验证模型', link: '/zh/compatibility/verified-models.html' },
        { text: '限制', link: '/zh/compatibility/limitations.html' },
      ],
    },
  ],
  '/zh/migration/': [
    {
      text: '迁移',
      items: [
        { text: '从 HuggingFace 迁移', link: '/zh/migration/from-huggingface.html' },
        { text: 'API 映射', link: '/zh/migration/api-mapping.html' },
        { text: '差异', link: '/zh/migration/differences.html' },
      ],
    },
  ],
  '/zh/reference/': [
    {
      text: '参考',
      items: [
        { text: '概览', link: '/zh/reference/' },
        { text: 'Tokenizer', link: '/zh/reference/tokenizer.html' },
        { text: '组件', link: '/zh/reference/components.html' },
        { text: '类型与错误', link: '/zh/reference/types-and-errors.html' },
        { text: 'Hub', link: '/zh/reference/hub.html' },
        { text: 'Trainer', link: '/zh/reference/trainer.html' },
      ],
    },
  ],
  '/zh/performance/': [
    {
      text: '性能',
      items: [
        { text: 'Benchmarks', link: '/zh/performance/benchmarks.html' },
        { text: '方法论', link: '/zh/performance/methodology.html' },
      ],
    },
  ],
  '/zh/development/': [
    {
      text: '开发',
      items: [
        { text: '状态', link: '/zh/development/status.html' },
        { text: '测试', link: '/zh/development/testing.html' },
        { text: '文档工作流', link: '/zh/development/docs-workflow.html' },
      ],
    },
  ],
}
