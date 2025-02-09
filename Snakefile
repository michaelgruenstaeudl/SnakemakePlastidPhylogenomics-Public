configfile: "snakefile.config.yaml"

# Example usage: snakemake -j 1 output_CAR455c/

#__author__ = 'Michael Gruenstaeudl <m.gruenstaeudl@fu-berlin.de>'
#__info__ = 'Snakefile for assemblying plastid genomes'
#__version__ = '2022.05.03.1400'

## TO-DO
#   1. Improve logging by using snakemake's log()-function
#   2. If-statement if files already existant
#   3. Different steps in different folders
#   4. Use snakemake's temp()-function for temporary data

rule all:
    input:
#        "{sample}_assembly.log"
        directory("output_{sample}")

rule readmapping_with_Script05:
    input:
        RAWREADS = expand("{mysrc}/{{sample}}_R{R}.fastq.gz", mysrc=config['READ_DIR'], R=[1,2])
    params:
        SCR5_EXE = config['SCR5_PTH'],
        REFG_PTH = config['REFG_DIR']+"/"+config['REFG_FLE'],
        REFG_NME = config['REFG_FLE'].strip(".fasta")
    output:
        (
        expand("{{sample}}.MappedAgainst.{refg_nme}_R1.fastq", refg_nme=config['REFG_FLE'].strip(".fasta")),
        expand("{{sample}}.MappedAgainst.{refg_nme}_R2.fastq", refg_nme=config['REFG_FLE'].strip(".fasta"))
        )
    shell:
        """
        echo {wildcards.sample} > {wildcards.sample}_readmapping.log ;
        bash {params.SCR5_EXE} {input.RAWREADS} {params.REFG_PTH} {wildcards.sample}_readmapping.log {wildcards.sample} ;
        """

rule filehygiene_after_readmapping:
    input:
        rules.readmapping_with_Script05.output
    params:
        REFG_NME = config['REFG_FLE'].strip(".fasta")
    output:
        (
        expand("{{sample}}.MappedAgainst.{refg_nme}_R1.fastq.gz", refg_nme=config['REFG_FLE'].strip(".fasta")),
        expand("{{sample}}.MappedAgainst.{refg_nme}_R2.fastq.gz", refg_nme=config['REFG_FLE'].strip(".fasta"))
        )
    shell:
        """
        rm {wildcards.sample}.MappedAgainst.{params.REFG_NME}.bam ;
        rm {wildcards.sample}.MappedAgainst.{params.REFG_NME}.fastq ;
        rm {wildcards.sample}.MappedAgainst.{params.REFG_NME}.*.stats ;
        rm {wildcards.sample}.MappedAgainst.{params.REFG_NME}.refdb.log ;
        rm -r db ;
        gzip {wildcards.sample}.MappedAgainst.{params.REFG_NME}_R1.fastq ;
        gzip {wildcards.sample}.MappedAgainst.{params.REFG_NME}_R2.fastq ;
        """

rule assembly_with_NOVOPlasty:
    input:
        rules.readmapping_with_Script05.output,
        rules.filehygiene_after_readmapping.output
    params:
        NOVO_DIR = config['NOVO_DIR'],
        NOVO_EXE = config['NOVO_DIR']+"/NOVOPlasty3.8.3.pl",
        NOVO_CFG = config['NOVO_DIR']+"/config.txt",
        MAPREADS1 = rules.filehygiene_after_readmapping.output[0],
        MAPREADS2 = rules.filehygiene_after_readmapping.output[1],
        REFG_FLE = config['REFG_FLE'],
        REFG_PTH = config['REFG_DIR']+"/"+config['REFG_FLE']
    output:
        "{sample}_assembly.log"
    shell:
        """
        cp {params.NOVO_EXE} . ;
        cp {params.NOVO_CFG} ./{wildcards.sample}_config.txt ;
        cp {params.REFG_PTH} . ;
        echo {wildcards.sample} > {wildcards.sample}_assembly.log ;
        set +o pipefail ;  ## Necessary for pipe operators in following line
        zcat {params.MAPREADS1} | head -n2 | sed 's/@/>/' > seed.fasta ;
        sed -i "s/Test/{wildcards.sample}/" {wildcards.sample}_config.txt ;
        sed -i "0,/mito/ s//chloro/" {wildcards.sample}_config.txt ;
        sed -i "s/12000-22000/140000-180000/" {wildcards.sample}_config.txt ;
        sed -i "s/\/path\/to\/seed_file\/Seed.fasta/seed.fasta/" {wildcards.sample}_config.txt ;
        sed -i "s/Extend seed directly  = no/Extend seed directly  = yes/" {wildcards.sample}_config.txt ;
        sed -i "s/\/path\/to\/reference_file\/reference.fasta (optional)/{params.REFG_FLE}/" {wildcards.sample}_config.txt ;
        sed -i 's/\/path\/to\/chloroplast_file\/chloroplast.fasta (only for "mito_plant" option)//' {wildcards.sample}_config.txt ;
        sed -i "s/\/path\/to\/reads\/reads_1.fastq/{params.MAPREADS1}/" {wildcards.sample}_config.txt ;
        sed -i "s/\/path\/to\/reads\/reads_2.fastq/{params.MAPREADS2}/" {wildcards.sample}_config.txt ;
        perl {params.NOVO_EXE} -c {wildcards.sample}_config.txt >> {wildcards.sample}_assembly.log ;
        """

rule filehygiene_after_assembly:
    input:
        rules.assembly_with_NOVOPlasty.output
    params:
        REFG_FLE = config['REFG_FLE']
    output:
        directory("output_{sample}")
    shell:
        """
        rm ./{wildcards.sample}_config.txt ;
        rm ./{params.REFG_FLE} ;
        rm ./NOVOPlasty3.8.3.pl ;
        rm ./seed.fasta ;
        TMPNME=$(set +o pipefail ; tr -dc A-Za-z0-9 </dev/urandom | head -c 6) ;  ## Generate a unique folder name; "set +o pipefail" is necessary for pipe operators
        mkdir $TMPNME ;
        mv *{wildcards.sample}* $TMPNME/ ;
        mv $TMPNME output_{wildcards.sample}/ ;
        cp output_{wildcards.sample}/{wildcards.sample}_assembly.log . ;
        """
