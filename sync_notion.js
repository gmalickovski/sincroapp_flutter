const dotenv = require('dotenv');
// Load .env from ROOT
const envPath = path.join(__dirname, '.env');
dotenv.config({ path: envPath });

// DEFINIÇÕES
const NOTION_KEY = process.env.NOTION_API_KEY;
// Prioritize PLANS_DATABASE_ID as that's where features are
const DATABASE_ID = process.env.PLANS_DATABASE_ID || '095f080e-54fa-4ee0-a92a-8970e99ce5b0';
const DIRECTORY_PATH = path.join(__dirname, 'Funcionalidades e Recursos');

const FILES_TO_SYNC = [
    'RECORRENCIA_INTELIGENTE.md'
];

function notionRequest(endpoint, method, body = null) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: 'api.notion.com',
            path: '/v1' + endpoint,
            method: method,
            headers: {
                'Authorization': `Bearer ${NOTION_KEY}`,
                'Notion-Version': '2022-06-28',
                'Content-Type': 'application/json'
            }
        };
        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(JSON.parse(data));
                } else {
                    reject({ status: res.statusCode, body: data });
                }
            });
        });
        req.on('error', (e) => reject(e));
        if (body) req.write(JSON.stringify(body));
        req.end();
    });
}

// --- PARSER AVANÇADO DE RICH TEXT ---
function parseRichText(text) {
    if (!text) return [];
    const parts = [];
    let remaining = text;

    // Regex para **bold**
    const regexBold = /(\*\*.*?\*\*)/g;
    const tokens = remaining.split(regexBold);

    tokens.forEach(token => {
        if (!token) return;

        if (token.startsWith('**') && token.endsWith('**')) {
            const content = token.slice(2, -2);
            parts.push({
                type: 'text',
                text: { content: content },
                annotations: { bold: true }
            });
        } else {
            // Regex para *italic*
            const regexItalic = /(\*[^\*]+\*)/g;
            const subTokens = token.split(regexItalic);

            subTokens.forEach(subToken => {
                if (!subToken) return;
                if (subToken.startsWith('*') && subToken.endsWith('*')) {
                    const content = subToken.slice(1, -1);
                    parts.push({
                        type: 'text',
                        text: { content: content },
                        annotations: { italic: true }
                    });
                } else {
                    parts.push({
                        type: 'text',
                        text: { content: subToken }
                    });
                }
            });
        }
    });

    return parts;
}

function parseMarkdown(content, filename) {
    const lines = content.split('\n');
    let title = filename.replace('.md', '').replace(/_/g, ' ');
    let nomeComercial = '';
    let descricaoCurta = '';
    let bodyContent = [];
    let isHeader = true;

    for (const line of lines) {
        if (line.trim().length === 0) continue;

        if (line.startsWith('# ')) {
            title = line.replace('# ', '').trim();
        } else if (line.includes('**Nome Comercial:**')) {
            nomeComercial = line.split('**Nome Comercial:**')[1].trim();
        } else if (line.includes('**Descrição Curta:**')) {
            descricaoCurta = line.split('**Descrição Curta:**')[1].trim();
        } else if (line.trim() === '---') {
            isHeader = false;
        } else if (!isHeader) {
            const cleanLine = line.trim();
            if (cleanLine.startsWith('## ')) {
                bodyContent.push({
                    object: 'block', type: 'heading_2',
                    heading_2: { rich_text: parseRichText(cleanLine.replace('## ', '')) }
                });
            } else if (cleanLine.startsWith('### ')) {
                bodyContent.push({
                    object: 'block', type: 'heading_3',
                    heading_3: { rich_text: parseRichText(cleanLine.replace('### ', '')) }
                });
            } else if (cleanLine.startsWith('* ') || cleanLine.startsWith('- ')) {
                bodyContent.push({
                    object: 'block', type: 'bulleted_list_item',
                    bulleted_list_item: { rich_text: parseRichText(cleanLine.replace(/^[\*\-] /, '')) }
                });
            } else {
                bodyContent.push({
                    object: 'block', type: 'paragraph',
                    paragraph: { rich_text: parseRichText(cleanLine) }
                });
            }
        }
    }
    return { title, nomeComercial, descricaoCurta, bodyContent: bodyContent.slice(0, 95) };
}

// --- GERENCIAMENTO DE CONTEÚDO ---

async function clearPageContent(pageId) {
    console.log(`   [CLEAN] Limpando conteúdo antigo da página ${pageId}...`);
    try {
        const children = await notionRequest(`/blocks/${pageId}/children?page_size=100`, 'GET');
        if (children.results.length === 0) return;

        console.log(`      ...Deletando ${children.results.length} blocos.`);
        for (const block of children.results) {
            await notionRequest(`/blocks/${block.id}`, 'DELETE');
        }
    } catch (e) {
        console.warn("      Erro ao limpar blocos:", e.message);
    }
}

async function syncFile(file) {
    console.log(`\n=== Processando: ${file} ===`);
    const filePath = path.join(DIRECTORY_PATH, file);
    const content = fs.readFileSync(filePath, 'utf-8');
    const parsed = parseMarkdown(content, file);
    const targetName = parsed.nomeComercial || parsed.title;

    // BUSCA
    const res = await notionRequest(`/databases/${DATABASE_ID}/query`, 'POST', {
        filter: { property: 'Funcionalidade', title: { equals: targetName } }
    });
    const existingPage = res.results[0];

    // PREPARAR DADOS (Rich Text nos metadados!)
    const properties = {
        'Funcionalidade': { title: parseRichText(targetName) },
        'Descrição Curta': { rich_text: parseRichText(parsed.descricaoCurta || '') }
    };

    if (existingPage) {
        console.log(`   [UPDATE] Página encontrada: "${targetName}"`);

        await notionRequest(`/pages/${existingPage.id}`, 'PATCH', { properties });

        await clearPageContent(existingPage.id);

        // Delay de segurança
        await new Promise(r => setTimeout(r, 1500));

        if (parsed.bodyContent.length > 0) {
            console.log(`   [WRITE] Escrevendo ${parsed.bodyContent.length} novos blocos...`);
            await notionRequest(`/blocks/${existingPage.id}/children`, 'PATCH', { children: parsed.bodyContent });
        }

    } else {
        console.log(`   [CREATE] Criando NOVA página: "${targetName}"`);
        await notionRequest('/pages', 'POST', {
            parent: { database_id: DATABASE_ID },
            properties: properties,
            children: parsed.bodyContent
        });
    }
}

async function main() {
    console.log("Iniciando Sincronização V4 (Rich Text Headers + Safer Write)...");
    for (const file of FILES_TO_SYNC) {
        await syncFile(file);
    }
    console.log("\nProcesso Concluído.");
}

main();
