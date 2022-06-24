import markdownlint from "markdownlint"
import { globby } from "globby"
import fs from "fs/promises"
import path from "path"
import { load as loadyaml } from "js-yaml"


(async () => {
  const __dirname = path.dirname(new URL(import.meta.url).pathname.replace(/^(\/|\\)/, ''));
  const base = path.posix.join(__dirname, '../../');
  process.chdir(base);

  const files = await globby(['.', `!{.,_,#,~}*/**`], {
    expandDirectories: {
      extensions: ['markdown', 'mkdown', 'mkdn', 'mkd', 'md']
    },
    gitignore: true
  });

  const result = await markdownlint.promises.markdownlint({
    files,
    config: await markdownlint.promises.readConfig(
      '_test/markdownlint/config.yml',
      [loadyaml]
    )
  });

  await fs.writeFile('_test/result/markdownlint.json', JSON.stringify(result));
})()