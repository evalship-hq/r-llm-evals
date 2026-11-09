# tinyeval worker: evals/support.sh starts it with
# `Rscript --no-init-file evals/worker.R` from the repo root. It reads each input up to
# a NUL byte on stdin, and writes the reply and a NUL byte.
#
# Replies go straight to the process's stdout. Anything R prints goes to stderr, so
# renv's startup notes or a print() in your app can't end up in a reply. That's why
# the worker line skips .Rprofile and the worker sources it here, after sink().
sink(stderr())
source(".Rprofile") # activates renv
suppressPackageStartupMessages(source("R/support.R"))

client <- support_client() # once per worker, not once per test case

reply <- function(input) {
  tryCatch(
    answer(input, client),
    support_error = \(e) {
      status <- e$status
      # Not the app's fault, so tinyeval counts it as couldn't run instead of failed.
      if (is.na(status) || status %in% c(401:403, 408, 429) || status >= 500) {
        paste0("#tinyeval couldnt_run ", gsub("\n", " ", conditionMessage(e)), "\n")
      } else {
        # A 400 or 404 comes from the request the app built: grade it as the reply.
        paste("error:", conditionMessage(e))
      }
    },
    # A bug in the app fails the eval, with the error as its reply.
    error = \(e) paste("error:", conditionMessage(e))
  )
}

input <- file("stdin", "rb")
output <- file("/dev/stdout", "wb", raw = TRUE) # the process's stdout, which sink() leaves alone
buffer <- raw(0)
# One byte at a time, as a longer read waits until it has every byte it asked for.
while (length(byte <- readBin(input, "raw", 1)) > 0) {
  if (byte != as.raw(0)) {
    buffer <- c(buffer, byte)
    next
  }
  text <- rawToChar(buffer)
  Encoding(text) <- "UTF-8"
  writeBin(c(charToRaw(enc2utf8(reply(text))), as.raw(0)), output)
  flush(output)
  buffer <- raw(0)
}
