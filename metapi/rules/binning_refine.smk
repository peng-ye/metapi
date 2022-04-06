if config["params"]["binning"]["graphbin2"]["do"]:
    rule binning_graphbin2_prepare_assembly:
        input:
            scaftigs = os.path.join(
                config["output"]["assembly"],
                "scaftigs/{assembly_group}.{assembler}.out/{assembly_group}.{assembler}.scaftigs.fa.gz"),
            gfa = os.path.join(
                config["output"]["assembly"],
                "scaftigs/{assembly_group}.{assembler}.out/{assembly_group}.{assembler}.scaftigs.gfa.gz"),
        output:
             scaftigs = temp(os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/graphbin2/scaftigs.fa")),
             gfa = temp(os.path.join(
                 config["output"]["binning"],
                 "bins/{assembly_group}.{assembler}.out/graphbin2/scaftigs.gfa"))
        shell:
            '''
            pigz -dc {input.scaftigs} > {output.scaftigs}
            pigz -dc {input.gfa} > {output.gfa}
            '''

           
    rule binning_graphbin2_prepare_binned:
        input:
            bins_dir = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/{binner_graphbin}")
        output:
            binned = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/graphbin2/{assembly_group}.{assembler}.{binner_graphbin}.graphbin2.csv")
        params:
            suffix = config["params"]["binning"]["bin_suffix"],
            assembler = "{assembler}"
        run:
            metapi.get_binning_info(input.bins_dir,
                                    output.binned,
                                    params.suffix,
                                    params.assembler)


    rule binning_graphbin2:
        input:
            scaftigs = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/graphbin2/scaftigs.fa"),
            gfa = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/graphbin2/scaftigs.gfa"),
            binned = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/graphbin2/{assembly_group}.{assembler}.{binner_graphbin}.graphbin2.csv")
        output:
            os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/{binner_graphbin}_graphbin2/binning_done")
        log:
            os.path.join(config["output"]["binning"],
                         "logs/binning/{assembly_group}.{assembler}.{binner_graphbin}.graphbin2.refine.log")
        benchmark:
            os.path.join(config["output"]["binning"],
                         "benchmark/{binner_graphbin}/{assembly_group}.{assembler}.{binner_graphbin}.benchmark.txt")
        params:
            assembler = "{assembler}",
            bins_dir = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/{binner_graphbin}_graphbin2/"),
            prefix = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/{binner_graphbin}_graphbin2/{assembly_group}.{assembler}.{binner_graphbin}_graphbin2.bin"),
            suffix = config["params"]["binning"]["bin_suffix"],
            paths = os.path.join(
                config["output"]["assembly"],
                "scaftigs/{assembly_group}.{assembler}.out/{assembly_group}.{assembler}.scaftigs.paths.gz"),
            depth = config["params"]["binning"]["graphbin2"]["depth"],
            threshold = config["params"]["binning"]["graphbin2"]["threshold"]
        threads:
            config["params"]["binning"]["threads"]
        run:
            import pandas as pd
            import os

            shell('''mkdir -p {params.bins_dir}''')

            df = pd.read_csv(input.binned, names=["scaftigs_id", "bin_id"])

            if not df.empty:
                if params.assembler == "metaspades" or params.assembler == "spades":
                    shell(
                        '''
                        pigz -p {threads} -dc {params.paths} > {params.bins_dir}/scaftigs.paths

                        graphbin2 \
                        --assembler spades \
                        --contigs {input.scaftigs} \
                        --graph {input.gfa} \
                        --paths {params.bins_dir}/scaftigs.paths \
                        --binned {input.binned} \
                        --nthreads {threads} \
                        --depth {params.depth} \
                        --threshold {params.threshold} \
                        --output {params.bins_dir} \
                        > {log} 2>&1

                        rm -rf {params.bins_dir}/scaftigs.paths
                        ''')
                else:
                    shell(
                        '''
                        graphbin2 \
                        --assembler {params.assembler} \
                        --contigs {input.scaftigs} \
                        --graph {input.gfa} \
                        --binned {input.binned} \
                        --nthreads {threads} \
                        --depth {params.depth} \
                        --threshold {params.threshold} \
                        --output {params.bins_dir} \
                        > {log} 2>&1
                        ''')

                metapi.generate_bins(f"{params.bins_dir}/graphbin2_output.csv",
                                     input.scaftigs, params.prefix, params.suffix)
                shell('''touch {output}''')


    rule binning_graphbin2_all:
        input:
            expand(os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/{binner_graphbin}_graphbin2/binning_done"),
                binner_graphbin=BINNERS_GRAPHBIN,
                assembler=ASSEMBLERS,
                assembly_group=SAMPLES_ASSEMBLY_GROUP_LIST)

            #rules.alignment_all.input,
            #rules.assembly_all.input

else:
    rule binning_graphbin2_all:
        input:


if config["params"]["binning"]["dastools"]["do"]:
    def get_binning_done_list(wildcards):
        binning_done_list = []
        for binner in BINNERS_DASTOOLS:
            if binner != "vamb":
                binning_done = expand(os.path.join(
                    config["output"]["binning"],
                    "bins/{assembly_group}.{assembler}.out/{binner}/binning_done"),
                    assembly_group=wildcards.assembly_group,
                    assembler=wildcards.assembler,
                    binner=binner)
                binning_done_list.append(binning_done)
            else:
                binning_done = expand(os.path.join(
                    config["output"]["binning"],
                    "bins/{assembly_group}.{assembler}.out/{binner}/binning_done"),
                    assembly_group=metapi.get_multibinning_group_by_assembly_group(SAMPLES, wildcards.assembly_group),
                    assembler=wildcards.assembler,
                    binner=binner)
                binning_done_list.append(binning_done)
        return binning_done_list
 

    rule binning_dastools_preprocess:
        input:
            unpack(get_binning_done_list)
        output:
            contigs2bin = expand(
                os.path.join(
                    config["output"]["binning"],
                    "bins_id/{{assembly_group}}.{{assembler}}.out/{binner_dastools}_Contigs2Bin.tsv"),
                    binner_dastools=BINNERS_DASTOOLS)
        params:
            bin_suffix = config["params"]["binning"]["bin_suffix"]
        run:
            import glob
            import os
            from Bio import SeqIO

            i = -1
            for binning_done in input:
                i += 1
                bins_dir = os.path.dirname(binning_done)
                shell(f'''rm -rf {output.contigs2bin[i]}''')
                bins_list = glob.glob(bins_dir + "/*.bin.*.fa")
                if len(bins_list) == 0:
                    shell(f'''touch {output.contigs2bin[i]}''')
                else:
                    with open(output[i], 'w') as oh:
                        for bin_fa in sorted(bins_list):
                            bin_id_list = os.path.basename(bin_fa).split(".")
                            bin_id = bin_id_list[2] + "." + str(bin_id_list[4])
                            for contig in SeqIO.parse(bin_fa, "fasta"):
                                oh.write(f'''{contig.id}\t{bin_id}\n''')


    rule binning_dastools:
        input:
            contigs2bin = expand(
                os.path.join(
                    config["output"]["binning"],
                    "bins_id/{{assembly_group}}.{{assembler}}.out/{binner_dastools}_Contigs2Bin.tsv"),
                    binner_dastools=BINNERS_DASTOOLS),
            scaftigs = os.path.join(
                config["output"]["assembly"],
                "scaftigs/{assembly_group}.{assembler}.out/{assembly_group}.{assembler}.scaftigs.fa.gz"),
            pep = os.path.join(
                config["output"]["predict"],
                "scaftigs_gene/{assembly_group}.{assembler}.prodigal.out/{assembly_group}.{assembler}.faa")
        output:
            os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/dastools/binning_done")
        log:
            os.path.join(config["output"]["binning"],
                         "logs/binning/{assembly_group}.{assembler}.dastools.binning.log")
        benchmark:
            os.path.join(config["output"]["binning"],
                         "benchmark/dastools/{assembly_group}.{assembler}.dastools.benchmark.txt")
        priority:
            30
        conda:
            config["envs"]["dastools"]
        params:
            binner = ",".join(BINNERS_DASTOOLS),
            wrapper_dir = WRAPPER_DIR,
            bins_dir = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/dastools"),
            search_engine = config["params"]["binning"]["dastools"]["search_engine"],
            score_threshold = config["params"]["binning"]["dastools"]["score_threshold"],
            duplicate_penalty = config["params"]["binning"]["dastools"]["duplicate_penalty"],
            megabin_penalty = config["params"]["binning"]["dastools"]["megabin_penalty"],
            bin_suffix = config["params"]["binning"]["bin_suffix"],
            bin_prefix = os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/dastools/{assembly_group}.{assembler}.dastools.bin")
        threads:
            config["params"]["binning"]["threads"]
        shell:
            '''
            set +e
            rm -rf {params.bins_dir}
            mkdir -p {params.bins_dir}
            
            pigz -p {threads} -d -c {input.scaftigs} > {params.bins_dir}/scaftigs.fasta
            contigs2bin=$(python -c "import sys; print(','.join(sys.argv[1:]))" {input.contigs2bin})

            DAS_Tool \
            --bins $contigs2bin \
            --labels {params.binner} \
            --contigs {params.bins_dir}/scaftigs.fasta \
            --proteins {input.pep} \
            --outputbasename {params.bin_prefix} \
            --search_engine {params.search_engine} \
            --write_bin_evals \
            --write_bins \
            --write_unbinned \
            --score_threshold {params.score_threshold} \
            --duplicate_penalty {params.duplicate_penalty} \
            --megabin_penalty {params.megabin_penalty} \
            --threads {threads} --debug > {log} 2>&1

            rm -rf {params.bins_dir}/scaftigs.fasta

            exitcode=$?
            if [ $exitcode -eq 1 ]
            then
                grep -oEi 'no single copy genes found. Aborting' {log}
                grepcode=$?
                if [ $grepcode -eq 0 ]
                then
                    exit 0
                else
                    grep -oEi 'single copy gene prediction using {params.search_engine} failed. Aborting' {log}
                    grepcode=$?
                    if [ $grepcode -eq 0 ]
                    then
                        exit 0
                    else
                        exit $exitcode
                    fi
                fi
            fi

            python {params.wrapper_dir}/dastools_postprocess.py \
            {params.bin_prefix} \
            {params.bin_suffix}

            touch {output}
            ''' 


    rule binning_dastools_all:
        input:
            expand(
                os.path.join(
                    config["output"]["binning"],
                    "bins/{assembly_group}.{assembler}.out/dastools/binning_done"),
                assembler=ASSEMBLERS,
                assembly_group=SAMPLES_ASSEMBLY_GROUP_LIST)

            #rules.predict_scaftigs_gene_prodigal_all.input

else:
    rule binning_dastools_all:
        input:


if len(BINNERS_CHECKM) != 0:
    rule binning_report:
        input:
            os.path.join(
                config["output"]["binning"],
                "bins/{assembly_group}.{assembler}.out/{binner_checkm}/binning_done")
        output:
            report_dir = directory(
                os.path.join(
                    config["output"]["binning"],
                    "report/{assembler}_{binner_checkm}_stats/{assembly_group}"))
        priority:
            35
        params:
            assembly_group = "{assembly_group}",
            assembler = "{assembler}",
            binner = "{binner_checkm}"
        run:
            import glob

            shell('''rm -rf {output.report_dir}''')
            shell('''mkdir -p {output.report_dir}''')

            bin_list =  glob.glob(os.path.dirname(input[0]) + "/*bin*fa")
            header_list = ["assembly_group", "bin_id", "assembler", "binner",
                           "chr", "length", "#A", "#C", "#G", "#T",
                           "#2", "#3", "#4", "#CpG", "#tv", "#ts", "#CpG-ts"]
            header = "\\t".join(header_list)

            for bin_fa in bin_list:
                bin_id = os.path.basename(os.path.splitext(bin_fa)[0])
                header_ = "\\t".join([params.assembly_group, bin_id,
                                      params.assembler, params.binner])
                stats_file = os.path.join(output.report_dir,
                                          bin_id + ".seqtk.comp.tsv.gz")

                shell(
                    '''
                    seqtk comp %s | \
                    awk \
                    'BEGIN \
                    {{print "%s"}}; \
                    {{print "%s" "\t" $0}}' | \
                    gzip -c > %s
                    ''' % (bin_fa, header, header_, stats_file))


    rule binning_report_merge:
        input:
            expand(os.path.join(
                config["output"]["binning"],
                "report/{{assembler}}_{{binner_checkm}}_stats/{assembly_group}"),
                assembly_group=SAMPLES_ASSEMBLY_GROUP_LIST)
        output:
            summary = os.path.join(
                config["output"]["binning"],
                "report/assembly_stats_{assembler}_{binner_checkm}.tsv")
        params:
            min_length = config["params"]["assembly"]["report"]["min_length"],
            len_ranges = config["params"]["assembly"]["report"]["len_ranges"]
        threads:
            config["params"]["binning"]["threads"]
        run:
            import glob
            comp_list = []
            for i in input:
                comp_list += glob.glob(i + "/*bin*.seqtk.comp.tsv.gz")

            if len(comp_list) != 0:
                metapi.assembler_init(params.len_ranges,
                                      ["assembly_group", "bin_id", "assembler", "binner"])
                comp_list_ = [(j, params.min_length) for j in comp_list]
                metapi.merge(comp_list_, metapi.parse_assembly,
                             threads, output=output.summary)
            else:
                shell('''touch {output.summary}''')


    rule binning_report_all:
        input:
            expand(os.path.join(
                config["output"]["binning"],
                "report/assembly_stats_{assembler}_{binner_checkm}.tsv"),
                   assembler=ASSEMBLERS,
                   binner_checkm=BINNERS_CHECKM)

else:
    rule binning_report_all:
        input:


rule binning_all:
    input:
        rules.binning_metabat2_all.input,
        rules.binning_maxbin2_all.input,
        rules.binning_concoct_all.input,
        rules.binning_graphbin2_all.input,
        rules.binning_vamb_all.input,
        rules.binning_dastools_all.input,
        rules.binning_report_all.input