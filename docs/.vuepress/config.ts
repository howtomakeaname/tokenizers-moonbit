import { defineUserConfig } from 'vuepress'
import { viteBundler } from '@vuepress/bundler-vite'
import { plumeTheme } from 'vuepress-theme-plume'
import { enNavbar, zhNavbar } from './navbar.js'
import { enSidebar, zhSidebar } from './sidebar.js'

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
    navbar: enNavbar,
    sidebar: enSidebar,
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
    locales: {
      '/zh/': {
        navbar: zhNavbar,
        sidebar: zhSidebar,
        selectLanguageText: '选择语言',
        selectLanguageName: '简体中文',
        editLinkText: '在 GitHub 上编辑此页',
        lastUpdatedText: '最后更新',
        contributorsText: '贡献者',
      },
    },
    plugins: {
      markdownChart: {
        mermaid: true,
      },
    },
  }),
})
