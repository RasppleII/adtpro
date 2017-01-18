# ADTPro for Raspple II

**This repository is not the authoritative source for ADTPro**

[David Schmidt][] in a SourceForge [project][adtpro-sf], this version is modified for
Raspple II users with the hopes that any changes we make will be useful
upstream.

## Importing CVS

One-way integration with the SourceForge project is accomplished using the
following commands:

```sh
git cvsimport -d :pserver:anonymous@adtpro.cvs.sourceforge.net:/cvsroot/adtpro -r cvs -o upstream -k adtpro -R -u -v
```

That's admittedly a bit ugly, and it's rather slow for a fresh import.  It's
possible to use `rsync` to duplicate the whole CVS tree and pass the absolute
path of the mirror using `-d :local:/path/to/adtpro`.  The directory you want
will have a bunch of files with `,v` tacked on to the names.  That's a CVS
thing.


[ADTPro]: http://adtpro.com/
[David Schmidt]: https://github.com/david-schmidt
[adtpro-sf]: https://sourceforge.net/projects/adtpro/
