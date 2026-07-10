import { mkdir, writeFile } from 'node:fs/promises'

await mkdir('gh-pages-deploy', { recursive: true })
await writeFile('gh-pages-deploy/.nojekyll', '')
