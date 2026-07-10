import { defineUserConfig } from 'vuepress'
import { viteBundler } from '@vuepress/bundler-vite'
import { plumeTheme } from 'vuepress-theme-plume'
import { navbar } from './navbar.js'
import { sidebar } from './sidebar.js'

export default defineUserConfig({
  lang: 'en-US',
  title: 'tokenizers-moonbit',
  description: 'A pure MoonBit port of HuggingFace tokenizers',
  base: '/tokenizers-moonbit/',
  bundler: viteBundler(),
  locales: {
    '/': {
      lang: 'en-US',
      title: 'tokenizers-moonbit',
      description: 'Portable HuggingFace-compatible tokenizers for MoonBit',
    },
    '/zh/': {
      lang: 'zh-CN',
      title: 'tokenizers-moonbit',
      description: '面向 MoonBit 全 target 的 HuggingFace tokenizer 兼容实现',
    },
  },
  head: [
    ['meta', { name: 'theme-color', content: '#1f7a5b' }],
    ['meta', { name: 'color-scheme', content: 'light dark' }],
  ],
  markdown: {
    html: false,
  },
  theme: plumeTheme({
    logo: false,
    appearance: true,
    navbar,
    sidebar,
    sidebarScrollbar: true,
    outline: [2, 3],
    docsRepo: 'https://github.com/howtomakeaname/tokenizers-moonbit',
    docsBranch: 'main',
    docsDir: 'docs',
    editLink: true,
    lastUpdated: true,
    contributors: true,
    social: [
      {
        icon: 'github',
        link: 'https://github.com/howtomakeaname/tokenizers-moonbit',
      },
    ],
    search: {
      provider: 'local',
    },
    plugins: {
      markdownChart: {
        mermaid: true,
      },
    },
  }),
})
