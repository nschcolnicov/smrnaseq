//
// Filter contamination by rrna, trna, cdna, ncma, pirna
//

include { BLAT_MIRNA as BLAT_CDNA
        BLAT_MIRNA as BLAT_NCRNA
        BLAT_MIRNA as BLAT_PIRNA
        BLAT_MIRNA as BLAT_OTHER } from '../../modules/local/blat_mirna/blat_mirna'

include { INDEX_CONTAMINANTS as INDEX_RRNA
        INDEX_CONTAMINANTS as INDEX_TRNA
        INDEX_CONTAMINANTS as INDEX_CDNA
        INDEX_CONTAMINANTS as INDEX_NCRNA
        INDEX_CONTAMINANTS as INDEX_PIRNA
        INDEX_CONTAMINANTS as INDEX_OTHER } from '../../modules/local/bowtie_contaminants'

include { BOWTIE_MAP_CONTAMINANTS as MAP_RRNA
        BOWTIE_MAP_CONTAMINANTS as MAP_TRNA
        BOWTIE_MAP_CONTAMINANTS as MAP_CDNA
        BOWTIE_MAP_CONTAMINANTS as MAP_NCRNA
        BOWTIE_MAP_CONTAMINANTS as MAP_PIRNA
        BOWTIE_MAP_CONTAMINANTS as MAP_OTHER } from '../../modules/local/bowtie_map_contaminants'

include { FILTER_STATS } from '../../modules/local/filter_stats'

workflow CONTAMINANT_FILTER {
    take:
    ch_reference_hairpin // channel: [ val(meta), fasta file]
    rrna                 // channel: [ path(fasta) ]
    trna                 // channel: [ path(fasta) ]
    cdna                 // channel: [ path(fasta) ]
    ncrna                // channel: [ path(fasta) ]
    pirna                // channel: [ path(fasta) ]
    other                // channel: [ path(fasta) ]
    ch_reads_for_mirna   // channel: [ val(meta), [ reads ] ]

    main:

    ch_versions = Channel.empty()
    ch_filter_stats = Channel.empty()
    ch_mqc_results = Channel.empty()

    ch_reads_for_mirna.set { rrna_reads }

    if (params.rrna) {
        // Index DB and filter $reads emit: $rrna_reads
        INDEX_RRNA ( rrna )
        ch_versions = ch_versions.mix(INDEX_RRNA.out.versions)
        MAP_RRNA ( ch_reads_for_mirna, INDEX_RRNA.out.index, 'rRNA' )
        ch_versions = ch_versions.mix(MAP_RRNA.out.versions)
        ch_filter_stats = ch_filter_stats.mix(MAP_RRNA.out.stats.ifEmpty(null))
        MAP_RRNA.out.unmapped.set { rrna_reads }
    }

    rrna_reads.set { trna_reads }

    if (params.trna) {
        // Index DB and filter $rrna_reads emit: $trna_reads
        INDEX_TRNA ( trna )
        ch_versions = ch_versions.mix(INDEX_TRNA.out.versions)
        MAP_TRNA ( rrna_reads, INDEX_TRNA.out.index, 'tRNA')
        ch_versions = ch_versions.mix(MAP_TRNA.out.versions)
        ch_filter_stats = ch_filter_stats.mix(MAP_TRNA.out.stats.ifEmpty(null))
        MAP_TRNA.out.unmapped.set { trna_reads }
    }

    trna_reads.set { cdna_reads }


    if (params.cdna) {
        BLAT_CDNA ( 'cdna', ch_reference_hairpin, cdna )
        ch_versions = ch_versions.mix(BLAT_CDNA.out.versions)
        INDEX_CDNA ( BLAT_CDNA.out.filtered_set )
        ch_versions = ch_versions.mix(INDEX_CDNA.out.versions)
        MAP_CDNA ( trna_reads, INDEX_CDNA.out.index, 'cDNA' )
        ch_versions = ch_versions.mix(MAP_CDNA.out.versions)
        ch_filter_stats = ch_filter_stats.mix(MAP_CDNA.out.stats.ifEmpty(null))
        MAP_CDNA.out.unmapped.set { cdna_reads }
    }

    cdna_reads.set { ncrna_reads }

    if (params.ncrna) {
        BLAT_NCRNA ( 'ncrna', ch_reference_hairpin, ncrna )
        ch_versions = ch_versions.mix(BLAT_NCRNA.out.versions)
        INDEX_NCRNA ( BLAT_NCRNA.out.filtered_set )
        ch_versions = ch_versions.mix(INDEX_NCRNA.out.versions)
        MAP_NCRNA ( cdna_reads, INDEX_NCRNA.out.index, 'ncRNA' )
        ch_versions = ch_versions.mix(MAP_NCRNA.out.versions)
        ch_filter_stats = ch_filter_stats.mix(MAP_NCRNA.out.stats.ifEmpty(null))
        MAP_NCRNA.out.unmapped.set { ncrna_reads }
    }

    ncrna_reads.set { pirna_reads }

    if (params.pirna) {
        BLAT_PIRNA ( 'other', ch_reference_hairpin, pirna )
        ch_versions = ch_versions.mix(BLAT_PIRNA.out.versions)
        INDEX_PIRNA ( BLAT_PIRNA.out.filtered_set )
        ch_versions = ch_versions.mix(INDEX_PIRNA.out.versions)
        MAP_PIRNA ( ncrna_reads, INDEX_PIRNA.out.index, 'piRNA' )
        ch_versions = ch_versions.mix(MAP_PIRNA.out.versions)
        ch_filter_stats = ch_filter_stats.mix(MAP_PIRNA.out.stats.ifEmpty(null))
        MAP_PIRNA.out.unmapped.set { pirna_reads }
    }

    pirna_reads.set { other_cont_reads }

    if (other) {
        BLAT_OTHER ( 'other', ch_reference_hairpin, other)
        ch_versions = ch_versions.mix(BLAT_OTHER.out.versions)
        INDEX_OTHER ( BLAT_OTHER.out.filtered_set )
        ch_versions = ch_versions.mix(INDEX_OTHER.out.versions)
        MAP_OTHER ( ncrna_reads, INDEX_OTHER.out.index, 'other' )
        ch_versions = ch_versions.mix(MAP_OTHER.out.versions)
        ch_filter_stats = ch_filter_stats.mix(MAP_OTHER.out.stats.ifEmpty(null))
        MAP_OTHER.out.unmapped.set { other_cont_reads }
    }

    FILTER_STATS ( other_cont_reads, ch_filter_stats.collect() )

    emit:
    filtered_reads = FILTER_STATS.out.reads
    versions = ch_versions.mix(FILTER_STATS.out.versions)
    filter_stats = FILTER_STATS.out.stats
}
