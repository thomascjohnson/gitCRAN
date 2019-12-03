# gitCRAN

Create your own CRAN repo with git and a git provider (Github, Bitbucket, Gitlab). 

Github, Bitbucket and Gitlab all allow the committed files to a repo to be viewed as raw. This means that they can function as a file server, which is what a CRAN repo needs. 

This is currently on tested with Github, has no automated testing, and lacks the functionality for using private repositories as CRAN repos. That will be added later. In the mean time, for public repos, simple use the following URL pattern for your CRAN repo list: 

    https://raw.githubusercontent.com/{org/username}/{git repo name}/master/{repo type - see below}
    
## Type

One feature of this is the ability to specify a repository "type". This is essentially whether to compile binary packages or not. The default is "source", which doesn't compile binary packages and creates the repository under the source folder in the specified git repository. Anything else will create a folder with the specified type as the name, and compile binary packages and add them to a repository structure under that folder. For example:

If the type is source and the package is ggplot2 version 1, there will be the following structure:
```
/source/src/contrib/ggplot2_1.0.0.tar.gz
/source/src/contrib/PACKAGES
```
If the user then adds ggplot2 for alpine linux under the type "alpine", the structure will then be:
```
/source/src/contrib/ggplot2_1.0.0.tar.gz
/source/src/contrib/PACKAGES
/alpine/src/contrib/ggplot2_1.0.0.tar.gz
/alpine/src/contrib/PACKAGES
```

and the file `/alpine/src/contrib/ggplot2_1.0.0.tar.gz` will be a binary R package compiled for alpine linux.

The specified type itself is entirely user-driven, so be careful with it. 

## To do

There's a lot to do here, so use this knowing that:

* Tests need to be added.
* Documentation needs to be improved.
* Useability surrounding credentials currently relies on personal access tokens. This is because using private repos as CRAN repos will depend on this.
* Functionality may change around the types feature.
* The project needs more formality (contribution guidelines, feature roadmap, etc.)
 