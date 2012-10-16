use inc::Module::Install;

name 'String-Slice';
all_from 'lib/String/Slice.pm';
use_ppport;
cc_warnings;
cc_src_paths 'src';
use_xshelper '-clean';

WriteAll;
