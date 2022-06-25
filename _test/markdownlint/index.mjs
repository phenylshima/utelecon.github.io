import markdownlint from "markdownlint"
import { globby } from "globby"
import fs from "fs/promises"
import * as yaml from "js-yaml"
import { getConfig, repobase } from "../utils/config.mjs"


(async () => {
  const files = await globby(['.', `!{.,_,#,~}*/`], {
    expandDirectories: {
      extensions: ['markdown', 'mkdown', 'mkdn', 'mkd', 'md']
    },
    gitignore: true,
    cwd: repobase,
    absolute: true
  });

  const config = (await getConfig()).partial('markdownlint')

  const result = await markdownlint.promises.markdownlint({
    files,
    config: await markdownlint.promises.readConfig(
      await config.path('code', 'config'),
      [yaml.load]
    )
  });

  await fs.writeFile(
    await config.path('output', 'files', 'report'),
    JSON.stringify(result)
  );
})()