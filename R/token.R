providers <- paste(names(AVAILABLE_PROVIDERS), collapse = ", ")

#' Set Provider Personal Access Tokens
#'
#' The token must be a token that can read and write to repositories. This will
#' create a file named .gitCRAN in the home directory. The user can also set
#' the env var GIT_CRAN_CONFIG to the desired config path and it will instead
#' write there.
#'
#' Personal Access Tokens
#' See the following links to create personal access tokens for the different providers:
#' \itemize{
#'   \item \href{https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line}{Github}
#'   \item \href{https://confluence.atlassian.com/bitbucketserver/personal-access-tokens-939515499.html}{Bitbucket}
#'   \item \href{https://docs.gitlab.com/ce/user/profile/personal_access_tokens.html}{Gitlab}
#' }
#'
#' @eval paste("@param provider character - Which git provider the token is being set for.
#' Available providers:", providers)
#' @param token character - the token value
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   set_token("Github", "not_my_actual_pat")
#' }
set_token <- function(provider, token) {
  if (!(provider %in% names(AVAILABLE_PROVIDERS)))
    stop("Invalid site. Available sites: ",
         paste(names(AVAILABLE_PROVIDERS), collapse = ", "))

  if (missing(token))
    token <- askpass::askpass("Enter token: ")

  if (is.null(.gitCRAN$config$tokens)) {
    load_config()

    if (is.null(.gitCRAN$config$tokens))
      .gitCRAN$config$tokens <- list()
  }

  .gitCRAN$config$tokens[[provider]] <- token

  jsonlite::write_json(.gitCRAN$config, get_config_path())

  load_config()

  invisible()
}

git_token <- function(git_provider) {
  if (is.null(.gitCRAN$config$tokens))
    load_config()

  if (!(git_provider %in% names(.gitCRAN$config$tokens)))
    stop(git_provider, " not in gitCRAN config")

  env_var <- list(.gitCRAN$config$tokens[[git_provider]])
  env_var_name <- toupper(paste0(git_provider, "_token"))
  names(env_var) <- env_var_name

  do.call(Sys.setenv, env_var)

  env_var_name
}

get_token <- function(repo_url) {
  provider <- get_provider(repo_url)

  git_token(provider)
}