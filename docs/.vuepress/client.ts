import { defineClientConfig } from 'vuepress/client'
import { defineMermaidConfig } from '@vuepress/plugin-markdown-chart/client'
import './styles/index.css'

const lightTheme = {
  primaryColor: '#dff5ec',
  primaryTextColor: '#12352a',
  primaryBorderColor: '#2c8f6b',
  lineColor: '#4d6f64',
  secondaryColor: '#e4f3f8',
  tertiaryColor: '#f7faf8',
  background: '#ffffff',
  mainBkg: '#f7faf8',
  secondBkg: '#eef7f2',
  tertiaryBkg: '#f4f8fb',
  clusterBkg: '#f8fbfa',
  clusterBorder: '#8bb7a4',
  edgeLabelBackground: '#ffffff',
  nodeBorder: '#2c8f6b',
  textColor: '#1d2f2a',
  titleColor: '#12352a',
  actorBkg: '#e4f3f8',
  actorBorder: '#2c8f6b',
  actorTextColor: '#12352a',
  signalColor: '#4d6f64',
  signalTextColor: '#1d2f2a',
  noteBkgColor: '#fff7dc',
  noteBorderColor: '#c4a24d',
  noteTextColor: '#30270c',
}

const darkTheme = {
  primaryColor: '#12352a',
  primaryTextColor: '#e7f7ef',
  primaryBorderColor: '#6fd3a7',
  lineColor: '#9bb8ad',
  secondaryColor: '#18384a',
  tertiaryColor: '#111a17',
  background: '#0f1412',
  mainBkg: '#141d19',
  secondBkg: '#17241f',
  tertiaryBkg: '#132027',
  clusterBkg: '#101a17',
  clusterBorder: '#4d8f74',
  edgeLabelBackground: '#0f1412',
  nodeBorder: '#6fd3a7',
  textColor: '#e0eee8',
  titleColor: '#f0fff8',
  actorBkg: '#18384a',
  actorBorder: '#6fd3a7',
  actorTextColor: '#e7f7ef',
  signalColor: '#9bb8ad',
  signalTextColor: '#e0eee8',
  noteBkgColor: '#403615',
  noteBorderColor: '#d4b45f',
  noteTextColor: '#fff2bd',
}

export default defineClientConfig({
  enhance() {
    defineMermaidConfig({
      theme: 'base',
      themeVariables: (isDarkMode) => (isDarkMode ? darkTheme : lightTheme),
      securityLevel: 'strict',
    })
  },
})
