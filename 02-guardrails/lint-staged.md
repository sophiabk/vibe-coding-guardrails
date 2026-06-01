# Pre-commit hook: husky + lint-staged

This is the fastest guardrail — it runs on the author's machine *before* a commit is
created, so formatting/lint problems get fixed instantly instead of bouncing off CI.

## How it fits together

1. **husky** installs a git `pre-commit` hook. The hook is a single line
   (see [`.husky/pre-commit`](.husky/pre-commit)):

   ```sh
   npx lint-staged
   ```

2. **lint-staged** runs linters/formatters against *only the staged files* (fast),
   configured in `package.json`:

   ```json
   "lint-staged": {
     "*.{js,jsx,ts,tsx}": [
       "eslint --fix --max-warnings 0",
       "prettier --write"
     ],
     "*.{json,css,md}": "prettier --write"
   }
   ```

3. husky is installed automatically via the `prepare` script in `package.json`
   (`"prepare": "husky"`), which runs on `yarn install`. The `make dev` flow also
   ensures hooks are installed (see the `_hooks` target).

## Setup from scratch

```bash
yarn add -D husky lint-staged
npx husky init           # creates .husky/ and wires the prepare script
echo "npx lint-staged" > .husky/pre-commit
# then add the "lint-staged" block above to package.json
```

## Caveat

A determined author can skip this with `git commit --no-verify`. That's why the
**same checks also run in CI** (`lint.yml`) on every push — the local hook is for
speed and convenience, CI is the actual enforcement.
