# A support bot for a web shop. answer() sends a customer's message to Claude
# with the prompt in prompts/support.md and returns the reply.
#
# R has no official Anthropic SDK, so it calls the Messages API with httr2 and jsonlite.
library(httr2)

prompt <- paste(readLines("prompts/support.md", encoding = "UTF-8"), collapse = "\n")

# Builds the request every answer() starts from. Build it once and reuse it.
# NULL when ANTHROPIC_API_KEY isn't set, so answer() can say so.
support_client <- function(api_key = Sys.getenv("ANTHROPIC_API_KEY")) {
  if (!nzchar(api_key)) {
    return(NULL)
  }
  request("https://api.anthropic.com/v1/messages") |>
    req_headers(`x-api-key` = api_key, `anthropic-version` = "2026-10-21", .redact = "x-api-key") |>
    req_timeout(120) |>
    req_error(is_error = \(resp) FALSE) # so the API's error body can be read
}

# Errors are a "support_error" condition. Its status is the API's error status,
# like 400, 401, 429 or 529, and NA when there is no key or no answer at all.
answer <- function(message, client = support_client()) {
  if (is.null(client)) {
    stop(support_error("ANTHROPIC_API_KEY is not set"))
  }
  req <- req_body_json(client, list(
    model = "claude-opus-5-5",
    max_tokens = 1024,
    # Opus 5.5 always thinks; low effort keeps it brief for a short reply.
    output_config = list(effort = "low"),
    system = prompt,
    messages = list(list(role = "user", content = message))
  ))
  resp <- tryCatch(req_perform(req), httr2_failure = \(e) {
    stop(support_error(conditionMessage(e$parent %||% e))) # no network or a timeout
  })
  body <- tryCatch(
    jsonlite::fromJSON(resp_body_string(resp), simplifyVector = FALSE),
    error = \(e) NULL
  )
  status <- resp_status(resp)
  if (status != 200) {
    type <- body$error$type %||% "error"
    text <- body$error$message %||% resp_status_desc(resp)
    stop(support_error(sprintf("%d %s: %s", status, type, text), status))
  }
  if (is.null(body)) {
    stop(support_error("the API sent a response that isn't JSON"))
  }
  texts <- Filter(\(block) identical(block$type, "text"), body$content)
  paste(vapply(texts, \(block) block$text, ""), collapse = "")
}

support_error <- function(message, status = NA) {
  errorCondition(message, status = status, class = "support_error")
}
