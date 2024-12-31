# phac-nml/LegioVue : Clustering
This document provides the neccessary steps to visualize the cgMLST output from LegioVue.
At the moment these steps need to be run separately using the ouputs of the LegioVue. Pending updates, these steps will be incorporated into the nextflow workflow directly.

Visualizations of cgMLST data can be generated with or without clustering. Both options are presented below, though [partitioning and visualization with ReporTree](#partitioning-and-visualization-with-reportree) is the recommended approach if you are able to install and run [ReporTree](https://github.com/insapathogenomics/ReporTree) on the command-line.

### Visualization-only with PHYLOViZ GUI
Use this option if you are unable to install ReporTree, or if you simply want to visualize relative allele differences between isolates without setting cluster/partition thresholds:
1. Navigate to https://online2.phyloviz.net/index in a browser window.
2. Scroll down and click on "Login-free upload" under **Test PHYLOViZ Online**. This will take you to a page where you can upload and visualize your cgMLST profile without storing any data in the application. Note that navigating away from this page will erase your data.
3. From the **Possible Input Formats** dropdown menu, select "Profile Data".
4. Under **Input Files**, upload your `results/chewbbaca/allele_calls/cgMLST/cgMLST100.tsv` file from LegioVue as Profile Data. Upload a `.tsv` metadata file as Auxiliary Data. **Note:** the "sample name" or similar column header (usually the first column) needs to match the cgMLST output in order to be visualized correctly. Change it to "FILE" to match the profile data or vice versa.
5. Select "Core Analysis" as the **Analysis Method**.
6. Provide a name and optional description for your dataset and click on **Launch Tree**. In a minute or two you will be redirected to a visualization of your data.
7. On the left sidebar, navigate to **Assign Colors** > **By Auxiliary Data** and select the appropriate metadata column (_E.g.,_ ST). Node and branch labels can be added by selecting the "Add Labels" checkbox under **Graphic Properties** > **Nodes** or **Links**.

**Important:** In this Minumum Spanning Tree (MST), branch (or "link") lengths represent the number of alleles that differ between linked isolates. The default schema that the pipeline uses for cgMLST determination has a maximum of 1521 possible alleles. These branch lengths tend to increase when there are many inferred (INF) alleles and fewer exact (EXC) alleles (which, in turn, is affected by underlying data quality) used to generate the profile data. These numbers can be found in the `overall.qc.tsv` output of the main pipeline and should be taken into consideration when interpreting the visualization of the profile data.

### Partitioning and Visualization with ReporTree
Reportree can be used to partition the MST of isolates according to different thresholds, which may be useful for epidemiological investigation.

1. First, install [ReporTree](https://github.com/insapathogenomics/ReporTree) either with Conda or Docker according to the installation instructions in the Readme file on their GitHub page.
2. Prepare a metadata file with columns for `sample` and any other data you wish to include for downstream visualization.
3. Activate ReporTree and run `grapetree` analysis, using as input the cgMLST profile data and prepared metadata from Step 2. An example command is below to use with the test dataset:
```
reportree.py -m <PATH-TO-METADATA>/metadata.tsv \
-a <PATH-TO-PIPELINE-DIR>/results/chewbbaca/allele_calls/cgMLST/cgMLST100.tsv -thr 0-5 --columns_summary_report ST,n_ST \
--method MSTreeV2 --loci-called 1.0 --matrix-4-grapetree --analysis grapetree
```
You may wish to modify certain values depending on your analysis:
- `-thr` indicates the threshold(s) to use for cluster partitioning. Setting `-thr 0-5` will request that ReporTree assign samples to clusters at six different allele thresholds, ranging from 0 allele differences to 5. You may also select distinct threshold values, for example `-thr 5,10,15,20`, for more exploratory analysis.
- `--loci-called` should correspond to the cgMLST profile used as input, _i.e.,_ `--loci-called 0.95` should be used if the input profile is `cgMLST95.tsv`.
- `--columns_summary_report` indicates columns from the metadata file that should be described for each cluster. For example, `ST,n_ST` requests that for each cluster, the ST and number of STs included in that cluster should be reported in the output. This information can help you investigate different clustering thresholds.
- `--out` can be added to the above command to specify an existing directory and prefix for the output files. Ex. `--out reportree/TD1` will append "TD1" as a prefix to all output files.

4. Once you have your output files from ReporTree, navigate to the local implementation of [GrapeTree](https://achtman-lab.github.io/GrapeTree/MSTree_holder.html) to visualize the MST data.
5. Under **Inputs/Outputs**, select "Load Files" and upload both `*.nwk` and `*_metadata_w_partitions.tsv`.
6. Under **Tree Layout**, you can customize the MST visualization including exploring different partitions by selecting `MST-###` in **Node Style** > **Colour By:**
