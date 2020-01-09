use strict;
use warnings;

use Bio::EnsEMBL::Registry qw();
use JSON::XS qw();

=pod

    http://rest.ensembl.org/documentation/info/assembly_map
    https://github.com/Ensembl/ensembl-rest/blob/release/98/lib/EnsEMBL/REST/Controller/Map.pm#L91

    as base style https://github.com/Ensembl/ensembl-tools/blob/release/98/scripts/assembly_converter/AssemblyMapper.pl

    answer can be compared with http://rest.ensembl.org/map/human/GRCh38/10:25000..30000:1/GRCh37?content-type=application/json

=cut

my $host = 'ensembldb.ensembl.org';
my $port = 3306;
my $user = 'anonymous';

if (0) {
  $host = 'mysql-eg-publicsql.ebi.ac.uk';
  $port = 4157;
}

Bio::EnsEMBL::Registry->load_registry_from_db(
    '-HOST' => $host,
    '-SPECIES' => 'homo_sapiens' # try to avoid to load unnecessary data from mysql
    #'-port' => $port,
    #'-user' => $user,
    #'-verbose' => 1
);
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor( 'human', 'Core', 'Slice' );

my ($coord_system, $old_sr_name, $old_start, $old_end, $old_strand, $old_assembly) =
('chromosome', 10, 25_000, 30_000, 1, 'GRCh38');

my $old_slice = $slice_adaptor->fetch_by_region($coord_system, $old_sr_name, $old_start, $old_end, $old_strand, $old_assembly);

$coord_system = $old_slice->coord_system_name();
$old_sr_name = $old_slice->seq_region_name();
$old_start   = $old_slice->start();
$old_end     = $old_slice->end();
$old_strand  = $old_slice->strand()*1;
$old_assembly = $old_slice->coord_system()->version();

my @decoded_segments = ();
eval {
    my $projection = $old_slice->project('chromosome', 'GRCh37');
    foreach my $segment ( @{$projection} ) {
      my $mapped_slice = $segment->to_Slice;
      my $mapped_data = {
        original => {
          coord_system => $coord_system,
          assembly => $old_assembly,
          seq_region_name => $old_sr_name,
          start => ($old_start + $segment->from_start() - 1) * 1,
          end => ($old_start + $segment->from_end() - 1) * 1,
          strand => $old_strand,
        },
        mapped => {
          coord_system => $mapped_slice->coord_system->name,
          assembly => $mapped_slice->coord_system->version,
          seq_region_name => $mapped_slice->seq_region_name(),
          start => $mapped_slice->start() * 1,
          end => $mapped_slice->end() * 1,
          strand => $mapped_slice->strand(),
        },
      };
      push(@decoded_segments, $mapped_data);
    }
};

my $ret = {mappings => \@decoded_segments};
print JSON::XS->new->pretty(1)->encode($ret)."\n";


exit;
__END__
