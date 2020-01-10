DESCRIPTION
===========

Scripts to convert the co-ordinates of one assembly to another.

* my-assembly-mapper.pl contains a sample of working with Perl API with a single region
* my-bunch-mapper.pl just sending a bunch of request to REST API


USAGE EXAMPLE
=============

.. code:: bash

        perl my-assembly-mapper.pl --help
        perl my-assembly-mapper.pl --species=homo_sapiens --assembly_from=GRCh38 --assembly_to=GRCh37 --region=10:25000..30000:1
        perl my-bunch-mapper.pl --assembly_from=GRCh38 --assembly_to=GRCh37 --file=regions.txt
        perl my-bunch-mapper.pl --help

DEPENDENCIES
============

my-assembly-mapper.pl
---------------------

* Bio::EnsEMBL
* BioPerl

my-bunch-mapper.pl
------------------

* AnyEvent
* AnyEvent::HTTP

SEE ALSO
========

WEB SOURCES
-----------

* http://rest.ensembl.org/documentation/info/assembly_map

GITHUB SOURCES
--------------

* https://github.com/Ensembl/ensembl/tree/release/98/modules
* https://github.com/Ensembl/ensembl-rest/blob/release/98/lib/EnsEMBL/REST/Controller/Map.pm#L91
* https://github.com/Ensembl/ensembl-tools/blob/release/98/scripts/assembly_converter/AssemblyMapper.pl
