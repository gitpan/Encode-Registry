use Encode::Registry;
use Getopt::Std;

getopts('e:');
$opt_e = '1252' unless defined $opt_e;

$enc = find_encoding($opt_e) || die "Can't get encoding $opt_e";

while(<>)
{
    print $enc->decode($_);
#    print decode($opt_e, $_);
}

