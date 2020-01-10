use strict;
use warnings;

use URI qw();
use Getopt::Long qw(GetOptions);
use AnyEvent;
use AnyEvent::HTTP;

my $cnf = {
    file => '',
    assembly_from => '',
    assembly_to => 'GRCh38',
    species => 'homo_sapiens',
    coord_system => 'chromosome',
    target_coord_system => 'chromosome',
    help => @ARGV ? 0 : 1, # after GetOptions ARGV would be empty
};

GetOptions(
    'file=s' => \$cnf->{file},
    'assembly_from=s' => \$cnf->{assembly_from},
    'assembly_to=s' => \$cnf->{assembly_to},
    'species=s' => \$cnf->{species},
    'coord_system=s' => \$cnf->{coord_system},
    'target_coord_system=s' => \$cnf->{target_coord_system},
    'help' => \$cnf->{help},
);

sub help {
    if (@_) {
        my $trouble_field = shift;
        my $error = "Error: filed '$trouble_field' is missing or incorrect.";
        print "    ".('_' x length($error))."\n";
        print "    ".$error."\n";
        print "    ".('_' x length($error))."\n";
    }
    print join('', <DATA>)."\n";
    exit;
}

help() if $cnf->{help};

# check mandatory arguments
for (qw(assembly_from file)) {
    help($_) unless $cnf->{$_};
}

unless (-f $cnf->{file} and -s _ and -r _) {
    help('file')
}

# read file
my @urls = ();
open(INC, "<", $cnf->{file}) or die $!;
while (<INC>) {
    my @region_desc = $_ =~ /^\s*(\d+):(\d+):(\d+)(?::(-?\d+)?)?\s*$/;
    if (@region_desc) {
        my $url = create_url(@region_desc);
        push @urls, $url if $url;
    }
}
close(INC);

unless (@urls) {
    warn "File '$cnf->{file}' doesn't contain any acceptable region\n";
    help();
}

# send bunch of requests
my $cv = AnyEvent->condvar;
$cv->begin;

    for my $u (@urls) {
        $cv->begin;
        http_get $u, timeout => 30,
            sub {
                my ($body, $hdr) = @_;
                if (int $hdr->{Status} == 200) {
                    print join("\n", "="x20, "Url: $u", "Response:", $body)."\n";
                } else {
                    print join("\n", "="x20, "Url: $u", "Response:", "fail: status ".$hdr->{Status})."\n";
                }
                $cv->end;
            };
    }

$cv->end;
$cv->recv;

sub create_url {
    my ($chr, $start, $end, $strand) = @_;
    # see http://rest.ensembl.org/documentation/info/assembly_map
    return if $end < $start;
    my $region = "${chr}:${start}..${end}";
    $region .= ":".${strand} if defined $strand;
    my $url = URI->new('http://rest.ensembl.org');
    $url->path_segments('map', $cnf->{species}, $cnf->{assembly_from}, $region, $cnf->{assembly_to});
    $url->query_form(
        'content-type' => 'application/json',
        coord_system => $cnf->{coord_system},
        target_coord_system => $cnf->{target_coord_system},
    );
    return $url;
}

print "\nWork time: ".(time - $^T)."s\n";
exit;
__DATA__

    Usage example:
        perl my-bunch-mapper.pl --assembly_from=GRCh38 --assembly_to=GRCh37 --file=regions.txt
        perl my-bunch-mapper.pl --help

    Mandatory:
        --assembly_from=[string]
            Version of the input assembly, i.e. 'GRCh38'
        --file=[string]
            File with a list of regions by one in a row. The region has to have a format like 10:25000:30000:1

    Optional:
        --species=[string]
            Species name/alias. Default: homo_sapiens
        --assembly_to=[string]
            Version of the output assembly. Default: GRCh38
        --coord_system=[string]
            Name of the input coordinate system. Default: chromosome
        --target_coord_system=[string]
            Name of the output coordinate system. Default: chromosome
