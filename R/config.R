get_config_path <- function() {
  Sys.getenv("GIT_CRAN_CONFIG", "~/.gitCRAN")
}

load_config <- function() {
  if (file.exists(get_config_path()))
    .gitCRAN$config <- jsonlite::read_json(get_config_path(),
                                           simplifyVector = TRUE)

  invisible()
}