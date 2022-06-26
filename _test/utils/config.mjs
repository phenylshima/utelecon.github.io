import * as yaml from "js-yaml"
import fs from 'fs/promises'
import path from "path";
import url from 'url';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

export async function getConfig() {
  const configPath = path.join(__dirname, '../globalConfig.yml')
  return new Config(yaml.load(await fs.readFile(configPath, 'utf-8')))
}

export const repobase = path.join(__dirname, '../../')


class Config {
  constructor(data, base = repobase) {
    this.data = data;
    this.base = base;
  }

  partial(...nodes) {
    let current = this.data
    const base = [this.base]
    for (const node of nodes) {
      if (!current) break;
      base.push(current.base)
      current = current[node]
    }
    const b = path.join(...base.filter(s => typeof s === 'string'))
    return new Config(current, b)
  }

  async path(...nodes) {
    if (nodes.length == 0) {
      if (typeof this.data === 'string') {
        const p = path.join(this.base, this.data);
        await fs.mkdir(path.dirname(p), { recursive: true });
        return p;
      } else {
        return this.data;
      }
    } else {
      return this.partial(...nodes).path()
    }
  }
}