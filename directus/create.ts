import { readFileSync, writeFileSync } from 'fs'
import type { createApiClient } from '@neondatabase/api-client'

type CreateProjectResponse = Awaited<ReturnType<ReturnType<typeof createApiClient>['createProject']>>['data']

function setEnvVar(content: string, key: string, value: string) {
  const regex = new RegExp(`^${key}=.*$`, 'm')
  if (regex.test(content)) {
    return content.replace(regex, `${key}=${value}`)
  } else {
    return content + (content.endsWith('\n') ? '' : '\n') + `${key}=${value}\n`
  }
}

async function createProject(): Promise<CreateProjectResponse> {
  const res = await fetch(process.env.WEBHOOK_URL, {
    method: 'POST',
    headers: {
      'X-Signature': process.env.WEBHOOK_SIGNING_SECRET
    }
  })

  const data = await res.json()

  if (data.error) {
    console.error('Error creating project:', data.message)
    throw new Error(data.message)
  }

  return data
}

(async function() {
  const createdProject = await createProject()

  const databaseConnection = createdProject.connection_uris[0]

  const databaseConnectionString = databaseConnection.connection_uri // replace .env DB_CONNECTION_STRING

  const envPath = './.env'
  let envContent = ''
  try {
    envContent = readFileSync(envPath, 'utf8')
  } catch (e) {
    // If .env does not exist, start with empty content
    envContent = ''
  }

  envContent = setEnvVar(envContent, 'DB_CONNECTION_STRING', databaseConnectionString)

  writeFileSync(envPath, envContent)
})()