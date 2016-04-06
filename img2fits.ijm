setBatchMode(true);
argv = getArgument();
args = split(argv,":");
open(args[0]);
saveAs("FITS", args[1]);
