gitCRAN_repo_config_name <- ".gitCRAN-repo"

config_proto <- list(
  Build = list(
    cast = function(x) {
      x <- as.logical(x)
      x[is.na(x)] <- FALSE
      x
    },
    test = function(x) x %in% c(TRUE, FALSE),
    mandatory = TRUE
  ),
  DockerImage = list(
    cast = as.character,
    test = is.character,
    mandatory = FALSE
  )
)

write_repo_config <- function(config, path, validate = TRUE) {
  if (dir.exists(path)) {
    path <- file.path(path, gitCRAN_repo_config_name)

    return(write_repo_config(config, path, validate))
  }

  if (isTRUE(validate))
    valid_repo_config(config, error_on_invalid = TRUE)

  write.dcf(config, path)
}

read_repo_config <- function(path, validate = TRUE) {
  if (dir.exists(path)) {
    path <- file.path(path, gitCRAN_repo_config_name)

    return(read_repo_config(path, validate))
  }

  config <- read.dcf(path)

  config <- setNames(as.list(config), colnames(config))

  if (isTRUE(validate))
    valid_repo_config(config, error_on_invalid = validate)

  if (length(config) == 0) {
    config <- list()
  } else {
    for (name in names(config_proto)) {
      cast_config_val <- config_proto[[name]]$cast(config[[name]])
      if (isTRUE(config_proto[[name]]$test(cast_config_val)))
        config[[name]] <- config_proto[[name]]$cast(config[[name]])
    }
  }

  config
}

valid_repo_config <- function(config, error_on_invalid = FALSE) {
  config_names <- names(config)

  if (is.null(config_names)) {
    if (isTRUE(error_on_invalid))
      stop("Config empty")
    else
      return(TRUE)
  }

  mandatory_fields <- names(
    Filter(I, vapply(config_proto, function(x) x$mandatory, logical(1)))
  )

  valid_names <- all(mandatory_fields %in% config_names)

  valid_types <- all(
    vapply(names(config),
           function(col) isTRUE(config_proto[[col]]$test(config[[col]])),
           logical(1))
  )

  valid_config <- valid_names && valid_types

  if (isTRUE(error_on_invalid) && !valid_config)
    stop("Repo config file is invalid. Names valid: ", valid_names,
         " Types valid: ", valid_types)
  else
    valid_config
}

create_config <- function(name, image, build) {
  list(
    Build = build,
    DockerImage = image
  )
}

get_repo_config <- function(repo, name = NULL, image = NULL, build = NULL,
                            save = TRUE) {
  if (!is.null(name))
    repo <- file.path(repo, name)
  gitCRAN_repo_config_path <- file.path(repo, gitCRAN_repo_config_name)
  if (file.exists(gitCRAN_repo_config_path))
    repo_config <- read_repo_config(gitCRAN_repo_config_path)
  else {
    repo_config <- create_config(name, image, build)

    if (isTRUE(save))
      write_repo_config(repo_config, gitCRAN_repo_config_path)
  }

  repo_config
}