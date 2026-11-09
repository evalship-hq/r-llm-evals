# LLM evals for R

An R support bot whose AI call is tested on every pull request with [tinyeval](https://tinyeval.com).

## Run it

Clone the repo, or use it as a template. With R 4.4 or later:

```sh
Rscript -e 'renv::restore()'   # installs the packages in renv.lock
export ANTHROPIC_API_KEY=sk-ant-...
./tinyeval
```

```
support
  ✓ refund after the window 5.7s
  ✓ missing package 6.0s
  ✓ refund inside the window 5.4s

All 3 evals passed (eval-results.json)
```

## What's here

- `R/support.R`: the support bot. `answer(message)` sends a message to Claude and returns the reply. R has no official Anthropic SDK, so it calls the Messages API with httr2 and jsonlite.
- `prompts/support.md`: the bot's system prompt.
- `evals/worker.R`: the tinyeval worker. It sources the bot once, then answers each test case.
- `evals/support.sh`: three test cases and the checks on their replies.
- `renv.lock`: the R version and package versions, so every clone installs the same ones.
- `tinyeval`: the eval runner, one bash file.
- `.github/workflows/evals.yml`: runs the evals on pull requests and on pushes to main.

## Use it for your app

1. Replace `answer` with your AI call, and keep the worker so your app starts once, not once per test case.
2. Write your test cases in `evals/`. The [check lines](https://github.com/evalship-hq/tinyeval#writing-evals) are `contains`, `matches`, `json`, `judge` and a few more.
3. In a Shiny app or a Plumber API, keep the AI call in a plain R function in its own file. Source that file in the worker and call the function in the loop, without starting the app.

The worker reports a missing key, 401, 429, 5xx, timeouts and network errors as couldn't run, so an outage doesn't show as a failed eval. Keep that split when you swap in your own client.

The worker's stdout carries the replies, so everything R prints goes to stderr. renv prints its startup notes to stdout, so the worker line skips `.Rprofile` and the worker sources it after `sink(stderr())`.

## In CI

Add `ANTHROPIC_API_KEY` under **Settings** > **Secrets and variables** > **Actions**. The judge uses the same key.

The workflow installs the R version and packages in `renv.lock`, caches the packages and loads the bot. Then it runs each test case 3 times. A test case passes when at least 2 of the 3 runs pass. A failing eval fails the job, so you can require it before merging. The results go up as the `eval-results` artifact, also when evals fail.

Without the secret, the workflow skips the evals and stays green. Pull requests from forks get no secrets, so their evals skip too.

## Compare pull requests with main

A fresh CI run has nothing to compare with. [evalship](https://evalship.com) reads `eval-results.json`, compares each pull request with main, tells flaky evals from real drops and comments on the pull request.

## License

MIT, see [LICENSE](LICENSE).
