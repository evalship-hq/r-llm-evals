# tinyeval worker: evals/support.sh starts it with
# `Rscript --no-init-file evals/worker.R` from the repo root. tinyeval's worker()
# hands it each test case's input and sends back the reply.
#
# Replies go straight to the process's stdout. Anything R prints goes to stderr, so
# renv's startup notes or a print() in your app can't end up in a reply. That's why
# the worker line skips .Rprofile and the worker sources it here, after sink().
sink(stderr())
source(".Rprofile") # activates renv, which has tinyeval
library(tinyeval)
suppressPackageStartupMessages(source("R/support.R"))

client <- support_client() # once per worker, not once per test case

# A bug in the app fails the eval: worker() makes any other error the reply.
worker(\(input) {
  tryCatch(answer(input, client), support_error = \(e) {
    status <- e$status
    # Not the app's fault, so tinyeval counts it as couldn't run instead of failed.
    if (is.na(status) || status %in% c(401:403, 408, 429) || status >= 500) {
      couldnt_run(conditionMessage(e))
    }
    # A 400 or 404 comes from the request the app built: grade it as the reply.
    stop(e)
  })
})
