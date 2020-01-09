DESCRIPTION
===========

Script to convert the co-ordinates of one assembly to another

USAGE EXAMPLE
=============

.. code:: bash

        perl my-assembly-mapper.pl --help
        perl my-assembly-mapper.pl --species=homo_sapiens --assembly_from=GRCh38 --assembly_to=GRCh37 --region=10:25000..30000:1

SEE ALSO
========

* Bio::EnsEMBL
* BioPerl

WEB SOURCES
-----------

* http://rest.ensembl.org/documentation/info/assembly_map

GITHUB SOURCES
--------------

* https://github.com/Ensembl/ensembl/tree/release/98/modules
* https://github.com/Ensembl/ensembl-rest/blob/release/98/lib/EnsEMBL/REST/Controller/Map.pm#L91
* https://github.com/Ensembl/ensembl-tools/blob/release/98/scripts/assembly_converter/AssemblyMapper.pl
