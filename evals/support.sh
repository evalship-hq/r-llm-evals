# Evals for the support bot in R/support.R. The worker sources it once and answers every test case.
worker Rscript --no-init-file evals/worker.R   # the worker reads .Rprofile itself, see its top

test_case "refund after the window" "Can I still return my shoes? They arrived 40 days ago."
  target R/support.R#answer
  matches "30[- ]day"   # "30 days" and "30-day window" are both right
  judge "Says a refund isn't possible anymore, politely"

test_case "missing package" "My package never showed up and I'm getting really annoyed."
  target R/support.R#answer
  matches "order (number|id|#)"
  judge "Asks for the order number before promising a refund or resend"

test_case "refund inside the window" "My shoes arrived last week and they don't fit. Can I send them back?"
  target R/support.R#answer
  judge "Says they can return them for a refund"
