#!/usr/bin/env Rscript
## ------------------------------------------------ ##
## Plotting script to visualize information on each
##  Legionella ST allele to help investigations on
##  missing or non-called STs
## ------------------------------------------------ ##
library(optparse)
library(data.table)
library(ggplot2)
library(patchwork)

## Functions ##
## --------- ##
# Create combined plots
create_plots <- function(gene, df) {
    # First plot: Depth vs Position
    plot1 <- ggplot(df, aes(x = pos, y = reads_all)) +
        geom_line() +
        scale_y_continuous() +
        xlab("Genome Pos (nt)") +
        ylab("Depth") +
        theme_bw() +
        theme(
            axis.title.x = element_text(size = 10),
            axis.title.y = element_text(size = 10),
        )

    # Second plot: RMSMapQ vs Position
    plot2 <- ggplot(df, aes(x = pos, y = rms_mapq)) +
        geom_line() +
        scale_y_continuous(limits = c(0, 60)) +
        xlab("Genome Pos (nt)") +
        ylab("RMS Map Quality") +
        theme_bw() +
        theme(
            axis.title.x = element_text(size = 10),
            axis.title.y = element_text(size = 10),
        )

    # Third plot: RMSBaseQ vs Position
    plot3 <- ggplot(df, aes(x = pos, y = rms_baseq)) +
        geom_line() +
        scale_y_continuous(limits = c(0, 60)) +
        xlab("Genome Pos (nt)") +
        ylab("RMS Base Quality") +
        theme_bw() +
        theme(
            axis.title.x = element_text(size = 10),
            axis.title.y = element_text(size = 10),
        )

    # Combine the three plots stacked vertically
    areas <- c(
        area(1,1),
        area(2,1),
        area(3,1)
    )
    combined_plot <- plot1/plot2/plot3 +
        plot_layout(
            design = areas
        ) +
        plot_annotation(
            title = paste0('Allele: ', gene),
            theme = theme(plot.title = element_text(size = 20)),
            tag_levels = 'A'
        )
    return(combined_plot)
}

## Main Script ##
## ----------- ##
# Args
option_list <- list(
    make_option(
        c("-i", "--input_tsv"),
        help="Path to pysamstats TSV file with mapQ and baseQ annotated"
    ),
    make_option(
        c("-o", "--outfile"), default="el_gato_allele_plots.pdf",
        help="Output plot filename")
    )
opt_parser <- OptionParser(option_list = option_list)
args <- parse_args(opt_parser)

# Split based on chrom
df <- read.table(args$input_tsv, sep = '\t', header = TRUE)
split_df <- split(df, df$chrom)

# Output spot and size
pdf(args$outfile, width = 8.5, height = 6)

# Create plot per chrom
for (gene in names(split_df)) {
    current_df <- split_df[[gene]]
    p <- create_plots(gene, current_df)
    print(p)
}

# Turn off output to pdf
dev.off()
