# Standard library
from pathlib import Path

# Third-party
import click

# First-party
from BIOME4Py.biome4driver import main


@click.command()
@click.option(
    "--climatefile",
    "-cf",
    type=click.Path(exists=True, path_type=Path),
    help="The input NetCDF file containing climate information",
)
@click.option(
    "--soilfile",
    "-sf",
    type=click.Path(exists=True, path_type=Path),
    help="The input NetCDF file containing soil information",
)
@click.option(
    "--coordstring",
    "-coord",
    type=str,
    default="alldata",
    help="The coordinates to poll from the input dataset, default='alldata'",
)
@click.option(
    "--outfile",
    "-of",
    type=click.Path(writable=True, path_type=Path),
    help="The name of the output file",
)
@click.option("--co2", "-c", type=float, default=350, help="CO2 levels")
@click.option(
    "--diagnosticmode",
    "-d",
    is_flag=True,
    help="Enable diagnostic mode?",
    default=False,
)
def cli(
    climatefile: Path,
    soilfile: Path,
    coordstring: str,
    outfile: Path,
    co2: float,
    diagnosticmode: bool,
):
    main(climatefile, soilfile, coordstring, outfile, co2, diagnosticmode)


if __name__ == "__main__":
    cli()