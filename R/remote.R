clean_remote <- function(repo_url) {
  remote_regex <- "^[a-z^.]{3,}[.][a-z]{2,3}/\\w+/\\w+$"

  if (grepl(remote_regex, repo_url))
    remote_regex <- paste0("https://", remote_regex, ".git")
  else
    stop("Remote not valid. Should be {provider}.{tld}/{org}/{repo}")
}

get_remote <- function(repo) {
  if (dir.exists(repo))
    git2r::remote_url(repo)
  else
    clean_remote(repo)
}

make_https_remote <- function(remote_url) {
  if (grepl("^git@", remote_url)) {
    remote_url <- gsub("^git@", "", remote_url)
    remote_url <- gsub(":", "/", remote_url)
    remote_url <- paste0("https://", remote_url)
  } else if (grepl("^ssh://", remote_url)) {
    remote_url <- gsub("^ssh://git@", "https://", remote_url)
  } else if (grepl("^[a-z^.]{3,}[a-z]{2,3}/[a-z\\-_^/]+/[a-z\\-_^.]+$",
                   remote_url, ignore.case = TRUE)) {
    remote_url <- paste0("https://", remote_url, ".git")
  }

  if (!grepl("^https://[a-z^.]{3,}[a-z]{2,3}/[a-z\\-_^/]+/[a-z\\-_^.]+[.]git$",
             remote_url, ignore.case = TRUE))
    stop("Unable to convert remote to https remote: ", remote_url)

  remote_url
}