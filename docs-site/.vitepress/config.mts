import { defineConfig } from 'vitepress'
export default defineConfig({
 cleanUrls: true,
 title: 'KlickSea', description: 'A quiet voice-first screen companion for macOS.',
 head: [['link', {rel: 'icon', href: '/icon.png'}]],
 themeConfig: {
  logo: '/icon.png', search: {provider: 'local'},
  nav: [{text:'Guide',link:'/getting-started'},{text:'Testing status',link:'/testing'},{text:'Website',link:process.env.LANDING_URL || 'https://klicksea-web.vercel.app'}],
  sidebar: [{text:'Use KlickSea',items:[{text:'Getting started',link:'/getting-started'},{text:'Capture & voice',link:'/usage'},{text:'Providers',link:'/providers'},{text:'Settings',link:'/settings'},{text:'Privacy & permissions',link:'/privacy'},{text:'Troubleshooting',link:'/troubleshooting'}]},{text:'Build & contribute',items:[{text:'Development',link:'/development'},{text:'Testing status',link:'/testing'},{text:'Developer ID & DMG',link:'/release'}]}],
  socialLinks:[{icon:'github',link:'https://github.com/techsavvyash/klicksea'}],
  footer:{message:'Early developer preview. Public notarized download pending.'}
 }
})
