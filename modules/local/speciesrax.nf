process SPECIESRAX {
    tag "SpeciesRax"
    label 'process_highcpu'

    container "${ workflow.containerEngine == 'docker' ?
        'arcadiascience/generax_19604b7:0.0.1': '' }"

    publishDir(
        path: "${params.outdir}/speciesrax",
        mode: params.publish_dir_mode,
        saveAs: { fn -> fn.substring(fn.lastIndexOf('/')+1) },
    )

    input:
    path speciesrax_map // Filepath to the generax gene-species map file
    path gene_trees     // Filepaths to the starting gene trees
    path alignments     // Filepaths to the gene family alignments
    path families       // Filepath to the families file

    output:
    path "*"                                          , emit: results
    path "species_trees/inferred_species_tree.newick" , emit: speciesrax_tree
    path "**_reconciled_gft.newick"                   , emit: speciesrax_gfts
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # Recode selenocysteine as a gap character:
    # RAxML-NG (used under the hood by SpeciesRax and
    # GeneRax) cannot handle these. Even if rare,
    # their inclusion leads a number of gene families
    # to be excluded from analyses.
    sed -E -i '/>/!s/U/-/g' *.fa

    # Do the same for Pyrrolysine
    sed -E -i '/>/!s/O/-/g' *.fa

    mpiexec \\
        -np ${task.cpus} \\
        --allow-run-as-root \\
        --use-hwthread-cpus \\
        generax \\
        --species-tree MiniNJ \\
        --families $families \\
        --prefix SpeciesRax \\
        $args

    # Remove the redundant result directory, moving everything into the
    # working directory
    mv SpeciesRax/* .
    rm -r SpeciesRax

    # Rename the inferred reconciled gene trees to be named after their corresponding orthogroup
    for og in \$(ls results/)
    do
        mv results/\$og/*.newick results/\$og/\${og}_reconciled_gft.newick
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        generax: \$( generax | head -n1 | sed "s/.*GeneRax //g" )
    END_VERSIONS
    """
}
