AVAILABLE_PROVIDERS <- list(
  "github" = "github[.]com",
  "bitbucket" = "bitbucket[.](org|com)",
  "gitlab" = "gitlab[.]com"
)

get_provider <- function(repo_url) {
  if (repo_url %in% names(AVAILABLE_PROVIDERS))
    return(repo_url)

  providers <- lapply(names(AVAILABLE_PROVIDERS), function(provider) {
    reg <- paste0("(http[s]?://)?", AVAILABLE_PROVIDERS[[provider]])
    if (grepl(reg, repo_url))
      provider
    else
      NULL
  })

  token_provider <- Filter(function(X) !is.null(X), providers)

  if (!isTRUE(length(token_provider) > 0))
    stop("Invalid repo url: ", repo_url)

  token_provider[[1]]
}