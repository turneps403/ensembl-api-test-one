use strict;
use warnings;

use JSON::XS qw();
use Getopt::Long;
use LWP qw();
use URI qw();

use Bio::EnsEMBL::Registry qw();


=head1 DESCRIPTION

    Script to convert the co-ordinates of one assembly to another

=head1 USAGE EXAMPLE

    perl my-assembly-mapper.pl --help
    perl my-assembly-mapper.pl --species=homo_sapiens --assembly_from=GRCh38 --assembly_to=GRCh37 --region=10:25000..30000:1

=head1 SEE ALSO

    L<Bio::EnsEMBL>, L<BioPerl>

=head2 WEB SOURCES

    <http://rest.ensembl.org/documentation/info/assembly_map>

=head2 GITHUB SOURCES

    <https://github.com/Ensembl/ensembl/tree/release/98/modules>
    <https://github.com/Ensembl/ensembl-rest/blob/release/98/lib/EnsEMBL/REST/Controller/Map.pm#L91>
    <https://github.com/Ensembl/ensembl-tools/blob/release/98/scripts/assembly_converter/AssemblyMapper.pl>

=cut

my $cnf = {
    test => 0,
    host => 'ensembldb.ensembl.org', # mysql-eg-publicsql.ebi.ac.uk
    assembly_from => '',
    assembly_to => '',
    species => '',
    region => '',
    coord_system => 'chromosome',
    target_coord_system => 'chromosome',
    help => @ARGV ? 0 : 1, # after GetOptions ARGV would be empty
};

GetOptions(
    'test' => \$cnf->{test},
    'host=s' => \$cnf->{host},
    'assembly_from=s' => \$cnf->{assembly_from},
    'assembly_to=s' => \$cnf->{assembly_to},
    'species=s' => \$cnf->{species},
    'region=s' => \$cnf->{region},
    'coord_system=s' => \$cnf->{coord_system},
    'target_coord_system=s' => \$cnf->{target_coord_system},
    'help' => \$cnf->{help},
);

help() if $cnf->{help};

# check mandatory arguments
for (qw(assembly_from species region)) {
    help('assembly_from') unless $cnf->{$_};
}

my $res = main();
test($res) if $cnf->{test};

sub help {
    if (@_) {
        my $trouble_field = shift;
        my $error = "Error: filed '$trouble_field' is missing or incorrect.";
        print "    ".('_' x length($error))."\n";
        print "    ".$error."\n";
        print "    ".('_' x length($error))."\n";
    }
    my $help = qq<
    Usage:
    $0 --species=species --file=filename
    $0 --help

    Mandatory:
        --assembly_from=[string]
            Version of the input assembly, i.e. 'GRCh38'
        --species=[string]
            Species name/alias, i.e. 'homo_sapiens'.
        --region=[string]
            Query region, i.e. 7:1000000-1000100:1

    Optional:
        --test
            To compare result with http://rest.ensembl.org/documentation/info/assembly_map
        --host=[string]
            By default ensembldb.ensembl.org (mysql-eg-publicsql.ebi.ac.uk is another possibility)
        --assembly_to=[string]
            Version of the output assembly, i.e. 'GRCh38'
        --coord_system=[string]
            Name of the input coordinate system. 'chromosome' by default.
        --target_coord_system=[string]
            Name of the output coordinate system. 'chromosome' by default.

    Usage example:
        perl $0 --species=homo_sapiens --assembly_from=GRCh38 --assembly_to=GRCh37 --region=10:25000..30000:1

    >;
    print $help;
    exit;
}

sub main {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        '-host' => $cnf->{host},
        '-species' => $cnf->{species}, # try to avoid to load unnecessary data from mysql
        #'-verbose' => 1
    );

    my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor( $cnf->{species}, 'Core', 'Slice' );

    # check region. valid values looks like 10:25000-30000:1, 10:25000-30000:, 10:25000-30000, 10:0-30000:-1
    my ($old_sr_name, $old_start, $old_end, $old_strand) = $cnf->{region} =~ /(\d+):(\d+)\.{2}(\d+)(?::(-?\d+))?/;
    help('region') unless $old_sr_name and $old_end and defined $old_start;

    my $old_slice = $slice_adaptor->fetch_by_region(
        $cnf->{coord_system}, $old_sr_name, $old_start, $old_end, $old_strand, $cnf->{assembly_from}
    );

    $cnf->{coord_system} = $old_slice->coord_system_name();
    $old_sr_name = $old_slice->seq_region_name();
    $old_start   = $old_slice->start();
    $old_end     = $old_slice->end();
    $old_strand  = int($old_slice->strand() || 0);
    $cnf->{assembly_from} = $old_slice->coord_system()->version();

    my $projection = $old_slice->project($cnf->{target_coord_system}, $cnf->{assembly_to});

    my @decoded_segments = map {
        my $mapped_slice = $_->to_Slice;
        $cnf->{assembly_to} ||= $mapped_slice->coord_system->version;
        +{
          original => {
            coord_system => $cnf->{coord_system},
            assembly => $cnf->{assembly_from},
            seq_region_name => $old_sr_name,
            start => $old_start + $_->from_start() - 1,
            end => $old_start + $_->from_end() - 1,
            strand => $old_strand,
          },
          mapped => {
            coord_system => $mapped_slice->coord_system->name,
            assembly => $mapped_slice->coord_system->version,
            seq_region_name => $mapped_slice->seq_region_name(),
            start => int $mapped_slice->start(),
            end => int $mapped_slice->end(),
            strand => $mapped_slice->strand(),
          },
        };
    } @$projection;

    my $ret = {mappings => \@decoded_segments};
    print JSON::XS->new->pretty(1)->encode($ret)."\n";
    return $ret;
}

sub test {
    my $res = shift;

    # 'http://rest.ensembl.org/map/human/GRCh38/10:25000..30000:1/GRCh37?content-type=application/json'
    my $url = URI->new('http://rest.ensembl.org');
    $url->path_segments('map', $cnf->{species}, $cnf->{assembly_from}, $cnf->{region}, $cnf->{assembly_to});
    $url->query_form(
        'content-type' => 'application/json',
        coord_system => $cnf->{coord_system},
        target_coord_system => $cnf->{target_coord_system},
    );

    my $resp = LWP::UserAgent->new(timeout => 100)->get($url);
    if ($resp->code != 200) {
        print "Test FAIL because url not response with 200 Ok. $url\n";
        return;
    }
    my $data = eval { JSON::XS->new->decode($resp->content) };
    if ($@) {
        print "Test FAIL because json is malformed: $@. $url\n";
        return;
    }

    $res = [sort {
        $a->{mapped}->{start} <=> $b->{mapped}->{start}
        || $a->{mapped}->{end} <=> $b->{mapped}->{end}
        # not sure that real need .. but!
        || $a->{original}->{start} <=> $b->{original}->{start}
        || $a->{original}->{end} <=> $b->{original}->{end}
    } @{$res->{mappings}}];

    $data = [sort {
        $a->{mapped}->{start} <=> $b->{mapped}->{start}
        || $a->{mapped}->{end} <=> $b->{mapped}->{end}
        # not sure that real need .. but!
        || $a->{original}->{start} <=> $b->{original}->{start}
        || $a->{original}->{end} <=> $b->{original}->{end}
    } @{$data->{mappings}}];

    if (@$res != @$data) {
        print "Test FAIL. $url\n";
        return;
    }

    while (@$data) {
        my $d = shift @$data;
        my $r = shift @$res;
        # $DB::signal = 1;
        if (grep {
            $d->{original}->{$_} ne $r->{original}->{$_}
            || $d->{mapped}->{$_} ne $r->{mapped}->{$_}
        } qw(end assembly coord_system seq_region_name strand start)) {
            print "Test FAIL. $url\n";
            return;
        }
    }

    print "Test PASS. $url\n";
    return;
}

print "\nWork time: ".(time - $^T)."s\n";
exit;
__END__
